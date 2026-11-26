import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

const ADMIN_ROLES = new Set([
  "admin",
  "administrator",
  "superadmin",
  "super_admin",
  "finance",
  "support",
  "customer_service",
  "operations",
  "fleet_manager",
  "marketing",
  "staff_admin",
]);

const SECRETS_COLLECTION = "admin_2fa_secrets";
const CHALLENGES_COLLECTION = "admin_2fa_challenges";
const MASTER_KEY_DOC = "server_internal/admin_2fa_master_key";
const GLOBAL_2FA_SETTINGS_DOC = "app_settings/email_2fa";

const TOTP_PERIOD_SECONDS = 30;
const TOTP_DIGITS = 6;
const TOTP_WINDOW = 1; // +/- 30s
const CHALLENGE_TTL_MS = 10 * 60 * 1000; // 10 minutes
const EMAIL_OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
const EMAIL_RESEND_COOLDOWN_MS = 30 * 1000; // 30 seconds
const MAX_CHALLENGE_ATTEMPTS = 5;
const MAX_EMAIL_SENDS_PER_CHALLENGE = 3;

const BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
const BACKUP_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function getAdmin() {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  return {
    db: admin.firestore(),
    auth: admin.auth(),
    FieldValue: admin.firestore.FieldValue,
    Timestamp: admin.firestore.Timestamp,
  };
}

// ================= BASE32 & TOTP (RFC 4648 / RFC 6238) =================

function base32Encode(buf: Buffer): string {
  let bits = 0;
  let value = 0;
  let output = "";
  for (let i = 0; i < buf.length; i++) {
    value = (value << 8) | buf[i];
    bits += 8;
    while (bits >= 5) {
      output += BASE32_ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) {
    output += BASE32_ALPHABET[(value << (5 - bits)) & 31];
  }
  return output;
}

function base32Decode(input: string): Buffer {
  const clean = input.toUpperCase().replace(/[^A-Z2-7]/g, "");
  let bits = 0;
  let value = 0;
  const bytes: number[] = [];
  for (let i = 0; i < clean.length; i++) {
    const idx = BASE32_ALPHABET.indexOf(clean[i]);
    if (idx === -1) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

function generateHotp(secret: Buffer, counter: bigint, digits = TOTP_DIGITS): string {
  const counterBuf = Buffer.alloc(8);
  counterBuf.writeBigUInt64BE(counter, 0);
  const hmac = crypto.createHmac("sha1", secret).update(counterBuf).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const binary = hmac.readUInt32BE(offset) & 0x7fffffff;
  const code = binary % Math.pow(10, digits);
  return String(code).padStart(digits, "0");
}

function constantTimeEqual(aStr: string, bStr: string): boolean {
  const a = Buffer.from(aStr, "utf8");
  const b = Buffer.from(bStr, "utf8");
  if (a.length !== b.length) {
    crypto.timingSafeEqual(b, b);
    return false;
  }
  return crypto.timingSafeEqual(a, b);
}

function verifyTotpCode(
  secret: Buffer,
  submittedCode: string,
  lastUsedStep: number | null
): number | null {
  const normalized = (submittedCode || "").replace(/\s+/g, "").trim();
  if (!/^\d{6}$/.test(normalized)) {
    return null;
  }

  const currentStep = Math.floor(Date.now() / 1000 / TOTP_PERIOD_SECONDS);
  let matchedStep: number | null = null;

  // Evaluate entire window without early break
  for (let offset = -TOTP_WINDOW; offset <= TOTP_WINDOW; offset++) {
    const step = currentStep + offset;
    if (step < 0) continue;
    const expected = generateHotp(secret, BigInt(step), TOTP_DIGITS);
    if (constantTimeEqual(normalized, expected)) {
      matchedStep = step;
    }
  }

  if (matchedStep === null) return null;
  if (lastUsedStep !== null && matchedStep <= lastUsedStep) {
    return null; // RFC 6238 §5.2 replay protection
  }
  return matchedStep;
}

function buildOtpAuthUri(secretBase32: string, email: string, issuer = "Haujzo Portal"): string {
  const label = `${encodeURIComponent(issuer)}:${encodeURIComponent(email)}`;
  return (
    `otpauth://totp/${label}` +
    `?secret=${secretBase32}` +
    `&issuer=${encodeURIComponent(issuer)}` +
    `&algorithm=SHA1&digits=${TOTP_DIGITS}&period=${TOTP_PERIOD_SECONDS}`
  );
}

// ================= MASTER KEY & AES-256-GCM ENCRYPTION =================

let cachedMasterKey: Buffer | null = null;

async function getMasterKey(): Promise<Buffer> {
  if (cachedMasterKey) return cachedMasterKey;

  const envKey = (process.env.ADMIN_2FA_MASTER_KEY || "").trim();
  if (envKey) {
    cachedMasterKey = crypto.createHash("sha256").update(envKey).digest();
    return cachedMasterKey;
  }

  const { db, FieldValue } = getAdmin();
  const docRef = db.doc(MASTER_KEY_DOC);
  const snap = await docRef.get();
  if (snap.exists && snap.data()?.keyHex) {
    cachedMasterKey = Buffer.from(snap.data()!.keyHex, "hex");
    return cachedMasterKey;
  }

  const newKey = crypto.randomBytes(32);
  try {
    await docRef.create({
      keyHex: newKey.toString("hex"),
      createdAt: FieldValue.serverTimestamp(),
    });
    cachedMasterKey = newKey;
  } catch (_) {
    const retry = await docRef.get();
    if (!retry.exists || !retry.data()?.keyHex) {
      throw new HttpsError("internal", "Could not initialize 2FA encryption master key.");
    }
    cachedMasterKey = Buffer.from(retry.data()!.keyHex, "hex");
  }
  return cachedMasterKey;
}

async function encryptSecret(plaintext: string): Promise<string> {
  const key = await getMasterKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString("hex")}:${tag.toString("hex")}:${encrypted.toString("hex")}`;
}

async function decryptSecret(payload: string): Promise<string> {
  const parts = (payload || "").split(":");
  if (parts.length !== 3) {
    throw new HttpsError("internal", "Corrupted encrypted 2FA secret.");
  }
  const [ivHex, tagHex, dataHex] = parts;
  const key = await getMasterKey();
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, Buffer.from(ivHex, "hex"));
  decipher.setAuthTag(Buffer.from(tagHex, "hex"));
  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(dataHex, "hex")),
    decipher.final(),
  ]);
  return decrypted.toString("utf8");
}

// ================= BACKUP RECOVERY CODES =================

interface StoredBackupCode {
  id: string;
  salt: string;
  hash: string;
  used: boolean;
  usedAt?: any;
}

function generateBackupCodes(count = 8): { plaintext: string[]; stored: StoredBackupCode[] } {
  const plaintext: string[] = [];
  const stored: StoredBackupCode[] = [];

  for (let i = 0; i < count; i++) {
    let raw = "";
    for (let j = 0; j < 8; j++) {
      raw += BACKUP_CODE_ALPHABET[crypto.randomInt(0, BACKUP_CODE_ALPHABET.length)];
    }
    const formatted = `${raw.slice(0, 4)}-${raw.slice(4, 8)}`;
    const salt = crypto.randomBytes(16).toString("hex");
    const hash = crypto.createHmac("sha256", salt).update(raw).digest("hex");
    plaintext.push(formatted);
    stored.push({
      id: crypto.randomBytes(8).toString("hex"),
      salt,
      hash,
      used: false,
    });
  }
  return { plaintext, stored };
}

function normalizeBackupCode(input: string): string {
  return (input || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function findMatchingBackupCodeIndex(
  codes: StoredBackupCode[],
  submitted: string
): number {
  const normalized = normalizeBackupCode(submitted);
  if (normalized.length !== 8) return -1;

  for (let i = 0; i < codes.length; i++) {
    const entry = codes[i];
    if (!entry || entry.used) continue;
    const candidateHash = crypto.createHmac("sha256", entry.salt).update(normalized).digest("hex");
    if (constantTimeEqual(candidateHash, entry.hash)) {
      return i;
    }
  }
  return -1;
}

// ================= EMAIL OTP & SMTP =================

interface SmtpConfig {
  enabled: boolean;
  smtpHost: string;
  smtpPort: number;
  smtpSecure: boolean;
  smtpUser: string;
  smtpPass: string;
  fromName: string;
  fromEmail: string;
  require2faForAllAdmins: boolean;
}

async function getGlobal2faSettingsInternal(): Promise<SmtpConfig> {
  const { db } = getAdmin();
  const snap = await db.doc(GLOBAL_2FA_SETTINGS_DOC).get();
  const data = snap.exists ? snap.data() || {} : {};

  let smtpPass = (process.env.SMTP_PASS || "").toString().trim();
  if (data.smtpPassEnc) {
    try {
      smtpPass = await decryptSecret(data.smtpPassEnc);
    } catch (e) {
      logger.warn("Failed to decrypt smtpPassEnc:", e);
    }
  } else if (data.smtpPass) {
    smtpPass = data.smtpPass.toString().trim();
  }

  const smtpHost = (data.smtpHost || process.env.SMTP_HOST || "").toString().trim();
  const smtpPort = Number(data.smtpPort || process.env.SMTP_PORT || 587);
  const smtpSecure =
    typeof data.smtpSecure === "boolean"
      ? data.smtpSecure
      : smtpPort === 465;
  const smtpUser = (data.smtpUser || process.env.SMTP_USER || "").toString().trim();
  const fromName = (data.fromName || process.env.SMTP_FROM_NAME || "Haujzo Portal Security").toString().trim();
  const fromEmail = (data.fromEmail || process.env.SMTP_FROM_EMAIL || smtpUser).toString().trim();

  const hasCreds = Boolean(smtpHost && smtpPort > 0 && smtpUser && smtpPass);
  const enabled = data.enabled !== false && hasCreds;

  return {
    enabled,
    smtpHost,
    smtpPort,
    smtpSecure,
    smtpUser,
    smtpPass,
    fromName,
    fromEmail,
    require2faForAllAdmins: data.require2faForAllAdmins === true,
  };
}

function hashEmailOtp(otp: string, salt: string): string {
  return crypto.createHmac("sha256", salt).update(otp.trim()).digest("hex");
}

async function sendOtpEmail(toEmail: string, otpCode: string, adminName: string, purposeLabel: string): Promise<void> {
  const cfg = await getGlobal2faSettingsInternal();
  if (!cfg.enabled || !cfg.smtpHost || !cfg.smtpUser || !cfg.smtpPass) {
    throw new HttpsError(
      "failed-precondition",
      "Email OTP SMTP server is not configured yet. Ask a Super Administrator to configure SMTP in Settings -> Two-Factor Authentication."
    );
  }

  const transporter = nodemailer.createTransport({
    host: cfg.smtpHost,
    port: cfg.smtpPort,
    secure: cfg.smtpSecure,
    auth: {
      user: cfg.smtpUser,
      pass: cfg.smtpPass,
    },
  });

  const safeName = adminName || "Administrator";
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden;">
      <div style="background-color: #122F51; color: #ffffff; padding: 20px 24px;">
        <h2 style="margin: 0; font-size: 18px;">Haujzo Portal Security</h2>
        <p style="margin: 4px 0 0; font-size: 12px; color: #cbd5e1;">Two-Factor Authentication Verification</p>
      </div>
      <div style="padding: 24px; background-color: #ffffff; color: #111827;">
        <p style="margin-top: 0;">Hello ${safeName},</p>
        <p>Use the verification code below to complete your <strong>${purposeLabel}</strong> on Haujzo Portal:</p>
        <div style="margin: 20px 0; padding: 16px; background-color: #f3f4f6; border-radius: 8px; text-align: center; letter-spacing: 8px; font-size: 30px; font-weight: bold; color: #122F51;">
          ${otpCode}
        </div>
        <p style="font-size: 13px; color: #4b5563;">This code expires in <strong>10 minutes</strong> and can only be used once.</p>
        <p style="font-size: 12px; color: #dc2626; margin-bottom: 0;">If you did not initiate this request, someone may have your password. Change your password immediately.</p>
      </div>
    </div>
  `;

  await transporter.sendMail({
    from: `"${cfg.fromName}" <${cfg.fromEmail}>`,
    to: toEmail,
    subject: `${otpCode} is your Haujzo Portal verification code`,
    text: `Hello ${safeName},\n\nYour Haujzo Portal verification code for ${purposeLabel} is: ${otpCode}\nThis code expires in 10 minutes.\n\nIf you did not request this, change your password immediately.`,
    html,
  });
}

function maskEmail(email: string): string {
  const parts = (email || "").split("@");
  if (parts.length !== 2) return email;
  const local = parts[0];
  const domain = parts[1];
  if (local.length <= 2) return `${local[0] || "*"}***@${domain}`;
  return `${local.slice(0, 2)}***${local.slice(-1)}@${domain}`;
}

// ================= ADMIN ROLE & SESSION GUARDS =================

interface AdminProfileInfo {
  uid: string;
  email: string;
  fullName: string;
  isSuperAdmin: boolean;
  data: FirebaseFirestore.DocumentData;
}

async function getActiveAdminProfile(uid: string): Promise<AdminProfileInfo> {
  const { db } = getAdmin();
  const doc = await db.collection("Users").doc(uid).get();
  if (!doc.exists) {
    throw new HttpsError("permission-denied", "Admin profile record was not found.");
  }
  const data = doc.data() || {};
  const role = (data.role || "").toString().toLowerCase().trim();
  const adminType = (data.adminType || "").toString().toLowerCase().trim();
  const status = (data.status || "active").toString().toLowerCase().trim();

  const isAdmin = ADMIN_ROLES.has(role) || adminType.length > 0;
  if (!isAdmin) {
    throw new HttpsError("permission-denied", "Access Denied: You do not have Administrator permissions.");
  }

  if (status === "blocked" || status === "suspended" || status === "disabled") {
    throw new HttpsError("permission-denied", "Account Disabled: Your admin access has been suspended.");
  }

  const isSuper =
    data.isSuperAdmin === true ||
    adminType === "super_admin" ||
    (!adminType && (role === "admin" || role === "administrator" || role === "superadmin"));

  const fullName = `${data.firstName || ""} ${data.lastName || ""}`.trim() || (data.email || "Admin");
  return {
    uid,
    email: (data.email || "").toString().trim(),
    fullName,
    isSuperAdmin: isSuper,
    data,
  };
}

/**
 * Shared guard for sensitive admin Cloud Functions (e.g. Paystack payouts & refunds).
 * When an admin has 2FA enabled in `admin_2fa_secrets/{uid}`, enforces that the
 * caller's Firebase ID token carries the `mfa_verified: true` claim minted by
 * `verifyAdmin2faLogin` / `confirmAdminTotpSetup` / `confirmAdminEmailOtpSetup`.
 */
export async function assertAdmin2faSession(
  auth?: { uid: string; token?: admin.auth.DecodedIdToken }
): Promise<AdminProfileInfo> {
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const profile = await getActiveAdminProfile(auth.uid);
  const { db } = getAdmin();
  const secretSnap = await db.collection(SECRETS_COLLECTION).doc(auth.uid).get();
  const is2faEnabled = secretSnap.exists && secretSnap.data()?.enabled === true;
  if (is2faEnabled && auth.token?.mfa_verified !== true) {
    throw new HttpsError(
      "permission-denied",
      "Two-Factor Authentication verification is required for this session. Please sign in again with 2FA."
    );
  }
  return profile;
}

async function resolveChallengeOrAuthUid(
  request: { auth?: { uid: string; token?: admin.auth.DecodedIdToken } },
  challengeId?: string,
  requiredPurpose?: "enroll" | "login"
): Promise<{ uid: string; challengeRef: FirebaseFirestore.DocumentReference | null; email: string; fullName: string }> {
  const { db } = getAdmin();

  if (challengeId && challengeId.trim().length > 0) {
    const ref = db.collection(CHALLENGES_COLLECTION).doc(challengeId.trim());
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "2FA session expired or invalid. Please sign in again.");
    }
    const c = snap.data()!;
    if (c.consumed === true) {
      throw new HttpsError("failed-precondition", "This 2FA challenge has already been completed.");
    }
    if (c.expiresAt && c.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("deadline-exceeded", "2FA verification session expired. Please sign in again.");
    }
    if ((c.attempts || 0) >= MAX_CHALLENGE_ATTEMPTS) {
      throw new HttpsError("resource-exhausted", "Too many failed verification attempts. Please sign in again.");
    }
    if (requiredPurpose && c.purpose !== requiredPurpose) {
      throw new HttpsError("permission-denied", "Invalid 2FA challenge purpose.");
    }
    const profile = await getActiveAdminProfile(c.uid);
    return {
      uid: profile.uid,
      challengeRef: ref,
      email: profile.email || c.email || "",
      fullName: profile.fullName,
    };
  }

  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const profile = await assertAdmin2faSession(request.auth);
  return {
    uid: profile.uid,
    challengeRef: null,
    email: profile.email,
    fullName: profile.fullName,
  };
}

// ================= CALLABLE: BEGIN 2FA LOGIN =================

export const beginAdmin2faLogin = onCall(async (request) => {
  const { idToken } = request.data || {};
  if (!idToken || typeof idToken !== "string") {
    throw new HttpsError("invalid-argument", "First-factor ID token is required.");
  }

  const { db, auth, Timestamp } = getAdmin();
  let decoded: admin.auth.DecodedIdToken;
  try {
    decoded = await auth.verifyIdToken(idToken, true);
  } catch (err: any) {
    throw new HttpsError("unauthenticated", "Invalid or expired credentials. Please try again.");
  }

  const profile = await getActiveAdminProfile(decoded.uid);
  const userEmail = profile.email || decoded.email || "";

  const [secretSnap, globalCfg] = await Promise.all([
    db.collection(SECRETS_COLLECTION).doc(profile.uid).get(),
    getGlobal2faSettingsInternal(),
  ]);

  const secretData = secretSnap.exists ? secretSnap.data() || {} : {};
  const totpEnabled = secretData.totpEnabled === true && Boolean(secretData.totpSecretEnc);
  const emailOtpEnabled = secretData.emailOtpEnabled === true;
  const any2faEnabled = secretData.enabled === true && (totpEnabled || emailOtpEnabled);

  if (any2faEnabled) {
    const challengeId = crypto.randomBytes(24).toString("hex");
    const preferredMethod =
      secretData.preferredMethod === "email" && emailOtpEnabled && globalCfg.enabled
        ? "email"
        : totpEnabled
          ? "totp"
          : "email";

    const challengeDoc: Record<string, any> = {
      uid: profile.uid,
      email: userEmail,
      purpose: "login",
      attempts: 0,
      emailOtpSentCount: 0,
      consumed: false,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + CHALLENGE_TTL_MS),
    };

    let autoEmailSent = false;
    if (preferredMethod === "email" && globalCfg.enabled && userEmail) {
      const otp = String(crypto.randomInt(100000, 1000000));
      const salt = crypto.randomBytes(16).toString("hex");
      challengeDoc.emailOtpSalt = salt;
      challengeDoc.emailOtpHash = hashEmailOtp(otp, salt);
      challengeDoc.emailOtpExpiresAt = Timestamp.fromMillis(Date.now() + EMAIL_OTP_TTL_MS);
      challengeDoc.emailOtpSentCount = 1;
      challengeDoc.lastEmailSentAt = Timestamp.now();

      await db.collection(CHALLENGES_COLLECTION).doc(challengeId).set(challengeDoc);
      try {
        await sendOtpEmail(userEmail, otp, profile.fullName, "Admin Sign-In");
        autoEmailSent = true;
      } catch (mailErr: any) {
        logger.error("Failed to send auto Email OTP during login:", mailErr);
      }
    } else {
      await db.collection(CHALLENGES_COLLECTION).doc(challengeId).set(challengeDoc);
    }

    const backupCodes: StoredBackupCode[] = Array.isArray(secretData.backupCodeHashes)
      ? secretData.backupCodeHashes
      : [];
    const backupCodesRemaining = backupCodes.filter((c) => c && !c.used).length;

    return {
      status: "challenge_required",
      challengeId,
      hasTotp: totpEnabled,
      hasEmailOtp: emailOtpEnabled && globalCfg.enabled,
      smtpConfigured: globalCfg.enabled,
      preferredMethod,
      autoEmailSent,
      backupCodesRemaining,
      emailMasked: maskEmail(userEmail),
    };
  }

  if (globalCfg.require2faForAllAdmins) {
    const challengeId = crypto.randomBytes(24).toString("hex");
    await db.collection(CHALLENGES_COLLECTION).doc(challengeId).set({
      uid: profile.uid,
      email: userEmail,
      purpose: "enroll",
      attempts: 0,
      emailOtpSentCount: 0,
      consumed: false,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + CHALLENGE_TTL_MS),
    });

    return {
      status: "enrollment_required",
      challengeId,
      smtpConfigured: globalCfg.enabled,
      email: userEmail,
      emailMasked: maskEmail(userEmail),
    };
  }

  // 2FA not yet configured and mandatory policy is off
  return {
    status: "no_2fa_configured",
    smtpConfigured: globalCfg.enabled,
  };
});

// ================= CALLABLE: SEND / RESEND EMAIL OTP FOR LOGIN =================

export const sendAdmin2faLoginEmailOtp = onCall(async (request) => {
  const { challengeId } = request.data || {};
  if (!challengeId || typeof challengeId !== "string") {
    throw new HttpsError("invalid-argument", "Challenge ID is required.");
  }

  const { db, Timestamp } = getAdmin();
  const ref = db.collection(CHALLENGES_COLLECTION).doc(challengeId.trim());
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "2FA login session expired. Please sign in again.");
  }

  const c = snap.data()!;
  if (c.consumed === true) {
    throw new HttpsError("failed-precondition", "This 2FA challenge has already been used.");
  }
  if (c.expiresAt && c.expiresAt.toMillis() < Date.now()) {
    throw new HttpsError("deadline-exceeded", "2FA session expired. Please sign in again.");
  }

  const profile = await getActiveAdminProfile(c.uid);
  const secretSnap = await db.collection(SECRETS_COLLECTION).doc(profile.uid).get();
  const secretData = secretSnap.exists ? secretSnap.data() || {} : {};

  if (c.purpose === "login" && secretData.emailOtpEnabled !== true) {
    throw new HttpsError("permission-denied", "Email OTP is not enabled for your admin account.");
  }

  const sentCount = Number(c.emailOtpSentCount || 0);
  if (sentCount >= MAX_EMAIL_SENDS_PER_CHALLENGE) {
    throw new HttpsError("resource-exhausted", "Maximum email OTP resends reached. Please sign in again.");
  }

  const lastSentMs = c.lastEmailSentAt ? c.lastEmailSentAt.toMillis() : 0;
  const elapsed = Date.now() - lastSentMs;
  if (lastSentMs > 0 && elapsed < EMAIL_RESEND_COOLDOWN_MS) {
    const waitSec = Math.ceil((EMAIL_RESEND_COOLDOWN_MS - elapsed) / 1000);
    throw new HttpsError("resource-exhausted", `Please wait ${waitSec}s before requesting another code.`);
  }

  const otp = String(crypto.randomInt(100000, 1000000));
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = hashEmailOtp(otp, salt);

  await sendOtpEmail(
    profile.email || c.email,
    otp,
    profile.fullName,
    c.purpose === "enroll" ? "Mandatory 2FA Setup" : "Admin Sign-In"
  );

  await ref.update({
    emailOtpSalt: salt,
    emailOtpHash: hash,
    emailOtpExpiresAt: Timestamp.fromMillis(Date.now() + EMAIL_OTP_TTL_MS),
    emailOtpSentCount: sentCount + 1,
    lastEmailSentAt: Timestamp.now(),
  });

  return {
    sent: true,
    emailMasked: maskEmail(profile.email || c.email),
    cooldownSeconds: Math.floor(EMAIL_RESEND_COOLDOWN_MS / 1000),
  };
});

// ================= CALLABLE: VERIFY 2FA LOGIN CHALLENGE =================

export const verifyAdmin2faLogin = onCall(async (request) => {
  const { challengeId, code, method = "totp" } = request.data || {};
  if (!challengeId || typeof challengeId !== "string" || !code || typeof code !== "string") {
    throw new HttpsError("invalid-argument", "Challenge ID and verification code are required.");
  }

  const { db, auth, Timestamp } = getAdmin();
  const challengeRef = db.collection(CHALLENGES_COLLECTION).doc(challengeId.trim());

  // First check challenge & secret outside/inside transaction cleanly
  const preSnap = await challengeRef.get();
  if (!preSnap.exists) {
    throw new HttpsError("not-found", "2FA session expired. Please sign in again.");
  }
  const preChallenge = preSnap.data()!;
  if (preChallenge.purpose !== "login") {
    throw new HttpsError("permission-denied", "Invalid challenge type.");
  }

  const uid = preChallenge.uid as string;
  await getActiveAdminProfile(uid);

  const secretRef = db.collection(SECRETS_COLLECTION).doc(uid);
  const secretSnap = await secretRef.get();
  if (!secretSnap.exists || secretSnap.data()?.enabled !== true) {
    throw new HttpsError("failed-precondition", "2FA is not configured for this account.");
  }

  const secretData = secretSnap.data()!;
  let decryptedTotpSecret: Buffer | null = null;
  if (method === "totp" && secretData.totpSecretEnc) {
    const base32 = await decryptSecret(secretData.totpSecretEnc);
    decryptedTotpSecret = base32Decode(base32);
  }

  await db.runTransaction(async (tx) => {
    const cSnap = await tx.get(challengeRef);
    const sSnap = await tx.get(secretRef);

    if (!cSnap.exists) {
      throw new HttpsError("not-found", "2FA session expired. Please sign in again.");
    }
    const c = cSnap.data()!;
    if (c.consumed === true) {
      throw new HttpsError("failed-precondition", "2FA challenge already consumed.");
    }
    if (c.expiresAt && c.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("deadline-exceeded", "2FA session expired. Please sign in again.");
    }
    const attempts = Number(c.attempts || 0);
    if (attempts >= MAX_CHALLENGE_ATTEMPTS) {
      throw new HttpsError("resource-exhausted", "Too many invalid codes. Please sign in again.");
    }

    const s = sSnap.data() || {};
    let verified = false;
    const secretUpdates: Record<string, any> = {};

    if (method === "totp") {
      if (s.totpEnabled !== true || !decryptedTotpSecret) {
        throw new HttpsError("failed-precondition", "Authenticator App (TOTP) is not enabled.");
      }
      const lastUsedStep = typeof s.lastUsedTotpStep === "number" ? s.lastUsedTotpStep : null;
      const matchedStep = verifyTotpCode(decryptedTotpSecret, code, lastUsedStep);
      if (matchedStep !== null) {
        verified = true;
        secretUpdates.lastUsedTotpStep = matchedStep;
        secretUpdates.lastVerifiedAt = Timestamp.now();
      }
    } else if (method === "email") {
      if (s.emailOtpEnabled !== true) {
        throw new HttpsError("failed-precondition", "Email OTP is not enabled for this account.");
      }
      if (!c.emailOtpHash || !c.emailOtpSalt) {
        throw new HttpsError("failed-precondition", "Request an Email OTP code first.");
      }
      if (c.emailOtpExpiresAt && c.emailOtpExpiresAt.toMillis() < Date.now()) {
        throw new HttpsError("deadline-exceeded", "Email code has expired. Request a new code.");
      }
      const normalized = code.replace(/\s+/g, "").trim();
      if (/^\d{6}$/.test(normalized)) {
        const expectedHash = hashEmailOtp(normalized, c.emailOtpSalt);
        if (constantTimeEqual(expectedHash, c.emailOtpHash)) {
          verified = true;
          secretUpdates.lastVerifiedAt = Timestamp.now();
        }
      }
    } else if (method === "backup_code") {
      const codes: StoredBackupCode[] = Array.isArray(s.backupCodeHashes)
        ? [...s.backupCodeHashes]
        : [];
      const matchIndex = findMatchingBackupCodeIndex(codes, code);
      if (matchIndex !== -1) {
        verified = true;
        codes[matchIndex] = {
          ...codes[matchIndex],
          used: true,
          usedAt: Timestamp.now(),
        };
        secretUpdates.backupCodeHashes = codes;
        secretUpdates.lastVerifiedAt = Timestamp.now();
      }
    } else {
      throw new HttpsError("invalid-argument", "Unsupported 2FA verification method.");
    }

    if (!verified) {
      tx.update(challengeRef, { attempts: attempts + 1 });
      const remaining = MAX_CHALLENGE_ATTEMPTS - (attempts + 1);
      throw new HttpsError(
        "unauthenticated",
        remaining > 0
          ? `Invalid verification code. ${remaining} attempt${remaining === 1 ? "" : "s"} remaining.`
          : "Too many failed attempts. Please sign in again."
      );
    }

    tx.update(challengeRef, {
      consumed: true,
      consumedAt: Timestamp.now(),
      verifiedMethod: method,
    });
    if (Object.keys(secretUpdates).length > 0) {
      tx.update(secretRef, secretUpdates);
    }
  });

  try {
    await auth.setCustomUserClaims(uid, {
      mfa_verified: true,
      admin_session: true,
      mfa_verified_at: Date.now(),
    });
  } catch (claimErr: any) {
    logger.warn("Could not set custom user claims in verifyAdmin2faLogin:", claimErr);
  }

  return {
    verified: true,
  };
});

// ================= CALLABLE: GET CURRENT ADMIN 2FA STATUS =================

export const getAdmin2faStatus = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const profile = await getActiveAdminProfile(request.auth.uid);
  const { db } = getAdmin();
  const [secretSnap, globalCfg] = await Promise.all([
    db.collection(SECRETS_COLLECTION).doc(profile.uid).get(),
    getGlobal2faSettingsInternal(),
  ]);

  const s = secretSnap.exists ? secretSnap.data() || {} : {};
  const backupCodes: StoredBackupCode[] = Array.isArray(s.backupCodeHashes)
    ? s.backupCodeHashes
    : [];

  return {
    enabled: s.enabled === true,
    totpEnabled: s.totpEnabled === true,
    emailOtpEnabled: s.emailOtpEnabled === true,
    preferredMethod: s.preferredMethod || (s.totpEnabled === true ? "totp" : "email"),
    backupCodesRemaining: backupCodes.filter((c) => c && !c.used).length,
    backupCodesTotal: backupCodes.length,
    smtpConfigured: globalCfg.enabled,
    require2faForAllAdmins: globalCfg.require2faForAllAdmins,
    sessionMfaVerified: request.auth.token?.mfa_verified === true,
    email: profile.email,
    isSuperAdmin: profile.isSuperAdmin,
  };
});

// ================= CALLABLE: BEGIN TOTP SETUP =================

export const beginAdminTotpSetup = onCall(async (request) => {
  const { challengeId } = request.data || {};
  const ctx = await resolveChallengeOrAuthUid(request, challengeId, "enroll");

  const secretBytes = crypto.randomBytes(20);
  const secretBase32 = base32Encode(secretBytes);
  const encryptedPending = await encryptSecret(secretBase32);
  const otpauthUri = buildOtpAuthUri(secretBase32, ctx.email || ctx.uid, "Haujzo Portal");

  const { db, Timestamp } = getAdmin();
  await db.collection(SECRETS_COLLECTION).doc(ctx.uid).set(
    {
      totpPendingSecretEnc: encryptedPending,
      totpPendingCreatedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    },
    { merge: true }
  );

  return {
    secretBase32,
    otpauthUri,
    issuer: "Haujzo Portal",
    accountEmail: ctx.email,
  };
});

// ================= CALLABLE: CONFIRM TOTP SETUP =================

export const confirmAdminTotpSetup = onCall(async (request) => {
  const { code, challengeId } = request.data || {};
  if (!code || typeof code !== "string") {
    throw new HttpsError("invalid-argument", "6-digit authenticator code is required.");
  }

  const ctx = await resolveChallengeOrAuthUid(request, challengeId, "enroll");
  const { db, auth, Timestamp, FieldValue } = getAdmin();
  const secretRef = db.collection(SECRETS_COLLECTION).doc(ctx.uid);
  const snap = await secretRef.get();

  if (!snap.exists || !snap.data()?.totpPendingSecretEnc) {
    throw new HttpsError("failed-precondition", "Start TOTP setup first before confirming a code.");
  }

  const pendingBase32 = await decryptSecret(snap.data()!.totpPendingSecretEnc);
  const secretBuf = base32Decode(pendingBase32);
  const matchedStep = verifyTotpCode(secretBuf, code, null);

  if (matchedStep === null) {
    throw new HttpsError("invalid-argument", "Invalid 6-digit code. Ensure your device clock is synced and try again.");
  }

  const existingData = snap.data() || {};
  const existingBackupCodes: StoredBackupCode[] = Array.isArray(existingData.backupCodeHashes)
    ? existingData.backupCodeHashes
    : [];
  const unusedCount = existingBackupCodes.filter((c) => c && !c.used).length;

  let plaintextBackupCodes: string[] = [];
  let storedBackupCodes = existingBackupCodes;
  if (unusedCount === 0) {
    const generated = generateBackupCodes(8);
    plaintextBackupCodes = generated.plaintext;
    storedBackupCodes = generated.stored;
  }

  const finalEncryptedSecret = await encryptSecret(pendingBase32);
  const methods = ["totp"];
  if (existingData.emailOtpEnabled === true) methods.push("email");

  await secretRef.set(
    {
      enabled: true,
      totpEnabled: true,
      totpSecretEnc: finalEncryptedSecret,
      totpPendingSecretEnc: FieldValue.delete(),
      totpPendingCreatedAt: FieldValue.delete(),
      lastUsedTotpStep: matchedStep,
      preferredMethod: existingData.preferredMethod || "totp",
      backupCodeHashes: storedBackupCodes,
      enrolledAt: existingData.enrolledAt || Timestamp.now(),
      updatedAt: Timestamp.now(),
    },
    { merge: true }
  );

  await db.collection("Users").doc(ctx.uid).set(
    {
      twoFactorEnabled: true,
      twoFactorMethods: methods,
      twoFactorUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  if (ctx.challengeRef) {
    await ctx.challengeRef.update({
      consumed: true,
      consumedAt: Timestamp.now(),
      verifiedMethod: "totp_enroll",
    });
  }

  try {
    await auth.setCustomUserClaims(ctx.uid, {
      mfa_verified: true,
      admin_session: true,
      mfa_verified_at: Date.now(),
    });
  } catch (claimErr: any) {
    logger.warn("Could not set custom user claims in confirmAdminTotpSetup:", claimErr);
  }

  return {
    enabled: true,
    backupCodes: plaintextBackupCodes,
    backupCodesGenerated: plaintextBackupCodes.length > 0,
  };
});

// ================= CALLABLE: EMAIL OTP SETUP (SEND & CONFIRM) =================

export const sendAdmin2faSetupEmailOtp = onCall(async (request) => {
  const { challengeId } = request.data || {};
  const ctx = await resolveChallengeOrAuthUid(request, challengeId, "enroll");

  const { db, Timestamp } = getAdmin();
  const otp = String(crypto.randomInt(100000, 1000000));
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = hashEmailOtp(otp, salt);

  await sendOtpEmail(ctx.email, otp, ctx.fullName, "2FA Email Verification Setup");

  await db.collection(SECRETS_COLLECTION).doc(ctx.uid).set(
    {
      emailSetupOtpSalt: salt,
      emailSetupOtpHash: hash,
      emailSetupOtpExpiresAt: Timestamp.fromMillis(Date.now() + EMAIL_OTP_TTL_MS),
      updatedAt: Timestamp.now(),
    },
    { merge: true }
  );

  return {
    sent: true,
    emailMasked: maskEmail(ctx.email),
  };
});

export const confirmAdminEmailOtpSetup = onCall(async (request) => {
  const { code, challengeId } = request.data || {};
  if (!code || typeof code !== "string") {
    throw new HttpsError("invalid-argument", "6-digit email verification code is required.");
  }

  const ctx = await resolveChallengeOrAuthUid(request, challengeId, "enroll");
  const { db, auth, Timestamp, FieldValue } = getAdmin();
  const secretRef = db.collection(SECRETS_COLLECTION).doc(ctx.uid);
  const snap = await secretRef.get();
  const s = snap.exists ? snap.data() || {} : {};

  if (!s.emailSetupOtpHash || !s.emailSetupOtpSalt) {
    throw new HttpsError("failed-precondition", "Send an email verification code first.");
  }
  if (s.emailSetupOtpExpiresAt && s.emailSetupOtpExpiresAt.toMillis() < Date.now()) {
    throw new HttpsError("deadline-exceeded", "Email verification code expired. Send a new one.");
  }

  const normalized = code.replace(/\s+/g, "").trim();
  if (!/^\d{6}$/.test(normalized)) {
    throw new HttpsError("invalid-argument", "Enter a valid 6-digit code.");
  }
  const expectedHash = hashEmailOtp(normalized, s.emailSetupOtpSalt);
  if (!constantTimeEqual(expectedHash, s.emailSetupOtpHash)) {
    throw new HttpsError("unauthenticated", "Invalid email verification code.");
  }

  const existingBackupCodes: StoredBackupCode[] = Array.isArray(s.backupCodeHashes)
    ? s.backupCodeHashes
    : [];
  const unusedCount = existingBackupCodes.filter((c) => c && !c.used).length;

  let plaintextBackupCodes: string[] = [];
  let storedBackupCodes = existingBackupCodes;
  if (unusedCount === 0) {
    const generated = generateBackupCodes(8);
    plaintextBackupCodes = generated.plaintext;
    storedBackupCodes = generated.stored;
  }

  const methods: string[] = [];
  if (s.totpEnabled === true) methods.push("totp");
  methods.push("email");

  await secretRef.set(
    {
      enabled: true,
      emailOtpEnabled: true,
      preferredMethod: s.totpEnabled === true ? (s.preferredMethod || "totp") : "email",
      emailSetupOtpSalt: FieldValue.delete(),
      emailSetupOtpHash: FieldValue.delete(),
      emailSetupOtpExpiresAt: FieldValue.delete(),
      backupCodeHashes: storedBackupCodes,
      enrolledAt: s.enrolledAt || Timestamp.now(),
      updatedAt: Timestamp.now(),
    },
    { merge: true }
  );

  await db.collection("Users").doc(ctx.uid).set(
    {
      twoFactorEnabled: true,
      twoFactorMethods: methods,
      twoFactorUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  if (ctx.challengeRef) {
    await ctx.challengeRef.update({
      consumed: true,
      consumedAt: Timestamp.now(),
      verifiedMethod: "email_enroll",
    });
  }

  try {
    await auth.setCustomUserClaims(ctx.uid, {
      mfa_verified: true,
      admin_session: true,
      mfa_verified_at: Date.now(),
    });
  } catch (claimErr: any) {
    logger.warn("Could not set custom user claims in confirmAdminEmailOtpSetup:", claimErr);
  }

  return {
    enabled: true,
    emailOtpEnabled: true,
    backupCodes: plaintextBackupCodes,
    backupCodesGenerated: plaintextBackupCodes.length > 0,
  };
});

// ================= STEP-UP HELPER FOR SENSITIVE 2FA CHANGES =================

async function verifyStepUpCodeForUser(
  uid: string,
  code: string,
  method: "totp" | "backup_code" | "email"
): Promise<void> {
  const { db, Timestamp } = getAdmin();
  const secretRef = db.collection(SECRETS_COLLECTION).doc(uid);
  const snap = await secretRef.get();
  if (!snap.exists || snap.data()?.enabled !== true) return;

  const s = snap.data()!;
  if (method === "totp") {
    if (s.totpEnabled !== true || !s.totpSecretEnc) {
      throw new HttpsError("failed-precondition", "TOTP is not enabled.");
    }
    const base32 = await decryptSecret(s.totpSecretEnc);
    const matchedStep = verifyTotpCode(
      base32Decode(base32),
      code,
      typeof s.lastUsedTotpStep === "number" ? s.lastUsedTotpStep : null
    );
    if (matchedStep === null) {
      throw new HttpsError("unauthenticated", "Invalid 6-digit authenticator code.");
    }
    await secretRef.update({ lastUsedTotpStep: matchedStep });
    return;
  }

  if (method === "backup_code") {
    const codes: StoredBackupCode[] = Array.isArray(s.backupCodeHashes) ? [...s.backupCodeHashes] : [];
    const idx = findMatchingBackupCodeIndex(codes, code);
    if (idx === -1) {
      throw new HttpsError("unauthenticated", "Invalid or already used backup recovery code.");
    }
    codes[idx] = { ...codes[idx], used: true, usedAt: Timestamp.now() };
    await secretRef.update({ backupCodeHashes: codes });
    return;
  }

  if (method === "email") {
    if (!s.emailSetupOtpHash || !s.emailSetupOtpSalt) {
      throw new HttpsError("failed-precondition", "Request an email verification code first.");
    }
    if (s.emailSetupOtpExpiresAt && s.emailSetupOtpExpiresAt.toMillis() < Date.now()) {
      throw new HttpsError("deadline-exceeded", "Email verification code expired.");
    }
    const expected = hashEmailOtp(code.replace(/\s+/g, "").trim(), s.emailSetupOtpSalt);
    if (!constantTimeEqual(expected, s.emailSetupOtpHash)) {
      throw new HttpsError("unauthenticated", "Invalid email verification code.");
    }
    return;
  }

  throw new HttpsError("invalid-argument", "Unsupported verification method.");
}

// ================= CALLABLE: REGENERATE BACKUP CODES =================

export const regenerateAdminBackupCodes = onCall(async (request) => {
  const profile = await assertAdmin2faSession(request.auth);
  const { code, method = "totp" } = request.data || {};
  if (!code || typeof code !== "string") {
    throw new HttpsError("invalid-argument", "Verification code is required to regenerate backup codes.");
  }

  await verifyStepUpCodeForUser(profile.uid, code, method);
  const generated = generateBackupCodes(8);

  const { db, Timestamp } = getAdmin();
  await db.collection(SECRETS_COLLECTION).doc(profile.uid).update({
    backupCodeHashes: generated.stored,
    updatedAt: Timestamp.now(),
  });

  return { backupCodes: generated.plaintext };
});

// ================= CALLABLE: DISABLE 2FA METHOD OR ALL 2FA =================

export const disableAdmin2faMethod = onCall(async (request) => {
  const profile = await assertAdmin2faSession(request.auth);
  const { target = "all", code, method = "totp" } = request.data || {};
  if (!code || typeof code !== "string") {
    throw new HttpsError("invalid-argument", "Current 2FA code is required to make security changes.");
  }

  const { db, FieldValue, Timestamp } = getAdmin();
  const globalCfg = await getGlobal2faSettingsInternal();
  const secretRef = db.collection(SECRETS_COLLECTION).doc(profile.uid);
  const snap = await secretRef.get();
  if (!snap.exists || snap.data()?.enabled !== true) {
    return { enabled: false };
  }

  const s = snap.data()!;
  const willLeaveNoMethod =
    target === "all" ||
    (target === "totp" && s.emailOtpEnabled !== true) ||
    (target === "email" && s.totpEnabled !== true);

  if (willLeaveNoMethod && globalCfg.require2faForAllAdmins) {
    throw new HttpsError(
      "failed-precondition",
      "Organization policy requires 2FA for all admins. Keep at least one 2FA method active."
    );
  }

  await verifyStepUpCodeForUser(profile.uid, code, method);

  const nextTotp = target === "totp" || target === "all" ? false : s.totpEnabled === true;
  const nextEmail = target === "email" || target === "all" ? false : s.emailOtpEnabled === true;
  const nextEnabled = nextTotp || nextEmail;

  const updates: Record<string, any> = {
    enabled: nextEnabled,
    totpEnabled: nextTotp,
    emailOtpEnabled: nextEmail,
    preferredMethod: nextTotp ? "totp" : "email",
    updatedAt: Timestamp.now(),
  };

  if (!nextTotp) {
    updates.totpSecretEnc = FieldValue.delete();
    updates.lastUsedTotpStep = FieldValue.delete();
  }
  if (!nextEnabled) {
    updates.backupCodeHashes = [];
  }

  await secretRef.set(updates, { merge: true });

  const methods: string[] = [];
  if (nextTotp) methods.push("totp");
  if (nextEmail) methods.push("email");

  await db.collection("Users").doc(profile.uid).set(
    {
      twoFactorEnabled: nextEnabled,
      twoFactorMethods: methods,
      twoFactorUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return {
    enabled: nextEnabled,
    totpEnabled: nextTotp,
    emailOtpEnabled: nextEmail,
  };
});

// ================= CALLABLE: SUPER ADMIN RESET USER 2FA =================

export const adminResetUser2fa = onCall(async (request) => {
  const caller = await assertAdmin2faSession(request.auth);
  if (!caller.isSuperAdmin) {
    throw new HttpsError("permission-denied", "Only Super Administrators can reset another admin's 2FA.");
  }

  const { targetUid } = request.data || {};
  if (!targetUid || typeof targetUid !== "string") {
    throw new HttpsError("invalid-argument", "targetUid is required.");
  }

  const { db, auth, FieldValue } = getAdmin();
  await db.collection(SECRETS_COLLECTION).doc(targetUid).delete();
  await db.collection("Users").doc(targetUid).set(
    {
      twoFactorEnabled: false,
      twoFactorMethods: [],
      twoFactorResetBy: caller.email,
      twoFactorUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  try {
    await auth.revokeRefreshTokens(targetUid);
  } catch (_) {}

  return { reset: true, targetUid };
});

// ================= CALLABLE: SUPER ADMIN GLOBAL 2FA & SMTP SETTINGS =================

export const getAdmin2faGlobalSettings = onCall(async (request) => {
  const caller = await assertAdmin2faSession(request.auth);
  if (!caller.isSuperAdmin) {
    throw new HttpsError("permission-denied", "Only Super Administrators can view global 2FA & SMTP settings.");
  }

  const cfg = await getGlobal2faSettingsInternal();
  return {
    enabled: cfg.enabled,
    smtpHost: cfg.smtpHost,
    smtpPort: cfg.smtpPort,
    smtpSecure: cfg.smtpSecure,
    smtpUser: cfg.smtpUser,
    hasSmtpPass: Boolean(cfg.smtpPass),
    fromName: cfg.fromName,
    fromEmail: cfg.fromEmail,
    require2faForAllAdmins: cfg.require2faForAllAdmins,
  };
});

export const saveAdmin2faGlobalSettings = onCall(async (request) => {
  const caller = await assertAdmin2faSession(request.auth);
  if (!caller.isSuperAdmin) {
    throw new HttpsError("permission-denied", "Only Super Administrators can update global 2FA & SMTP settings.");
  }

  const {
    smtpHost = "",
    smtpPort = 587,
    smtpSecure = false,
    smtpUser = "",
    smtpPass = "",
    fromName = "Haujzo Portal Security",
    fromEmail = "",
    require2faForAllAdmins = false,
  } = request.data || {};

  const { db, FieldValue } = getAdmin();
  const payload: Record<string, any> = {
    smtpHost: smtpHost.toString().trim(),
    smtpPort: Number(smtpPort) || 587,
    smtpSecure: Boolean(smtpSecure),
    smtpUser: smtpUser.toString().trim(),
    fromName: fromName.toString().trim() || "Haujzo Portal Security",
    fromEmail: (fromEmail || smtpUser).toString().trim(),
    require2faForAllAdmins: Boolean(require2faForAllAdmins),
    enabled: Boolean(smtpHost.toString().trim() && smtpUser.toString().trim()),
    updatedBy: caller.email,
    updatedAt: FieldValue.serverTimestamp(),
  };

  const cleanPass = smtpPass.toString().trim();
  if (cleanPass.length > 0) {
    payload.smtpPassEnc = await encryptSecret(cleanPass);
    payload.smtpPass = FieldValue.delete();
  }

  await db.doc(GLOBAL_2FA_SETTINGS_DOC).set(payload, { merge: true });
  return { saved: true };
});

export const sendTestAdmin2faEmail = onCall(async (request) => {
  const caller = await assertAdmin2faSession(request.auth);
  if (!caller.isSuperAdmin) {
    throw new HttpsError("permission-denied", "Only Super Administrators can test SMTP settings.");
  }

  const targetEmail = (request.data?.testEmail || caller.email || "").toString().trim();
  if (!targetEmail) {
    throw new HttpsError("invalid-argument", "A destination email address is required.");
  }

  await sendOtpEmail(targetEmail, "123456", caller.fullName, "SMTP Configuration Test");
  return { sent: true, to: targetEmail };
});
