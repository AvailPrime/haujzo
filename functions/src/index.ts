import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";
import * as crypto from "crypto";

import * as admin from "firebase-admin";
import { assertAdmin2faSession } from "./admin2fa";

export {
  beginAdmin2faLogin,
  sendAdmin2faLoginEmailOtp,
  verifyAdmin2faLogin,
  getAdmin2faStatus,
  beginAdminTotpSetup,
  confirmAdminTotpSetup,
  sendAdmin2faSetupEmailOtp,
  confirmAdminEmailOtpSetup,
  regenerateAdminBackupCodes,
  disableAdmin2faMethod,
  adminResetUser2fa,
  getAdmin2faGlobalSettings,
  saveAdmin2faGlobalSettings,
  sendTestAdmin2faEmail,
} from "./admin2fa";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

setGlobalOptions({ maxInstances: 10 });

function getAdmin() {
  return {
    db: admin.firestore(),
    messaging: admin.messaging(),
    FieldValue: admin.firestore.FieldValue,
  };
}

const SETTINGS_DOC_PATH = "Settings/GLOBAL_SETTINGS";

// ================= HELPER: GET PAYSTACK KEYS =================
/**
 * Fetches the Paystack Secret Key & Public Key from Firestore (`app_settings/payment_gateway`).
 * Supports liveSecretKey and livePublicKey configured in app_settings/payment_gateway.
 */
async function getPaystackKeys(): Promise<{ secretKey: string; publicKey: string }> {
  const { db } = getAdmin();

  const extractFromData = (data: any): { secretKey: string; publicKey: string } | null => {
    if (!data || typeof data !== "object") return null;

    const isSandbox = data.isPaystackSandboxMode === true || data.isSandbox === true || data.isLive === false;

    const liveSecret = (
      data.liveSecretKey ||
      data.paystackLiveSecretKey ||
      data.secretKey ||
      data.secret_key ||
      ""
    ).toString().trim();

    const testSecret = (
      data.testSecretKey ||
      data.paystackTestSecretKey ||
      ""
    ).toString().trim();

    const livePublic = (
      data.livePublicKey ||
      data.paystackLivePublicKey ||
      data.publicKey ||
      data.public_key ||
      ""
    ).toString().trim();

    const testPublic = (
      data.testPublicKey ||
      data.paystackTestPublicKey ||
      ""
    ).toString().trim();

    const secretKey = isSandbox && testSecret ? testSecret : (liveSecret || testSecret);
    const publicKey = isSandbox && testPublic ? testPublic : (livePublic || testPublic);

    if (secretKey) {
      return { secretKey, publicKey };
    }
    return null;
  };

  // 1. Primary: app_settings/payment_gateway document
  const gatewayDoc = await db.collection("app_settings").doc("payment_gateway").get();
  if (gatewayDoc.exists) {
    const keys = extractFromData(gatewayDoc.data());
    if (keys) return keys;

    // Check if there is a nested subcollection under app_settings/payment_gateway
    try {
      const subCols = await gatewayDoc.ref.listCollections();
      for (const col of subCols) {
        const snap = await col.limit(5).get();
        for (const doc of snap.docs) {
          const subKeys = extractFromData(doc.data());
          if (subKeys) return subKeys;
        }
      }
    } catch (_) {}
  }

  // 2. Fallback: scan all docs in app_settings in case keys or payment_gateway subcollection are nested
  try {
    const appSettingsSnap = await db.collection("app_settings").get();
    for (const doc of appSettingsSnap.docs) {
      const keys = extractFromData(doc.data());
      if (keys) return keys;
      try {
        const subSnap = await doc.ref.collection("payment_gateway").limit(5).get();
        for (const subDoc of subSnap.docs) {
          const subKeys = extractFromData(subDoc.data());
          if (subKeys) return subKeys;
        }
      } catch (_) {}
    }
  } catch (_) {}

  // 3. Fallback: top-level payment_gateway collection or collectionGroup
  try {
    const pgSnap = await db.collectionGroup("payment_gateway").limit(5).get();
    for (const doc of pgSnap.docs) {
      const keys = extractFromData(doc.data());
      if (keys) return keys;
    }
  } catch (_) {}

  // 4. Fallback: Settings/GLOBAL_SETTINGS or Settings/payment_gateway
  const globalDoc = await db.doc(SETTINGS_DOC_PATH).get();
  if (globalDoc.exists) {
    const keys = extractFromData(globalDoc.data());
    if (keys) return keys;
  }

  throw new Error("Paystack Secret Key not found in Firestore (app_settings/payment_gateway).");
}

async function getPaystackSecretKey(): Promise<string> {
  const { secretKey } = await getPaystackKeys();
  return secretKey;
}

/**
 * Helper to perform POST requests to Paystack API using native fetch.
 */
async function paystackPost(endpoint: string, secretKey: string, payload: any): Promise<any> {
  const response = await fetch(`https://api.paystack.co${endpoint}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const data: any = await response.json().catch(() => ({}));
  if (!response.ok) {
    const errMsg = data?.message || data?.data?.message || `Paystack HTTP ${response.status}`;
    const err: any = new Error(errMsg);
    err.responseData = data;
    throw err;
  }
  return data;
}

/**
 * Helper to perform GET requests to Paystack API using native fetch.
 */
async function paystackGet(endpoint: string, secretKey: string): Promise<any> {
  const response = await fetch(`https://api.paystack.co${endpoint}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/json",
    },
  });

  const data: any = await response.json().catch(() => ({}));
  if (!response.ok) {
    const errMsg = data?.message || data?.data?.message || `Paystack HTTP ${response.status}`;
    const err: any = new Error(errMsg);
    err.responseData = data;
    throw err;
  }
  return data;
}

/**
 * Idempotently settles a driver's platform commission fee in Firestore when Paystack confirms payment.
 */
async function settleDriverCommissionInFirestore(params: {
  driverId: string;
  reference: string;
  usdAmount: number;
  ghsAmount: number;
  phone?: string;
  network?: string;
}) {
  const { db, FieldValue } = getAdmin();
  const { driverId, reference, usdAmount, ghsAmount, phone, network } = params;
  if (!driverId || !reference) return;

  const driverRef = db.collection("drivers").doc(driverId);
  const txId = `paystack_${reference}`;
  const txRef = driverRef.collection("transactions").doc(txId);

  const existingTx = await txRef.get();
  if (existingTx.exists) {
    logger.info(`Commission settlement ${txId} already recorded for driver ${driverId}.`);
    return;
  }

  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) return;

  const driverData = driverSnap.data() || {};
  const currentCommissionOwed = Number(driverData.commissionOwed || 0);
  const currentCommissionPaid = Number(driverData.totalCommissionPaid || 0);

  // If usdAmount was passed in metadata, use it; otherwise if currentCommissionOwed > 0, settle currentCommissionOwed
  const effectiveUsdPaid = usdAmount > 0 ? usdAmount : currentCommissionOwed;
  const newCommissionOwed = Math.max(0, currentCommissionOwed - effectiveUsdPaid);
  const newCommissionPaid = currentCommissionPaid + effectiveUsdPaid;
  const timestampMs = Date.now();

  await driverRef.set(
    {
      commissionOwed: newCommissionOwed,
      totalCommissionPaid: newCommissionPaid,
      isCommissionBlocked: newCommissionOwed > 0.005,
      lastSettledAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await txRef.set(
    {
      id: txId,
      reference: reference,
      type: "commission_settlement",
      amount: effectiveUsdPaid,
      amountGhs: ghsAmount,
      network: network || "Paystack",
      phone: phone || "",
      status: "success",
      timestamp: FieldValue.serverTimestamp(),
      createdAtMs: timestampMs,
    },
    { merge: true }
  );
}

/**
 * Idempotently marks a booking as paid online via Paystack so Customer, Driver, and Admin see it immediately.
 */
async function settleBookingTripPaymentInFirestore(params: {
  bookingId: string;
  userId: string;
  reference: string;
  usdAmount: number;
  ghsAmount: number;
  phone?: string;
  network?: string;
  channel?: string;
}) {
  const { db, messaging, FieldValue } = getAdmin();
  const { bookingId, userId, reference, usdAmount, ghsAmount, phone, network, channel } = params;
  if (!bookingId || !reference) return;

  const bookingRef = db.collection("bookings").doc(bookingId);
  const bookingSnap = await bookingRef.get();
  if (!bookingSnap.exists) {
    logger.warn(`Booking ${bookingId} not found when settling trip payment ${reference}`);
    return;
  }

  const bookingData = bookingSnap.data() || {};
  if (bookingData.paymentStatus === "paid" && bookingData.paymentReference === reference) {
    logger.info(`Booking ${bookingId} already marked paid for reference ${reference}.`);
    return;
  }

  const normalizedStatus = (bookingData.status || "").toString().toLowerCase().trim();
  const isDelivered = normalizedStatus === "delivered" || normalizedStatus === "completed";
  const resolvedUsd = usdAmount > 0 ? usdAmount : Number(bookingData.price || 0);
  const methodLabel = (channel || "").toLowerCase() === "card"
    ? "Paystack Card (Online)"
    : "Paystack (Online)";

  await bookingRef.set(
    {
      initialPaymentMethod: bookingData.initialPaymentMethod || bookingData.paymentMethod || "Cash on Delivery",
      paymentMethod: methodLabel,
      paymentStatus: "paid",
      paidOnline: true,
      paymentReference: reference,
      paymentChannel: channel || "paystack",
      paymentNetwork: network || "Paystack",
      paymentPhone: phone || "",
      paidAmountGhs: ghsAmount,
      paidAmountUsd: resolvedUsd,
      paidByUserId: userId || bookingData.userId || "",
      paidAt: FieldValue.serverTimestamp(),
      driverPayoutStatus: isDelivered ? "ready_for_payout" : "pending_delivery",
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Notify assigned driver immediately so they know NOT to collect cash on delivery
  const driverId = (bookingData.driverId || "").toString().trim();
  if (driverId) {
    try {
      const driverSnap = await db.collection("drivers").doc(driverId).get();
      const fcmToken = driverSnap.data()?.fcmToken;
      if (fcmToken) {
        const displayId = bookingData.bookingId || bookingId;
        await messaging.send({
          token: fcmToken,
          notification: {
            title: "Trip Paid Online ✅",
            body: `Customer paid online for Manifest #${displayId}. Do NOT collect cash on delivery.`,
          },
          data: {
            type: "booking_paid",
            bookingId,
            targetId: bookingId,
          },
        });
      }
    } catch (notifyErr: any) {
      logger.warn(`Failed to notify driver ${driverId} of online payment:`, notifyErr?.message);
    }
  }
}

// ================= INITIALIZE PAYMENT =================
export const initializePayment = onCall(async (request) => {
  try {
    const { email, amount, callback_url, metadata } = request.data || {};
    const userId = request.auth?.uid || metadata?.userId || metadata?.driverId;

    if (!userId) {
      throw new HttpsError("unauthenticated", "User not authenticated");
    }

    if (!email || !amount) {
      throw new HttpsError("invalid-argument", "Missing required fields (email, amount)");
    }

    const { secretKey, publicKey } = await getPaystackKeys();
    const isTripPayment = metadata?.type === "trip_payment";

    const responseData = await paystackPost("/transaction/initialize", secretKey, {
      email,
      amount: Math.round(Number(amount) * 100),
      currency: "GHS",
      callback_url: callback_url || "https://availprime.com/paystack-redirect",
      metadata: {
        userId: userId,
        ...(isTripPayment ? {} : { driverId: userId }),
        ...(metadata || {}),
      },
    });

    return {
      authorization_url: responseData.data.authorization_url,
      access_code: responseData.data.access_code,
      reference: responseData.data.reference,
      publicKey: publicKey,
    };
  } catch (error: any) {
    logger.error("INIT ERROR:", error.responseData || error.message);
    throw new HttpsError(
      "internal",
      error.responseData?.message || error.message || "Failed to initialize payment"
    );
  }
});

// ================= VERIFY PAYMENT =================
export const verifyPaystackPayment = onCall(async (request) => {
  try {
    const { reference, userId, usdAmount, phone, network, type, bookingId } = request.data || {};
    const effectiveUserId = userId || request.auth?.uid;

    if (!reference || !effectiveUserId) {
      throw new HttpsError("invalid-argument", "Missing reference or userId");
    }

    const { db, FieldValue } = getAdmin();
    const secretKey = await getPaystackSecretKey();

    const paymentRef = db.collection("Payments").doc(reference);
    const existingDoc = await paymentRef.get();

    if (existingDoc.exists && existingDoc.data()?.status === "success") {
      const existingData = existingDoc.data() || {};
      const existingBookingId = (bookingId || existingData.bookingId || "").toString().trim();
      const isExistingTrip = type === "trip_payment" || existingData.type === "trip_payment" || Boolean(existingBookingId);

      if (isExistingTrip && existingBookingId) {
        await settleBookingTripPaymentInFirestore({
          bookingId: existingBookingId,
          userId: effectiveUserId,
          reference,
          usdAmount: Number(usdAmount || existingData.usdAmount || 0),
          ghsAmount: Number(existingData.amount || 0),
          phone: phone || existingData.phone,
          network: network || existingData.network,
          channel: existingData.channel,
        });
      } else if (type === "commission_settlement" || existingData.type === "commission_settlement") {
        await settleDriverCommissionInFirestore({
          driverId: effectiveUserId,
          reference,
          usdAmount: Number(usdAmount || existingData.usdAmount || 0),
          ghsAmount: Number(existingData.amount || 0),
          phone: phone || existingData.phone,
          network: network || existingData.network,
        });
      }
      return {
        success: true,
        isPending: false,
        status: "success",
        reference,
        amount: existingData.amount || 0,
      };
    }

    const responseData = await paystackGet(`/transaction/verify/${encodeURIComponent(reference)}`, secretKey);
    const paymentData = responseData?.data;

    if (!paymentData) {
      return { success: false, isPending: false, message: "Transaction data not found" };
    }

    // Convert amount back from Pesewas/Kobo to normal currency
    const normalAmount = Number(paymentData.amount || 0) / 100;
    const meta = paymentData.metadata || {};
    const resolvedBookingId = (bookingId || meta.bookingId || "").toString().trim();
    const isTripPayment =
      type === "trip_payment" ||
      meta.type === "trip_payment" ||
      Boolean(resolvedBookingId);
    const isCommission =
      !isTripPayment &&
      (type === "commission_settlement" || meta.type === "commission_settlement");
    const resolvedUsdAmount = Number(usdAmount || meta.usdAmount || 0);
    const resolvedPhone = phone || meta.phone || paymentData.authorization?.mobile_money_number || "";
    const resolvedNetwork = network || meta.network || paymentData.authorization?.bank || "Mobile Money";

    if (paymentData.status === "success") {
      await paymentRef.set(
        {
          userId: effectiveUserId,
          ...(resolvedBookingId ? { bookingId: resolvedBookingId } : {}),
          reference,
          amount: normalAmount,
          usdAmount: resolvedUsdAmount,
          type: isTripPayment ? "trip_payment" : (isCommission ? "commission_settlement" : (meta.type || "payment")),
          paymentMethod: isTripPayment ? "Paystack (Online)" : resolvedNetwork,
          phone: resolvedPhone,
          network: resolvedNetwork,
          status: "success",
          channel: paymentData.channel || "",
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      if (isTripPayment && resolvedBookingId) {
        await settleBookingTripPaymentInFirestore({
          bookingId: resolvedBookingId,
          userId: effectiveUserId,
          reference,
          usdAmount: resolvedUsdAmount,
          ghsAmount: normalAmount,
          phone: resolvedPhone,
          network: resolvedNetwork,
          channel: paymentData.channel || "",
        });
      } else if (isCommission) {
        await settleDriverCommissionInFirestore({
          driverId: effectiveUserId,
          reference,
          usdAmount: resolvedUsdAmount,
          ghsAmount: normalAmount,
          phone: resolvedPhone,
          network: resolvedNetwork,
        });
      }

      return {
        success: true,
        isPending: false,
        status: "success",
        ...paymentData,
        amount: normalAmount,
      };
    }

    if (
      paymentData.status === "pending" ||
      paymentData.status === "pay_offline" ||
      paymentData.status === "ongoing" ||
      paymentData.status === "send_otp" ||
      paymentData.status === "processing"
    ) {
      return {
        success: false,
        isPending: true,
        status: paymentData.status,
        message: paymentData.gateway_response || "Payment is pending authorization on mobile device",
        ...paymentData,
        amount: normalAmount,
      };
    }

    return {
      success: false,
      isPending: false,
      status: paymentData.status,
      message: paymentData.gateway_response || "Payment not successful",
      ...paymentData,
    };
  } catch (error: any) {
    logger.error("VERIFY ERROR:", error.responseData || error.message);
    throw new HttpsError("internal", error.responseData?.message || error.message);
  }
});

// ================= CHARGE WITH SAVED AUTHORIZATION =================
export const chargeWithAuthorization = onCall(async (request) => {
  try {
    const { email, amount, authorization_code, metadata } = request.data || {};
    const secretKey = await getPaystackSecretKey();

    const responseData = await paystackPost("/transaction/charge_authorization", secretKey, {
      email,
      amount: Math.round(Number(amount) * 100),
      authorization_code,
      currency: "GHS",
      metadata: metadata || {},
    });

    return {
      status: responseData.status,
      data: {
        status: responseData.data.status,
        reference: responseData.data.reference,
        message: responseData.data.gateway_response || responseData.message,
      },
    };
  } catch (error: any) {
    throw new HttpsError("internal", error.responseData?.message || error.message);
  }
});

// ================= SUBMIT PAYSTACK OTP (CARD) =================
export const submitPaystackOtp = onCall(async (request) => {
  try {
    const { otp, reference } = request.data || {};

    if (!otp || !reference) {
      throw new HttpsError("invalid-argument", "Missing OTP or reference");
    }

    const secretKey = await getPaystackSecretKey();

    const responseData = await paystackPost("/transaction/submit_otp", secretKey, {
      otp,
      reference,
    });

    return {
      status: responseData.status,
      data: {
        status: responseData.data.status,
        reference: responseData.data.reference,
      },
    };
  } catch (error: any) {
    logger.error("OTP Submission Error:", error.responseData?.message || error.message);
    throw new HttpsError("internal", error.responseData?.message || "OTP verification failed");
  }
});

// ================= SUBMIT MOMO OTP =================
export const submitMoMoOtp = onCall(async (request) => {
  try {
    const { otp, reference } = request.data || {};

    if (!otp || !reference) {
      throw new HttpsError("invalid-argument", "Missing OTP or reference");
    }

    const secretKey = await getPaystackSecretKey();

    const responseData = await paystackPost("/charge/submit_otp", secretKey, {
      otp,
      reference,
    });

    return {
      status: responseData.status,
      data: {
        status: responseData.data.status,
        reference: responseData.data.reference,
      },
    };
  } catch (error: any) {
    logger.error("MoMo OTP Error:", error.responseData || error.message);
    throw new HttpsError("internal", error.responseData?.message || "OTP verification failed");
  }
});

// ================= CHARGE MOBILE MONEY =================
export const chargeMobileMoney = onCall(async (request) => {
  try {
    const { email, amount, phone, network, metadata } = request.data || {};
    const userId = request.auth?.uid || metadata?.userId || metadata?.driverId;

    if (!email || !amount || !phone || !network) {
      throw new HttpsError("invalid-argument", "Missing required fields (email, amount, phone, network)");
    }

    const secretKey = await getPaystackSecretKey();

    const mapNetwork = (net: string): string => {
      const cleaned = net.toLowerCase().trim();
      if (cleaned.includes("mtn")) return "mtn";
      if (cleaned.includes("telecel") || cleaned.includes("vodafone") || cleaned === "vod") return "vod";
      if (cleaned.includes("airtel") || cleaned.includes("tigo") || cleaned === "atl" || cleaned === "at") return "atl";
      return "mtn";
    };

    // Normalize phone to local 10-digit Ghana format (0XXXXXXXXX) required by Paystack Ghana MoMo charge API
    const formatLocalGhanaPhone = (rawPhone: string): string => {
      const digits = rawPhone.replace(/\D/g, "");
      if (digits.startsWith("233") && digits.length >= 12) {
        return "0" + digits.substring(3);
      }
      if (digits.length === 9 && !digits.startsWith("0")) {
        return "0" + digits;
      }
      return digits || rawPhone.trim();
    };

    const provider = mapNetwork(network);
    const localPhone = formatLocalGhanaPhone(phone.toString());
    const isTripPayment = metadata?.type === "trip_payment";

    const chargePayload = (phoneToUse: string) => ({
      email,
      amount: Math.round(Number(amount) * 100),
      currency: "GHS",
      mobile_money: {
        phone: phoneToUse,
        provider,
      },
      metadata: {
        userId: userId || "",
        ...(isTripPayment ? {} : { driverId: userId || "" }),
        phone: localPhone,
        network,
        ...(metadata || {}),
      },
    });

    let responseData: any;
    try {
      responseData = await paystackPost("/charge", secretKey, chargePayload(localPhone));
    } catch (firstErr: any) {
      // Fallback: if Paystack requests international format 233XXXXXXXXX, try that automatically
      const intlPhone = localPhone.startsWith("0") ? "233" + localPhone.substring(1) : localPhone;
      if (intlPhone !== localPhone) {
        responseData = await paystackPost("/charge", secretKey, chargePayload(intlPhone));
      } else {
        throw firstErr;
      }
    }

    return {
      status: responseData.status,
      data: responseData.data,
    };
  } catch (error: any) {
    logger.error("MOMO CHARGE ERROR:", error.responseData || error.message);
    throw new HttpsError(
      "internal",
      error.responseData?.data?.message || error.responseData?.message || error.message || "MoMo charge failed"
    );
  }
});

// ================= PAYSTACK WEBHOOK =================
export const paystackWebhook = onRequest({ cors: false, invoker: "public" }, async (req, res) => {
  try {
    logger.info("🔥 PAYSTACK WEBHOOK HIT");

    const secret = await getPaystackSecretKey();

    const hash = crypto
      .createHmac("sha512", secret)
      .update(req.rawBody)
      .digest("hex");

    const signature = req.headers["x-paystack-signature"];

    if (hash !== signature) {
      logger.error("❌ Invalid Paystack webhook signature");
      res.status(401).send("Invalid signature");
      return;
    }

    const event = req.body;
    logger.info("PAYSTACK EVENT:", event?.event);

    if (event?.event === "charge.success") {
      const paymentData = event.data;
      const { db, FieldValue } = getAdmin();
      const reference = paymentData.reference;
      const meta = paymentData.metadata || {};

      const userId =
        meta.userId ||
        meta.user_id ||
        meta.driverId ||
        null;

      if (!userId) {
        logger.warn("❌ No userId/driverId in webhook metadata");
        res.status(200).send("No userId");
        return;
      }

      const paymentRef = db.collection("Payments").doc(reference);
      const existingDoc = await paymentRef.get();

      const normalAmount = Number(paymentData.amount || 0) / 100;
      const resolvedBookingId = (meta.bookingId || "").toString().trim();
      const isTripPayment = meta.type === "trip_payment" || Boolean(resolvedBookingId);
      const resolvedPhone = meta.phone || paymentData.authorization?.mobile_money_number || "";
      const resolvedNetwork = meta.network || paymentData.authorization?.bank || "Mobile Money";

      if (!existingDoc.exists) {
        await paymentRef.set({
          userId,
          ...(resolvedBookingId ? { bookingId: resolvedBookingId } : {}),
          reference,
          amount: normalAmount,
          usdAmount: Number(meta.usdAmount || 0),
          type: isTripPayment ? "trip_payment" : (meta.type || "payment"),
          paymentMethod: isTripPayment ? "Paystack (Online)" : resolvedNetwork,
          phone: resolvedPhone,
          network: resolvedNetwork,
          channel: paymentData.channel || "",
          status: "success",
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      if (isTripPayment && resolvedBookingId) {
        await settleBookingTripPaymentInFirestore({
          bookingId: resolvedBookingId,
          userId,
          reference,
          usdAmount: Number(meta.usdAmount || 0),
          ghsAmount: normalAmount,
          phone: resolvedPhone,
          network: resolvedNetwork,
          channel: paymentData.channel || "",
        });
      } else if (meta.type === "commission_settlement" || meta.driverId) {
        await settleDriverCommissionInFirestore({
          driverId: meta.driverId || userId,
          reference,
          usdAmount: Number(meta.usdAmount || 0),
          ghsAmount: normalAmount,
          phone: resolvedPhone,
          network: resolvedNetwork,
        });
      }
    } else if (
      event?.event === "transfer.success" ||
      event?.event === "transfer.failed" ||
      event?.event === "transfer.reversed"
    ) {
      const transferData = event.data || {};
      const { db, FieldValue } = getAdmin();
      const reference = (transferData.reference || "").toString().trim();
      const transferCode = (transferData.transfer_code || "").toString().trim();

      let targetBookingDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
      let isRefundTransfer = false;
      if (reference) {
        const snap = await db
          .collection("bookings")
          .where("driverPayoutReference", "==", reference)
          .limit(1)
          .get();
        if (!snap.empty) targetBookingDoc = snap.docs[0];
      }
      if (!targetBookingDoc && transferCode) {
        const snap = await db
          .collection("bookings")
          .where("pendingDriverTransferCode", "==", transferCode)
          .limit(1)
          .get();
        if (!snap.empty) targetBookingDoc = snap.docs[0];
      }

      if (!targetBookingDoc && reference) {
        const refundSnap = await db
          .collection("bookings")
          .where("refundReference", "==", reference)
          .limit(1)
          .get();
        if (!refundSnap.empty) {
          targetBookingDoc = refundSnap.docs[0];
          isRefundTransfer = true;
        }
      }
      if (!targetBookingDoc && transferCode) {
        const refundSnap = await db
          .collection("bookings")
          .where("pendingRefundTransferCode", "==", transferCode)
          .limit(1)
          .get();
        if (!refundSnap.empty) {
          targetBookingDoc = refundSnap.docs[0];
          isRefundTransfer = true;
        }
      }

      if (targetBookingDoc) {
        const bData = targetBookingDoc.data() || {};
        if (isRefundTransfer) {
          if (event.event === "transfer.success") {
            await recordShipperRefundInFirestore({
              bookingId: targetBookingDoc.id,
              bookingData: bData,
              reference: reference || bData.refundReference || transferCode,
              refundId: transferCode || bData.pendingRefundTransferCode || "",
              usdAmount: Number(bData.refundAmountUsd || bData.paidAmountUsd || bData.price || 0),
              ghsAmount: Number(bData.refundAmountGhs || bData.paidAmountGhs || 0),
              mode: "paystack_transfer_refund",
              methodLabel: (bData.refundMethod || "Paystack Transfer Refund").toString(),
              accountLabel: (bData.refundAccount || "").toString(),
              accountName: (bData.refundAccountName || "").toString(),
              adminUid: (bData.refundedBy || "webhook").toString(),
              notes: (bData.refundNotes || "").toString(),
            });
          } else {
            await targetBookingDoc.ref.set(
              {
                refundStatus: "refund_failed",
                pendingRefundTransferCode: FieldValue.delete(),
                refundFailureReason:
                  transferData.reason ||
                  transferData.gateway_response ||
                  `Refund transfer ${event.event.replace("transfer.", "")}`,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
            if (reference) {
              await db.collection("Payments").doc(reference).set(
                {
                  status: "failed",
                  updatedAt: FieldValue.serverTimestamp(),
                },
                { merge: true }
              );
            }
          }
        } else if (event.event === "transfer.success") {
          await recordDriverPayoutInFirestore({
            bookingId: targetBookingDoc.id,
            bookingData: bData,
            driverId: (bData.driverId || bData.assignedDriverId || bData.companyId || "").toString(),
            reference: reference || bData.driverPayoutReference || transferCode,
            transferCode: transferCode || bData.pendingDriverTransferCode || "",
            usdAmount: Number(bData.driverPayoutAmountUsd || 0),
            ghsAmount: Number(bData.driverPayoutAmountGhs || 0),
            methodLabel: (bData.driverPayoutMethod || "Paystack Transfer").toString(),
            accountLabel: (bData.driverPayoutAccount || "").toString(),
            adminUid: (bData.driverPayoutPaidBy || "webhook").toString(),
            mode: "paystack_transfer",
            notes: (bData.driverPayoutNotes || "").toString(),
          });
        } else {
          await targetBookingDoc.ref.set(
            {
              driverPayoutStatus: "payout_failed",
              pendingDriverTransferCode: FieldValue.delete(),
              driverPayoutFailureReason:
                transferData.reason ||
                transferData.gateway_response ||
                `Transfer ${event.event.replace("transfer.", "")}`,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
          if (reference) {
            await db.collection("Payments").doc(reference).set(
              {
                status: "failed",
                updatedAt: FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          }
        }
      }
    } else if (
      event?.event === "refund.processed" ||
      event?.event === "refund.pending" ||
      event?.event === "refund.failed"
    ) {
      const refundData = event.data || {};
      const { db, FieldValue } = getAdmin();
      const refundId = (refundData.id || "").toString().trim();
      const txRef = (
        refundData.transaction_reference ||
        refundData.transaction?.reference ||
        ""
      ).toString().trim();
      const refundRef = (refundData.reference || "").toString().trim();

      let targetBookingDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
      if (refundId) {
        const snap = await db.collection("bookings").where("refundId", "==", refundId).limit(1).get();
        if (!snap.empty) targetBookingDoc = snap.docs[0];
      }
      if (!targetBookingDoc && refundRef) {
        const snap = await db.collection("bookings").where("refundReference", "==", refundRef).limit(1).get();
        if (!snap.empty) targetBookingDoc = snap.docs[0];
      }
      if (!targetBookingDoc && txRef) {
        const snap = await db.collection("bookings").where("paymentReference", "==", txRef).limit(1).get();
        if (!snap.empty) targetBookingDoc = snap.docs[0];
      }

      if (targetBookingDoc) {
        const bData = targetBookingDoc.data() || {};
        const amountGhs = Number(refundData.amount || 0) / 100;
        const effectiveGhs = amountGhs > 0 ? amountGhs : Number(bData.refundAmountGhs || bData.paidAmountGhs || 0);
        const effectiveUsd = Number(bData.refundAmountUsd || bData.paidAmountUsd || bData.price || 0);

        if (event.event === "refund.processed") {
          await recordShipperRefundInFirestore({
            bookingId: targetBookingDoc.id,
            bookingData: bData,
            reference: refundRef || bData.refundReference || `rfnd_${txRef || targetBookingDoc.id}`,
            refundId: refundId || bData.refundId || "",
            usdAmount: effectiveUsd,
            ghsAmount: effectiveGhs,
            mode: "paystack_refund",
            methodLabel: "Paystack Direct Refund",
            accountLabel: txRef || bData.paymentReference || "",
            accountName: bData.senderName || "",
            adminUid: (bData.refundedBy || "webhook").toString(),
            notes: (bData.refundNotes || refundData.merchant_note || "").toString(),
          });
        } else if (event.event === "refund.failed") {
          await targetBookingDoc.ref.set(
            {
              refundStatus: "refund_failed",
              refundFailureReason: refundData.status || "Paystack refund failed",
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        } else {
          await targetBookingDoc.ref.set(
            {
              refundStatus: "refund_processing",
              ...(refundId ? { refundId } : {}),
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      }
    }

    res.status(200).send("OK");
  } catch (error: any) {
    logger.error("❌ Paystack Webhook error:", error.message);
    res.status(500).send("Error");
  }
});

// ================= DRIVER PAYOUT HELPERS & FUNCTIONS =================

async function assertAdminCaller(
  auth?: { uid: string; token?: admin.auth.DecodedIdToken } | string
): Promise<string> {
  if (typeof auth === "string") {
    const profile = await assertAdmin2faSession({ uid: auth });
    return profile.uid;
  }
  const profile = await assertAdmin2faSession(auth);
  return profile.uid;
}

function isBookingCompletedStatus(status: any): boolean {
  const s = (status || "").toString().toLowerCase().trim();
  if (!s || s.includes("incomplet") || s.includes("uncomplet")) return false;
  return (
    s === "delivered" ||
    s === "completed" ||
    s === "complete" ||
    s === "finished" ||
    s === "ended" ||
    s === "done" ||
    s === "paid" ||
    s === "is_paid" ||
    s.endsWith("_delivered") ||
    s.endsWith("_completed") ||
    s.startsWith("delivered_") ||
    s.startsWith("completed_") ||
    s.includes("trip_complet") ||
    s.includes("delivery_complet")
  );
}

function isBookingCancelledStatus(status: any): boolean {
  const s = (status || "").toString().toLowerCase().trim();
  return s === "cancelled" || s === "canceled";
}

function normalizeAccountNameTokens(name: string): string[] {
  return (name || "")
    .toUpperCase()
    .replace(/[^A-Z0-9\s]/g, " ")
    .split(/\s+/)
    .map((t) => t.trim())
    .filter(Boolean);
}

function doAccountNamesMatch(expectedName: string, resolvedName: string): boolean {
  const tokensA = normalizeAccountNameTokens(expectedName);
  const tokensB = normalizeAccountNameTokens(resolvedName);
  if (tokensA.length === 0 || tokensB.length === 0) return false;
  const normA = tokensA.join(" ");
  const normB = tokensB.join(" ");
  if (normA === normB) return true;
  if (tokensA.length === tokensB.length && tokensA.length >= 2) {
    const sortedA = [...tokensA].sort().join(" ");
    const sortedB = [...tokensB].sort().join(" ");
    return sortedA === sortedB;
  }
  return false;
}

function formatLocalGhanaPhone(rawPhone: string): string {
  const digits = rawPhone.replace(/\D/g, "");
  if (digits.startsWith("233") && digits.length >= 12) {
    return "0" + digits.substring(3);
  }
  if (digits.length === 9 && !digits.startsWith("0")) {
    return "0" + digits;
  }
  return digits || rawPhone.trim();
}

function sanitizeGhanaBankCode(rawCode: string, label?: string): string {
  const clean = `${rawCode || ""} ${label || ""}`.toUpperCase();
  if (clean.includes("MTN")) return "MTN";
  if (clean.includes("TELECEL") || clean.includes("VODAFONE") || clean.trim() === "VOD") return "VOD";
  if (clean.includes("AIRTEL") || clean.includes("TIGO") || clean.trim() === "ATL" || clean.trim() === "AT") {
    return "ATL";
  }
  return (rawCode || "").trim().toUpperCase();
}

async function resolveDriverPayoutSplit(
  bookingData: Record<string, any>,
  fallbackGhsRate = 15.5
): Promise<{
  grossUsd: number;
  platformFeeUsd: number;
  commissionPercent: number;
  driverPayoutUsd: number;
  driverPayoutGhs: number;
}> {
  const { db } = getAdmin();
  const grossUsd = Number(bookingData.price || bookingData.paidAmountUsd || 0);
  const pb = (bookingData.priceBreakdown && typeof bookingData.priceBreakdown === "object")
    ? bookingData.priceBreakdown
    : {};

  let platformFeeUsd = Number(
    bookingData.platformFee ||
      bookingData.commissionFee ||
      pb.platformCommission ||
      pb.platformFee ||
      0
  );
  let commissionPercent = Number(
    bookingData.platformCommissionPercent || pb.platformCommissionPercent || 0
  );

  if (platformFeeUsd <= 0) {
    if (commissionPercent <= 0) {
      // Read dynamic pricing config from app_settings/pricing_config
      try {
        const cfgDoc = await db.collection("app_settings").doc("pricing_config").get();
        const cfg = cfgDoc.data() || {};
        const dist = Number(bookingData.distance || 0);
        const categories = Array.isArray(cfg.journeyCategories) ? cfg.journeyCategories : [];
        const matched = categories.find(
          (c: any) => dist >= Number(c.minKm || 0) && dist <= Number(c.maxKm || 999999)
        );
        commissionPercent = Number(
          matched?.platformCommissionPercent || cfg.platformCommissionPercent || 15
        );
      } catch (_) {
        commissionPercent = 15;
      }
    }
    platformFeeUsd = Number((grossUsd * (commissionPercent / 100)).toFixed(2));
  } else if (commissionPercent <= 0 && grossUsd > 0) {
    commissionPercent = Number(((platformFeeUsd / grossUsd) * 100).toFixed(2));
  }

  const storedDriverPayout = Number(
    bookingData.driverPayout || bookingData.driverNetPayout || pb.driverPayout || 0
  );
  const maxDriverPortion = Number(Math.max(0, grossUsd - platformFeeUsd).toFixed(2));

  // Strictly enforce paying ONLY the driver's portion (never the full gross amount)
  let driverPayoutUsd =
    storedDriverPayout > 0 && (grossUsd <= 0 || storedDriverPayout <= maxDriverPortion + 0.05)
      ? Number(storedDriverPayout.toFixed(2))
      : maxDriverPortion;

  if (grossUsd > 0 && driverPayoutUsd > maxDriverPortion && maxDriverPortion > 0) {
    driverPayoutUsd = maxDriverPortion;
  }

  const paidAmountGhs = Number(bookingData.paidAmountGhs || 0);
  let driverPayoutGhs: number;
  if (paidAmountGhs > 0 && grossUsd > 0) {
    driverPayoutGhs = Number((paidAmountGhs * (driverPayoutUsd / grossUsd)).toFixed(2));
  } else {
    const rate = fallbackGhsRate > 1 ? fallbackGhsRate : 15.5;
    driverPayoutGhs = Number((driverPayoutUsd * rate).toFixed(2));
  }

  return {
    grossUsd,
    platformFeeUsd,
    commissionPercent,
    driverPayoutUsd,
    driverPayoutGhs,
  };
}

async function recordDriverPayoutInFirestore(params: {
  bookingId: string;
  bookingData: Record<string, any>;
  driverId: string;
  reference: string;
  transferCode?: string;
  usdAmount: number;
  ghsAmount: number;
  methodLabel: string;
  accountLabel: string;
  adminUid: string;
  mode: string;
  notes?: string;
}) {
  const { db, messaging, FieldValue } = getAdmin();
  const {
    bookingId,
    bookingData,
    driverId,
    reference,
    transferCode,
    usdAmount,
    ghsAmount,
    methodLabel,
    accountLabel,
    adminUid,
    mode,
    notes,
  } = params;

  const bookingRef = db.collection("bookings").doc(bookingId);
  const nowMs = Date.now();
  const payoutTxId = `payout_${reference}`;

  await bookingRef.set(
    {
      driverPayoutStatus: "paid_out",
      driverPayoutReference: reference,
      driverPayoutTransferCode: transferCode || "",
      pendingDriverTransferCode: FieldValue.delete(),
      driverPayoutFailureReason: FieldValue.delete(),
      driverPayoutAmountUsd: usdAmount,
      driverPayoutAmountGhs: ghsAmount,
      driverPayoutMethod: methodLabel,
      driverPayoutAccount: accountLabel,
      driverPayoutNotes: notes || "",
      driverPayoutPaidBy: adminUid,
      driverPayoutAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Mirror in top-level Payments collection
  await db.collection("Payments").doc(reference).set(
    {
      userId: driverId,
      driverId,
      bookingId,
      reference,
      transferCode: transferCode || "",
      amount: ghsAmount,
      usdAmount,
      type: "driver_payout",
      paymentMethod: methodLabel,
      phone: accountLabel,
      network: methodLabel,
      channel: mode,
      status: "success",
      recordedBy: mode === "paystack_transfer" ? "Admin (Paystack Transfer)" : "Admin (Manual Payout)",
      ...(notes ? { notes } : {}),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  if (driverId) {
    const driverRef = db.collection("drivers").doc(driverId);
    const txRef = driverRef.collection("transactions").doc(payoutTxId);
    const existingTx = await txRef.get();

    if (!existingTx.exists) {
      await txRef.set(
        {
          id: payoutTxId,
          reference,
          bookingId: bookingData.bookingId || bookingId,
          bookingDocId: bookingId,
          type: "driver_payout",
          amount: usdAmount,
          netPayout: usdAmount,
          amountGhs: ghsAmount,
          network: methodLabel,
          phone: accountLabel,
          status: "success",
          recordedBy: mode === "paystack_transfer" ? "Admin (Paystack Transfer)" : "Admin",
          ...(notes ? { notes } : {}),
          timestamp: FieldValue.serverTimestamp(),
          createdAtMs: nowMs,
        },
        { merge: true }
      );

      // Update driver's cumulative paid-out earnings metric
      await driverRef.set(
        {
          totalPayoutsReceived: FieldValue.increment(usdAmount),
          lastPayoutAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // Push notify the driver
      try {
        const driverSnap = await driverRef.get();
        const fcmToken = driverSnap.data()?.fcmToken;
        if (fcmToken) {
          const displayId = bookingData.bookingId || bookingId;
          await messaging.send({
            token: fcmToken,
            notification: {
              title: "Trip Payout Sent! 💰",
              body: `GH₵ ${ghsAmount.toFixed(2)} for Manifest #${displayId} has been paid to ${methodLabel} (${accountLabel}).`,
            },
            data: {
              type: "driver_payout",
              bookingId,
              targetId: bookingId,
              reference,
            },
          });
        }
      } catch (notifyErr: any) {
        logger.warn(`Failed to notify driver ${driverId} of payout:`, notifyErr?.message);
      }
    }
  }
}

// ================= RESOLVE PAYSTACK BANK / MOMO ACCOUNT =================
export const resolvePaystackAccount = onCall(async (request) => {
  try {
    await assertAdminCaller(request.auth);
    const { accountNumber, bankCode, type } = request.data || {};
    if (!accountNumber || !bankCode) {
      throw new HttpsError("invalid-argument", "Account number and bank/network code are required.");
    }

    const secretKey = await getPaystackSecretKey();
    const resolvedCode = sanitizeGhanaBankCode(bankCode.toString());
    const effectiveNumber =
      type === "mobile_money" || ["MTN", "VOD", "ATL"].includes(resolvedCode)
        ? formatLocalGhanaPhone(accountNumber.toString())
        : accountNumber.toString().trim();

    const responseData = await paystackGet(
      `/bank/resolve?account_number=${encodeURIComponent(effectiveNumber)}&bank_code=${encodeURIComponent(resolvedCode)}`,
      secretKey
    );

    return {
      accountName: responseData?.data?.account_name || "",
      accountNumber: responseData?.data?.account_number || effectiveNumber,
      bankCode: resolvedCode,
    };
  } catch (error: any) {
    logger.warn("RESOLVE ACCOUNT:", error.responseData || error.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      error.responseData?.message || error.message || "Could not resolve account name."
    );
  }
});

// ================= FETCH PAYSTACK GHANA BANKS & MOMO PROVIDERS =================
export const getPaystackTransferBanks = onCall(async (request) => {
  try {
    await assertAdminCaller(request.auth);
    const secretKey = await getPaystackSecretKey();
    const [bankRes, momoRes] = await Promise.all([
      paystackGet("/bank?currency=GHS&type=ghipss", secretKey).catch(() => ({ data: [] })),
      paystackGet("/bank?currency=GHS&type=mobile_money", secretKey).catch(() => ({ data: [] })),
    ]);

    return {
      banks: Array.isArray(bankRes?.data) ? bankRes.data : [],
      mobileMoney: Array.isArray(momoRes?.data) ? momoRes.data : [],
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message || "Failed to fetch Paystack banks");
  }
});

// ================= INITIATE DRIVER PORTION PAYOUT =================
export const initiateDriverPayout = onCall(async (request) => {
  try {
    const adminUid = await assertAdminCaller(request.auth);
    const {
      bookingId,
      payoutType = "mobile_money",
      networkOrBankCode = "",
      accountNumber = "",
      accountName = "",
      expectedAccountName = "",
      methodLabel = "",
      mode = "paystack_transfer",
      fallbackGhsRate = 15.5,
      customReference = "",
      notes = "",
    } = request.data || {};

    if (!bookingId || !accountNumber) {
      throw new HttpsError("invalid-argument", "Booking ID and driver payment address/account are required.");
    }

    const { db, FieldValue } = getAdmin();
    const bookingRef = db.collection("bookings").doc(bookingId.toString());
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const bookingData = bookingSnap.data() || {};
    if (isBookingCancelledStatus(bookingData.status)) {
      throw new HttpsError(
        "failed-precondition",
        "Cannot pay out a driver for a cancelled booking. Use Shipper Refund if eligible."
      );
    }

    const currentRefundStatus = (bookingData.refundStatus || "").toString().toLowerCase().trim();
    if (currentRefundStatus === "refunded") {
      throw new HttpsError(
        "failed-precondition",
        "This booking has already been refunded to the shipper."
      );
    }

    if (!isBookingCompletedStatus(bookingData.status)) {
      throw new HttpsError(
        "failed-precondition",
        "Driver payout can only be activated once the booking status is Delivered / Completed."
      );
    }

    const isPaidOnline =
      bookingData.paidOnline === true ||
      (bookingData.paymentStatus || "").toString().toLowerCase().trim() === "paid";
    if (!isPaidOnline) {
      throw new HttpsError(
        "failed-precondition",
        "Only bookings paid online via Paystack can be paid out from platform funds."
      );
    }

    const currentPayoutStatus = (bookingData.driverPayoutStatus || "").toString().toLowerCase().trim();
    if (currentPayoutStatus === "paid_out") {
      throw new HttpsError("already-exists", "This driver's portion has already been paid out.");
    }

    const driverId = (
      bookingData.driverId ||
      bookingData.assignedDriverId ||
      bookingData.companyId ||
      ""
    ).toString().trim();
    if (!driverId) {
      throw new HttpsError("failed-precondition", "No assigned driver found for this booking.");
    }

    const split = await resolveDriverPayoutSplit(bookingData, Number(fallbackGhsRate || 15.5));
    if (split.driverPayoutUsd <= 0 || split.driverPayoutGhs <= 0) {
      throw new HttpsError("failed-precondition", "Calculated driver portion must be greater than zero.");
    }

    const cleanType = payoutType.toString().toLowerCase().trim();
    const effectiveAccount = accountNumber.toString().trim();
    const effectiveMethodLabel =
      methodLabel.toString().trim() ||
      (cleanType === "mobile_money" ? "Mobile Money" : cleanType === "card" ? "Card" : "Bank / Wallet");
    const safeSlug = bookingId.toString().toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 14) || "trip";
    const reference =
      (customReference.toString().trim() || `drvpay_${safeSlug}_${Date.now()}`).slice(0, 50);

    // Manual payout mode (used for cards, external wallets, or offline transfers)
    if (mode === "manual") {
      await recordDriverPayoutInFirestore({
        bookingId: bookingId.toString(),
        bookingData,
        driverId,
        reference,
        usdAmount: split.driverPayoutUsd,
        ghsAmount: split.driverPayoutGhs,
        methodLabel: effectiveMethodLabel,
        accountLabel: effectiveAccount,
        adminUid,
        mode: "manual",
        notes: notes.toString(),
      });

      return {
        success: true,
        status: "paid_out",
        mode: "manual",
        reference,
        usdAmount: split.driverPayoutUsd,
        ghsAmount: split.driverPayoutGhs,
        platformFeeUsd: split.platformFeeUsd,
      };
    }

    // Paystack Automated Transfer Mode (supports Mobile Money & Bank accounts)
    if (cleanType !== "mobile_money" && cleanType !== "bank") {
      throw new HttpsError(
        "failed-precondition",
        `Paystack automated transfers only support Mobile Money or Bank accounts (not "${cleanType}"). Use "Confirm Manual Payout" for Card/Other addresses.`
      );
    }

    const secretKey = await getPaystackSecretKey();
    const bankCode = sanitizeGhanaBankCode(networkOrBankCode.toString(), effectiveMethodLabel);
    if (!bankCode) {
      throw new HttpsError("invalid-argument", "Bank or Mobile Money provider code is required.");
    }

    const isMoMo = cleanType === "mobile_money" || ["MTN", "VOD", "ATL"].includes(bankCode);
    const recipientType = isMoMo ? "mobile_money" : "ghipss";
    const formattedAccount = isMoMo ? formatLocalGhanaPhone(effectiveAccount) : effectiveAccount;

    // Strict Account Name Match Gate: verify Paystack resolved name equals driver's added account name
    const savedExpectedName = (expectedAccountName || accountName || "").toString().trim();
    if (!savedExpectedName) {
      throw new HttpsError(
        "failed-precondition",
        "Driver's saved Account Name is required on the payment address before sending a Paystack payout."
      );
    }

    let paystackResolvedName = "";
    try {
      const resolveData = await paystackGet(
        `/bank/resolve?account_number=${encodeURIComponent(formattedAccount)}&bank_code=${encodeURIComponent(bankCode)}`,
        secretKey
      );
      paystackResolvedName = (resolveData?.data?.account_name || "").toString().trim();
    } catch (resolveErr: any) {
      throw new HttpsError(
        "failed-precondition",
        `Could not verify recipient account name with Paystack: ${resolveErr?.responseData?.message || resolveErr?.message || "Resolution failed"}`
      );
    }

    if (!paystackResolvedName || !doAccountNamesMatch(savedExpectedName, paystackResolvedName)) {
      throw new HttpsError(
        "failed-precondition",
        `Account Name Mismatch! Driver saved "${savedExpectedName}" but Paystack resolved "${paystackResolvedName || "Unknown"}". Payout blocked.`
      );
    }

    const recipientName = paystackResolvedName;

    // 1. Create Paystack Transfer Recipient
    const recipientRes = await paystackPost("/transferrecipient", secretKey, {
      type: recipientType,
      name: recipientName,
      account_number: formattedAccount,
      bank_code: bankCode,
      currency: "GHS",
    });

    const recipientCode = recipientRes?.data?.recipient_code;
    if (!recipientCode) {
      throw new Error("Paystack did not return a transfer recipient code.");
    }

    // 2. Initiate Transfer ONLY for the Driver's Portion in GHS pesewas
    const displayId = (bookingData.bookingId || bookingId).toString();
    const transferRes = await paystackPost("/transfer", secretKey, {
      source: "balance",
      amount: Math.round(split.driverPayoutGhs * 100),
      recipient: recipientCode,
      reference,
      currency: "GHS",
      reason: `Driver trip payout (Manifest #${displayId})`,
    });

    const transferData = transferRes?.data || {};
    const transferStatus = (transferData.status || "").toString().toLowerCase().trim();
    const transferCode = (transferData.transfer_code || "").toString().trim();

    if (transferStatus === "otp") {
      await bookingRef.set(
        {
          driverPayoutStatus: "otp_pending",
          driverPayoutReference: reference,
          pendingDriverTransferCode: transferCode,
          driverPayoutRecipientCode: recipientCode,
          driverPayoutAmountUsd: split.driverPayoutUsd,
          driverPayoutAmountGhs: split.driverPayoutGhs,
          driverPayoutMethod: effectiveMethodLabel,
          driverPayoutAccount: formattedAccount,
          driverPayoutNotes: notes.toString(),
          driverPayoutPaidBy: adminUid,
          driverPayoutFailureReason: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        success: false,
        requiresOtp: true,
        status: "otp",
        transferCode,
        reference,
        usdAmount: split.driverPayoutUsd,
        ghsAmount: split.driverPayoutGhs,
        platformFeeUsd: split.platformFeeUsd,
        message: "Paystack requires OTP confirmation to finalize this transfer.",
      };
    }

    if (transferStatus === "success") {
      await recordDriverPayoutInFirestore({
        bookingId: bookingId.toString(),
        bookingData,
        driverId,
        reference,
        transferCode,
        usdAmount: split.driverPayoutUsd,
        ghsAmount: split.driverPayoutGhs,
        methodLabel: effectiveMethodLabel,
        accountLabel: formattedAccount,
        adminUid,
        mode: "paystack_transfer",
        notes: notes.toString(),
      });

      return {
        success: true,
        status: "paid_out",
        mode: "paystack_transfer",
        reference,
        transferCode,
        usdAmount: split.driverPayoutUsd,
        ghsAmount: split.driverPayoutGhs,
        platformFeeUsd: split.platformFeeUsd,
      };
    }

    // Paystack queued / pending async processing -> mark processing & let webhook or Sync finalize
    await bookingRef.set(
      {
        driverPayoutStatus: "processing",
        driverPayoutReference: reference,
        pendingDriverTransferCode: transferCode,
        driverPayoutRecipientCode: recipientCode,
        driverPayoutAmountUsd: split.driverPayoutUsd,
        driverPayoutAmountGhs: split.driverPayoutGhs,
        driverPayoutMethod: effectiveMethodLabel,
        driverPayoutAccount: formattedAccount,
        driverPayoutNotes: notes.toString(),
        driverPayoutPaidBy: adminUid,
        driverPayoutFailureReason: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await db.collection("Payments").doc(reference).set(
      {
        userId: driverId,
        driverId,
        bookingId: bookingId.toString(),
        reference,
        transferCode,
        amount: split.driverPayoutGhs,
        usdAmount: split.driverPayoutUsd,
        type: "driver_payout",
        paymentMethod: effectiveMethodLabel,
        phone: formattedAccount,
        network: effectiveMethodLabel,
        channel: "paystack_transfer",
        status: transferStatus || "pending",
        recordedBy: "Admin (Paystack Transfer)",
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      isPending: true,
      status: transferStatus || "pending",
      reference,
      transferCode,
      usdAmount: split.driverPayoutUsd,
      ghsAmount: split.driverPayoutGhs,
      platformFeeUsd: split.platformFeeUsd,
    };
  } catch (error: any) {
    logger.error("INITIATE DRIVER PAYOUT ERROR:", error.responseData || error.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      error.responseData?.message || error.message || "Failed to process driver payout."
    );
  }
});

// ================= FINALIZE DRIVER PAYOUT WITH TRANSFER OTP =================
export const finalizeDriverPayoutOtp = onCall(async (request) => {
  try {
    const adminUid = await assertAdminCaller(request.auth);
    const { bookingId, transferCode, otp } = request.data || {};
    if (!bookingId || !transferCode || !otp) {
      throw new HttpsError("invalid-argument", "Booking ID, transfer code, and OTP are required.");
    }

    const { db, FieldValue } = getAdmin();
    const bookingRef = db.collection("bookings").doc(bookingId.toString());
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const bookingData = bookingSnap.data() || {};
    const driverId = (
      bookingData.driverId ||
      bookingData.assignedDriverId ||
      bookingData.companyId ||
      ""
    ).toString().trim();

    const secretKey = await getPaystackSecretKey();
    const finalizeRes = await paystackPost("/transfer/finalize_transfer", secretKey, {
      transfer_code: transferCode.toString().trim(),
      otp: otp.toString().trim(),
    });

    const data = finalizeRes?.data || {};
    const status = (data.status || "").toString().toLowerCase().trim();
    const reference = (data.reference || bookingData.driverPayoutReference || transferCode).toString();
    const usdAmount = Number(bookingData.driverPayoutAmountUsd || 0);
    const ghsAmount = Number(bookingData.driverPayoutAmountGhs || 0);

    if (status === "success") {
      await recordDriverPayoutInFirestore({
        bookingId: bookingId.toString(),
        bookingData,
        driverId,
        reference,
        transferCode: transferCode.toString(),
        usdAmount,
        ghsAmount,
        methodLabel: (bookingData.driverPayoutMethod || "Paystack Transfer").toString(),
        accountLabel: (bookingData.driverPayoutAccount || "").toString(),
        adminUid,
        mode: "paystack_transfer",
        notes: (bookingData.driverPayoutNotes || "").toString(),
      });
      return { success: true, status: "paid_out", reference };
    }

    await bookingRef.set(
      {
        driverPayoutStatus: "processing",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { success: true, isPending: true, status: status || "pending", reference };
  } catch (error: any) {
    logger.error("FINALIZE DRIVER PAYOUT OTP ERROR:", error.responseData || error.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      error.responseData?.message || error.message || "Transfer OTP verification failed."
    );
  }
});

// ================= RESEND DRIVER PAYOUT TRANSFER OTP =================
export const resendDriverPayoutOtp = onCall(async (request) => {
  try {
    await assertAdminCaller(request.auth);
    const { transferCode } = request.data || {};
    if (!transferCode) {
      throw new HttpsError("invalid-argument", "Transfer code is required.");
    }
    const secretKey = await getPaystackSecretKey();
    await paystackPost("/transfer/resend_otp", secretKey, {
      transfer_code: transferCode.toString().trim(),
      reason: "transfer",
    });
    return { status: "sent" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.responseData?.message || error.message || "Failed to resend OTP.");
  }
});

// ================= VERIFY / SYNC DRIVER PAYOUT TRANSFER STATUS =================
export const verifyDriverPayoutTransfer = onCall(async (request) => {
  try {
    const adminUid = await assertAdminCaller(request.auth);
    const { bookingId, transferCode, reference } = request.data || {};
    if (!bookingId || (!transferCode && !reference)) {
      throw new HttpsError("invalid-argument", "Booking ID and transfer code or reference are required.");
    }

    const { db, FieldValue } = getAdmin();
    const bookingRef = db.collection("bookings").doc(bookingId.toString());
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const bookingData = bookingSnap.data() || {};
    const driverId = (
      bookingData.driverId ||
      bookingData.assignedDriverId ||
      bookingData.companyId ||
      ""
    ).toString().trim();

    const secretKey = await getPaystackSecretKey();
    const endpoint = transferCode
      ? `/transfer/${encodeURIComponent(transferCode.toString().trim())}`
      : `/transfer/verify/${encodeURIComponent(reference.toString().trim())}`;

    const resData = await paystackGet(endpoint, secretKey);
    const data = resData?.data || {};
    const status = (data.status || "").toString().toLowerCase().trim();
    const resolvedRef = (data.reference || reference || bookingData.driverPayoutReference || "").toString();
    const resolvedTransferCode = (data.transfer_code || transferCode || "").toString();

    if (status === "success") {
      await recordDriverPayoutInFirestore({
        bookingId: bookingId.toString(),
        bookingData,
        driverId,
        reference: resolvedRef,
        transferCode: resolvedTransferCode,
        usdAmount: Number(bookingData.driverPayoutAmountUsd || 0),
        ghsAmount: Number(bookingData.driverPayoutAmountGhs || 0),
        methodLabel: (bookingData.driverPayoutMethod || "Paystack Transfer").toString(),
        accountLabel: (bookingData.driverPayoutAccount || "").toString(),
        adminUid,
        mode: "paystack_transfer",
        notes: (bookingData.driverPayoutNotes || "").toString(),
      });
      return { success: true, status: "paid_out", reference: resolvedRef };
    }

    if (status === "failed" || status === "reversed" || status === "abandoned") {
      await bookingRef.set(
        {
          driverPayoutStatus: "payout_failed",
          pendingDriverTransferCode: FieldValue.delete(),
          driverPayoutFailureReason: data.gateway_response || data.reason || `Transfer ${status}`,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return {
        success: false,
        status,
        message: data.gateway_response || data.reason || `Transfer ${status}`,
      };
    }

    return {
      success: false,
      isPending: true,
      requiresOtp: status === "otp",
      status: status || "pending",
      transferCode: resolvedTransferCode,
      reference: resolvedRef,
    };
  } catch (error: any) {
    logger.error("VERIFY DRIVER PAYOUT ERROR:", error.responseData || error.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      error.responseData?.message || error.message || "Failed to verify payout transfer."
    );
  }
});

// ================= SHIPPER CANCELLATION & REFUND HELPERS & FUNCTIONS =================

async function recordShipperRefundInFirestore(params: {
  bookingId: string;
  bookingData: Record<string, any>;
  reference: string;
  refundId?: string;
  usdAmount: number;
  ghsAmount: number;
  mode: string;
  methodLabel: string;
  accountLabel: string;
  accountName: string;
  adminUid: string;
  notes?: string;
}) {
  const { db, messaging, FieldValue } = getAdmin();
  const {
    bookingId,
    bookingData,
    reference,
    refundId,
    usdAmount,
    ghsAmount,
    mode,
    methodLabel,
    accountLabel,
    accountName,
    adminUid,
    notes,
  } = params;

  const bookingRef = db.collection("bookings").doc(bookingId);
  const userId = (bookingData.userId || "").toString().trim();
  const nowMs = Date.now();

  await bookingRef.set(
    {
      refundStatus: "refunded",
      paymentStatus: "refunded",
      refundReference: reference,
      ...(refundId ? { refundId } : {}),
      pendingRefundTransferCode: FieldValue.delete(),
      refundFailureReason: FieldValue.delete(),
      refundAmountUsd: usdAmount,
      refundAmountGhs: ghsAmount,
      refundMode: mode,
      refundMethod: methodLabel,
      refundAccount: accountLabel,
      refundAccountName: accountName,
      refundNotes: notes || "",
      refundedBy: adminUid,
      refundedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Record in top-level Payments ledger
  await db.collection("Payments").doc(reference).set(
    {
      userId,
      bookingId,
      reference,
      ...(refundId ? { refundId } : {}),
      amount: ghsAmount,
      usdAmount,
      type: "shipper_refund",
      paymentMethod: methodLabel,
      phone: accountLabel,
      network: methodLabel,
      channel: mode,
      status: "success",
      recordedBy:
        mode === "paystack_refund"
          ? "Admin (Paystack Refund)"
          : mode === "paystack_transfer_refund"
              ? "Admin (Paystack Transfer Refund)"
              : "Admin (Manual Refund)",
      ...(notes ? { notes } : {}),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  if (userId) {
    const userRef = db.collection("Users").doc(userId);
    const txRef = userRef.collection("transactions").doc(`refund_${reference}`);
    const existingTx = await txRef.get();

    if (!existingTx.exists) {
      await txRef.set(
        {
          id: `refund_${reference}`,
          reference,
          bookingId: bookingData.bookingId || bookingId,
          bookingDocId: bookingId,
          type: "shipper_refund",
          amount: usdAmount,
          amountGhs: ghsAmount,
          network: methodLabel,
          phone: accountLabel,
          accountName,
          status: "success",
          timestamp: FieldValue.serverTimestamp(),
          createdAtMs: nowMs,
        },
        { merge: true }
      );

      // Push notify the shipper
      try {
        const userSnap = await userRef.get();
        const fcmToken = userSnap.data()?.fcmToken;
        if (fcmToken) {
          const displayId = bookingData.bookingId || bookingId;
          await messaging.send({
            token: fcmToken,
            notification: {
              title: "Refund Processed! 💸",
              body: `GH₵ ${ghsAmount.toFixed(2)} for cancelled Manifest #${displayId} has been refunded (${methodLabel}).`,
            },
            data: {
              type: "shipper_refund",
              bookingId,
              targetId: bookingId,
              reference,
            },
          });
        }
      } catch (notifyErr: any) {
        logger.warn(`Failed to notify shipper ${userId} of refund:`, notifyErr?.message);
      }
    }
  }
}

// ================= DRIVER NOTIFIES SHIPPER ON CANCELLATION OF PAID TRIP =================
export const notifyShipperOfDriverCancellation = onCall(async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }
    const { bookingId } = request.data || {};
    if (!bookingId) {
      throw new HttpsError("invalid-argument", "Booking ID is required.");
    }

    const { db, messaging, FieldValue } = getAdmin();
    const bookingRef = db.collection("bookings").doc(bookingId.toString());
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const bookingData = bookingSnap.data() || {};
    await bookingRef.set(
      {
        lastDriverCancelledBy: request.auth.uid,
        lastDriverCancelledAt: FieldValue.serverTimestamp(),
        driverCancellationCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const userId = (bookingData.userId || "").toString().trim();
    const isPaidOnline =
      bookingData.paidOnline === true ||
      (bookingData.paymentStatus || "").toString().toLowerCase().trim() === "paid";

    if (userId) {
      const userSnap = await db.collection("Users").doc(userId).get();
      const fcmToken = userSnap.data()?.fcmToken;
      if (fcmToken) {
        const displayId = (bookingData.bookingId || bookingId).toString();
        const ghsAmount = Number(bookingData.paidAmountGhs || 0);
        const body = isPaidOnline
          ? `The assigned driver cancelled Manifest #${displayId}. Your online payment${ghsAmount > 0 ? ` (GH₵ ${ghsAmount.toFixed(2)})` : ""} is protected — another driver can accept it, or you can cancel and request a full refund.`
          : `The assigned driver released Manifest #${displayId}. Your booking has been returned to the map for another nearby driver.`;

        await messaging.send({
          token: fcmToken,
          notification: {
            title: isPaidOnline ? "Driver Cancelled — Payment Protected 🛡️" : "Driver Released Booking",
            body,
          },
          data: {
            type: "driver_cancelled_booking",
            bookingId: bookingId.toString(),
            targetId: bookingId.toString(),
            paidOnline: isPaidOnline ? "true" : "false",
          },
        }).catch(() => {});
      }
    }

    return { ok: true };
  } catch (error: any) {
    logger.warn("NOTIFY DRIVER CANCELLATION ERROR:", error?.message);
    if (error instanceof HttpsError) throw error;
    return { ok: false, error: error?.message || "Notification error" };
  }
});

// ================= SHIPPER CANCEL & REQUEST REFUND =================
export const requestShipperBookingRefund = onCall(async (request) => {
  try {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const {
      bookingId,
      reason = "",
      refundMethodId = "",
      refundMethodType = "",
      refundNetworkOrBankCode = "",
      refundAccountNumber = "",
      refundAccountName = "",
      refundMethodLabel = "",
    } = request.data || {};

    if (!bookingId) {
      throw new HttpsError("invalid-argument", "Booking ID is required.");
    }

    const { db, FieldValue } = getAdmin();
    const bookingRef = db.collection("bookings").doc(bookingId.toString());
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const bookingData = bookingSnap.data() || {};
    if ((bookingData.userId || "").toString().trim() !== uid) {
      throw new HttpsError("permission-denied", "You can only cancel or request a refund for your own booking.");
    }

    const cleanStatus = (bookingData.status || "").toString().toLowerCase().trim().replace(/[^a-z]/g, "");
    if (
      cleanStatus === "pickedup" ||
      cleanStatus === "intransit" ||
      cleanStatus === "loaded" ||
      cleanStatus === "loadedontruck" ||
      cleanStatus === "arrived" ||
      isBookingCompletedStatus(bookingData.status)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Cargo has already been picked up or delivered. Please contact support/admin for dispute review."
      );
    }

    const isPaidOnline =
      bookingData.paidOnline === true ||
      (bookingData.paymentStatus || "").toString().toLowerCase().trim() === "paid";

    const currentRefundStatus = (bookingData.refundStatus || "").toString().toLowerCase().trim();
    if (currentRefundStatus === "refunded") {
      throw new HttpsError("already-exists", "This booking has already been refunded.");
    }

    const grossUsd = Number(bookingData.paidAmountUsd || bookingData.price || 0);
    const paidGhs = Number(bookingData.paidAmountGhs || 0);

    const updates: Record<string, any> = {
      status: "cancelled",
      cancelledBy: "shipper",
      cancelledAt: FieldValue.serverTimestamp(),
      ...(reason.toString().trim() ? { cancellationReason: reason.toString().trim() } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (isPaidOnline) {
      updates.refundStatus = "refund_requested";
      updates.refundRequestedAt = FieldValue.serverTimestamp();
      updates.refundAmountUsd = grossUsd;
      if (paidGhs > 0) updates.refundAmountGhs = paidGhs;
      if (refundMethodId) updates.refundPreferredMethodId = refundMethodId.toString().trim();
      if (refundMethodType) updates.refundPreferredType = refundMethodType.toString().trim();
      if (refundNetworkOrBankCode) updates.refundPreferredBankCode = refundNetworkOrBankCode.toString().trim();
      if (refundAccountNumber) updates.refundPreferredAccount = refundAccountNumber.toString().trim();
      if (refundAccountName) updates.refundPreferredAccountName = refundAccountName.toString().trim();
      if (refundMethodLabel) updates.refundPreferredLabel = refundMethodLabel.toString().trim();
    }

    await bookingRef.set(updates, { merge: true });

    return {
      success: true,
      isPaidOnline,
      refundStatus: isPaidOnline ? "refund_requested" : "none",
    };
  } catch (error: any) {
    logger.error("REQUEST SHIPPER REFUND ERROR:", error?.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error?.message || "Failed to cancel and request refund.");
  }
});

// ================= VERIFY ORIGINAL SHIPPER PAYSTACK TRANSACTION =================
export const verifyShipperTransaction = onCall(async (request) => {
  try {
    await assertAdminCaller(request.auth);
    const { reference } = request.data || {};
    if (!reference) {
      throw new HttpsError("invalid-argument", "Transaction reference is required.");
    }

    const secretKey = await getPaystackSecretKey();
    const resData = await paystackGet(`/transaction/verify/${encodeURIComponent(reference.toString().trim())}`, secretKey);
    const data = resData?.data || {};
    const auth = data.authorization || {};
    const cust = data.customer || {};

    return {
      status: data.status || "",
      reference: data.reference || reference,
      amountGhs: Number(data.amount || 0) / 100,
      currency: data.currency || "GHS",
      channel: data.channel || "",
      paidAt: data.paid_at || "",
      gatewayResponse: data.gateway_response || "",
      customerEmail: cust.email || "",
      customerName: `${cust.first_name || ""} ${cust.last_name || ""}`.trim(),
      accountName: auth.account_name || "",
      bank: auth.bank || "",
      mobileMoneyNumber: auth.mobile_money_number || "",
      last4: auth.last4 || "",
      brand: auth.brand || "",
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      error.responseData?.message || error.message || "Failed to verify Paystack transaction."
    );
  }
});

// ================= INITIATE SHIPPER REFUND =================
export const initiateShipperRefund = onCall(async (request) => {
  try {
    const adminUid = await assertAdminCaller(request.auth);
    const {
      bookingId,
      mode = "paystack_refund", // 'paystack_refund' | 'paystack_transfer_refund' | 'manual'
      payoutType = "mobile_money",
      networkOrBankCode = "",
      accountNumber = "",
      accountName = "",
      expectedAccountName = "",
      methodLabel = "",
      fallbackGhsRate = 15.5,
      customReference = "",
      notes = "",
    } = request.data || {};

    if (!bookingId) {
      throw new HttpsError("invalid-argument", "Booking ID is required.");
    }

    const { db, FieldValue } = getAdmin();
    const bookingRef = db.collection("bookings").doc(bookingId.toString());
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const bookingData = bookingSnap.data() || {};
    if (!isBookingCancelledStatus(bookingData.status)) {
      throw new HttpsError(
        "failed-precondition",
        "Shipper refunds can only be issued for cancelled bookings."
      );
    }

    const isPaidOnline =
      bookingData.paidOnline === true ||
      (bookingData.paymentStatus || "").toString().toLowerCase().trim() === "paid";
    if (!isPaidOnline) {
      throw new HttpsError(
        "failed-precondition",
        "This booking was not paid online. No Paystack refund is owed."
      );
    }

    const payoutStatus = (bookingData.driverPayoutStatus || "").toString().toLowerCase().trim();
    if (payoutStatus === "paid_out") {
      throw new HttpsError(
        "failed-precondition",
        "Driver has already been paid out for this booking. Review manually before issuing a refund."
      );
    }

    const currentRefundStatus = (bookingData.refundStatus || "").toString().toLowerCase().trim();
    if (currentRefundStatus === "refunded") {
      throw new HttpsError("already-exists", "This booking has already been refunded.");
    }

    const refundUsd = Number(bookingData.refundAmountUsd || bookingData.paidAmountUsd || bookingData.price || 0);
    const rate = Number(fallbackGhsRate || 15.5) > 1 ? Number(fallbackGhsRate) : 15.5;
    const refundGhs = Number(
      (Number(bookingData.refundAmountGhs || bookingData.paidAmountGhs || 0) > 0
        ? Number(bookingData.refundAmountGhs || bookingData.paidAmountGhs)
        : refundUsd * rate
      ).toFixed(2)
    );

    if (refundUsd <= 0 || refundGhs <= 0) {
      throw new HttpsError("failed-precondition", "Refund amount must be greater than zero.");
    }

    const safeSlug = bookingId.toString().toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 14) || "trip";
    const reference =
      (customReference.toString().trim() || `rfnd_${safeSlug}_${Date.now()}`).slice(0, 50);
    const displayId = (bookingData.bookingId || bookingId).toString();

    // 1. Manual Refund Confirmation
    if (mode === "manual") {
      await recordShipperRefundInFirestore({
        bookingId: bookingId.toString(),
        bookingData,
        reference,
        usdAmount: refundUsd,
        ghsAmount: refundGhs,
        mode: "manual",
        methodLabel: methodLabel.toString().trim() || "Manual Refund",
        accountLabel: accountNumber.toString().trim() || (bookingData.paymentReference || "").toString(),
        accountName: (expectedAccountName || accountName || bookingData.senderName || "").toString().trim(),
        adminUid,
        notes: notes.toString(),
      });

      return {
        success: true,
        status: "refunded",
        mode: "manual",
        reference,
        usdAmount: refundUsd,
        ghsAmount: refundGhs,
      };
    }

    const secretKey = await getPaystackSecretKey();

    // 2. Direct Paystack Transaction Refund (POST /refund)
    if (mode === "paystack_refund") {
      const txRef = (bookingData.paymentReference || "").toString().trim();
      if (!txRef) {
        throw new HttpsError(
          "failed-precondition",
          "Original Paystack payment reference is missing. Use Transfer Refund to Shipper's verified MoMo/Bank account instead."
        );
      }

      const refundRes = await paystackPost("/refund", secretKey, {
        transaction: txRef,
        amount: Math.round(refundGhs * 100),
        currency: "GHS",
        customer_note: `Refund for cancelled Manifest #${displayId}`,
        merchant_note: notes.toString().trim() || `Admin refund by ${adminUid} for ${displayId}`,
      });

      const rData = refundRes?.data || {};
      const rStatus = (rData.status || "").toString().toLowerCase().trim();
      const refundId = (rData.id || "").toString().trim();

      if (rStatus === "processed" || rStatus === "success") {
        await recordShipperRefundInFirestore({
          bookingId: bookingId.toString(),
          bookingData,
          reference,
          refundId,
          usdAmount: refundUsd,
          ghsAmount: refundGhs,
          mode: "paystack_refund",
          methodLabel: "Paystack Direct Refund",
          accountLabel: txRef,
          accountName: (bookingData.senderName || "").toString().trim(),
          adminUid,
          notes: notes.toString(),
        });

        return {
          success: true,
          status: "refunded",
          mode: "paystack_refund",
          reference,
          refundId,
          usdAmount: refundUsd,
          ghsAmount: refundGhs,
        };
      }

      await bookingRef.set(
        {
          refundStatus: "refund_processing",
          refundReference: reference,
          ...(refundId ? { refundId } : {}),
          refundMode: "paystack_refund",
          refundMethod: "Paystack Direct Refund",
          refundAccount: txRef,
          refundAmountUsd: refundUsd,
          refundAmountGhs: refundGhs,
          refundNotes: notes.toString(),
          refundedBy: adminUid,
          refundFailureReason: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        success: true,
        isPending: true,
        status: rStatus || "pending",
        mode: "paystack_refund",
        reference,
        refundId,
        usdAmount: refundUsd,
        ghsAmount: refundGhs,
      };
    }

    // 3. Paystack Transfer Refund to Shipper's Saved Account (strictly enforces Account Name Match!)
    const cleanType = payoutType.toString().toLowerCase().trim();
    if (cleanType !== "mobile_money" && cleanType !== "bank") {
      throw new HttpsError(
        "failed-precondition",
        `Paystack Transfer Refund supports Mobile Money or Bank accounts only (not "${cleanType}").`
      );
    }

    const effectiveAccount = accountNumber.toString().trim();
    const effectiveMethodLabel =
      methodLabel.toString().trim() || (cleanType === "mobile_money" ? "Mobile Money" : "Bank Account");
    const bankCode = sanitizeGhanaBankCode(networkOrBankCode.toString(), effectiveMethodLabel);
    if (!effectiveAccount || !bankCode) {
      throw new HttpsError("invalid-argument", "Shipper refund account number and provider code are required.");
    }

    const isMoMo = cleanType === "mobile_money" || ["MTN", "VOD", "ATL"].includes(bankCode);
    const recipientType = isMoMo ? "mobile_money" : "ghipss";
    const formattedAccount = isMoMo ? formatLocalGhanaPhone(effectiveAccount) : effectiveAccount;

    const savedExpectedName = (expectedAccountName || accountName || "").toString().trim();
    if (!savedExpectedName) {
      throw new HttpsError(
        "failed-precondition",
        "Shipper's saved Account Name is required before sending a Paystack refund transfer."
      );
    }

    let paystackResolvedName = "";
    try {
      const resolveData = await paystackGet(
        `/bank/resolve?account_number=${encodeURIComponent(formattedAccount)}&bank_code=${encodeURIComponent(bankCode)}`,
        secretKey
      );
      paystackResolvedName = (resolveData?.data?.account_name || "").toString().trim();
    } catch (resolveErr: any) {
      throw new HttpsError(
        "failed-precondition",
        `Could not verify shipper account name with Paystack: ${resolveErr?.responseData?.message || resolveErr?.message || "Resolution failed"}`
      );
    }

    if (!paystackResolvedName || !doAccountNamesMatch(savedExpectedName, paystackResolvedName)) {
      throw new HttpsError(
        "failed-precondition",
        `Account Name Mismatch! Shipper saved "${savedExpectedName}" but Paystack resolved "${paystackResolvedName || "Unknown"}". Refund blocked.`
      );
    }

    const recipientRes = await paystackPost("/transferrecipient", secretKey, {
      type: recipientType,
      name: paystackResolvedName,
      account_number: formattedAccount,
      bank_code: bankCode,
      currency: "GHS",
    });

    const recipientCode = recipientRes?.data?.recipient_code;
    if (!recipientCode) {
      throw new Error("Paystack did not return a transfer recipient code for refund.");
    }

    const transferRes = await paystackPost("/transfer", secretKey, {
      source: "balance",
      amount: Math.round(refundGhs * 100),
      recipient: recipientCode,
      reference,
      currency: "GHS",
      reason: `Shipper refund (Cancelled Manifest #${displayId})`,
    });

    const transferData = transferRes?.data || {};
    const transferStatus = (transferData.status || "").toString().toLowerCase().trim();
    const transferCode = (transferData.transfer_code || "").toString().trim();

    if (transferStatus === "otp") {
      await bookingRef.set(
        {
          refundStatus: "refund_otp_pending",
          refundReference: reference,
          pendingRefundTransferCode: transferCode,
          refundMode: "paystack_transfer_refund",
          refundMethod: effectiveMethodLabel,
          refundAccount: formattedAccount,
          refundAccountName: paystackResolvedName,
          refundAmountUsd: refundUsd,
          refundAmountGhs: refundGhs,
          refundNotes: notes.toString(),
          refundedBy: adminUid,
          refundFailureReason: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        success: false,
        requiresOtp: true,
        status: "otp",
        transferCode,
        reference,
        usdAmount: refundUsd,
        ghsAmount: refundGhs,
      };
    }

    if (transferStatus === "success") {
      await recordShipperRefundInFirestore({
        bookingId: bookingId.toString(),
        bookingData,
        reference,
        refundId: transferCode,
        usdAmount: refundUsd,
        ghsAmount: refundGhs,
        mode: "paystack_transfer_refund",
        methodLabel: effectiveMethodLabel,
        accountLabel: formattedAccount,
        accountName: paystackResolvedName,
        adminUid,
        notes: notes.toString(),
      });

      return {
        success: true,
        status: "refunded",
        mode: "paystack_transfer_refund",
        reference,
        transferCode,
        usdAmount: refundUsd,
        ghsAmount: refundGhs,
      };
    }

    await bookingRef.set(
      {
        refundStatus: "refund_processing",
        refundReference: reference,
        pendingRefundTransferCode: transferCode,
        refundMode: "paystack_transfer_refund",
        refundMethod: effectiveMethodLabel,
        refundAccount: formattedAccount,
        refundAccountName: paystackResolvedName,
        refundAmountUsd: refundUsd,
        refundAmountGhs: refundGhs,
        refundNotes: notes.toString(),
        refundedBy: adminUid,
        refundFailureReason: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      isPending: true,
      status: transferStatus || "pending",
      mode: "paystack_transfer_refund",
      reference,
      transferCode,
      usdAmount: refundUsd,
      ghsAmount: refundGhs,
    };
  } catch (error: any) {
    logger.error("INITIATE SHIPPER REFUND ERROR:", error.responseData || error.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      error.responseData?.message || error.message || "Failed to process shipper refund."
    );
  }
});

// ================= FINALIZE SHIPPER REFUND TRANSFER OTP =================
export const finalizeShipperRefundOtp = onCall(async (request) => {
  try {
    const adminUid = await assertAdminCaller(request.auth);
    const { bookingId, transferCode, otp } = request.data || {};
    if (!bookingId || !transferCode || !otp) {
      throw new HttpsError("invalid-argument", "Booking ID, transfer code, and OTP are required.");
    }

    const { db, FieldValue } = getAdmin();
    const bookingRef = db.collection("bookings").doc(bookingId.toString());
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const bookingData = bookingSnap.data() || {};
    const secretKey = await getPaystackSecretKey();
    const finalizeRes = await paystackPost("/transfer/finalize_transfer", secretKey, {
      transfer_code: transferCode.toString().trim(),
      otp: otp.toString().trim(),
    });

    const data = finalizeRes?.data || {};
    const status = (data.status || "").toString().toLowerCase().trim();
    const reference = (data.reference || bookingData.refundReference || transferCode).toString();
    const usdAmount = Number(bookingData.refundAmountUsd || bookingData.paidAmountUsd || bookingData.price || 0);
    const ghsAmount = Number(bookingData.refundAmountGhs || bookingData.paidAmountGhs || 0);

    if (status === "success") {
      await recordShipperRefundInFirestore({
        bookingId: bookingId.toString(),
        bookingData,
        reference,
        refundId: transferCode.toString(),
        usdAmount,
        ghsAmount,
        mode: "paystack_transfer_refund",
        methodLabel: (bookingData.refundMethod || "Paystack Transfer Refund").toString(),
        accountLabel: (bookingData.refundAccount || "").toString(),
        accountName: (bookingData.refundAccountName || "").toString(),
        adminUid,
        notes: (bookingData.refundNotes || "").toString(),
      });
      return { success: true, status: "refunded", reference };
    }

    await bookingRef.set(
      {
        refundStatus: "refund_processing",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { success: true, isPending: true, status: status || "pending", reference };
  } catch (error: any) {
    logger.error("FINALIZE SHIPPER REFUND OTP ERROR:", error.responseData || error.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      error.responseData?.message || error.message || "Refund OTP verification failed."
    );
  }
});

// ================= VERIFY / SYNC SHIPPER REFUND STATUS =================
export const verifyShipperRefundStatus = onCall(async (request) => {
  try {
    const adminUid = await assertAdminCaller(request.auth);
    const { bookingId } = request.data || {};
    if (!bookingId) {
      throw new HttpsError("invalid-argument", "Booking ID is required.");
    }

    const { db, FieldValue } = getAdmin();
    const bookingRef = db.collection("bookings").doc(bookingId.toString());
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const bookingData = bookingSnap.data() || {};
    const secretKey = await getPaystackSecretKey();
    const refundMode = (bookingData.refundMode || "").toString().toLowerCase().trim();
    const transferCode = (bookingData.pendingRefundTransferCode || "").toString().trim();
    const refundRef = (bookingData.refundReference || "").toString().trim();
    const refundId = (bookingData.refundId || "").toString().trim();

    if (refundMode === "paystack_transfer_refund" || transferCode) {
      if (!transferCode && !refundRef) {
        throw new HttpsError("failed-precondition", "No refund transfer reference found to sync.");
      }
      const endpoint = transferCode
        ? `/transfer/${encodeURIComponent(transferCode)}`
        : `/transfer/verify/${encodeURIComponent(refundRef)}`;
      const resData = await paystackGet(endpoint, secretKey);
      const data = resData?.data || {};
      const status = (data.status || "").toString().toLowerCase().trim();
      const resolvedRef = (data.reference || refundRef || transferCode).toString();
      const resolvedTransferCode = (data.transfer_code || transferCode).toString();

      if (status === "success") {
        await recordShipperRefundInFirestore({
          bookingId: bookingId.toString(),
          bookingData,
          reference: resolvedRef,
          refundId: resolvedTransferCode,
          usdAmount: Number(bookingData.refundAmountUsd || bookingData.paidAmountUsd || bookingData.price || 0),
          ghsAmount: Number(bookingData.refundAmountGhs || bookingData.paidAmountGhs || 0),
          mode: "paystack_transfer_refund",
          methodLabel: (bookingData.refundMethod || "Paystack Transfer Refund").toString(),
          accountLabel: (bookingData.refundAccount || "").toString(),
          accountName: (bookingData.refundAccountName || "").toString(),
          adminUid,
          notes: (bookingData.refundNotes || "").toString(),
        });
        return { success: true, status: "refunded", reference: resolvedRef };
      }

      if (status === "failed" || status === "reversed" || status === "abandoned") {
        await bookingRef.set(
          {
            refundStatus: "refund_failed",
            pendingRefundTransferCode: FieldValue.delete(),
            refundFailureReason: data.gateway_response || data.reason || `Refund transfer ${status}`,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        return { success: false, status, message: data.gateway_response || `Refund transfer ${status}` };
      }

      return {
        success: false,
        isPending: true,
        requiresOtp: status === "otp",
        status: status || "pending",
        transferCode: resolvedTransferCode,
        reference: resolvedRef,
      };
    }

    if (!refundId) {
      throw new HttpsError("failed-precondition", "No Paystack refund ID found to verify.");
    }

    const resData = await paystackGet(`/refund/${encodeURIComponent(refundId)}`, secretKey);
    const data = resData?.data || {};
    const status = (data.status || "").toString().toLowerCase().trim();

    if (status === "processed" || status === "success") {
      await recordShipperRefundInFirestore({
        bookingId: bookingId.toString(),
        bookingData,
        reference: refundRef || `rfnd_${refundId}`,
        refundId,
        usdAmount: Number(bookingData.refundAmountUsd || bookingData.paidAmountUsd || bookingData.price || 0),
        ghsAmount: Number(bookingData.refundAmountGhs || bookingData.paidAmountGhs || 0),
        mode: "paystack_refund",
        methodLabel: "Paystack Direct Refund",
        accountLabel: (bookingData.paymentReference || "").toString(),
        accountName: (bookingData.senderName || "").toString(),
        adminUid,
        notes: (bookingData.refundNotes || "").toString(),
      });
      return { success: true, status: "refunded", reference: refundRef };
    }

    if (status === "failed") {
      await bookingRef.set(
        {
          refundStatus: "refund_failed",
          refundFailureReason: data.gateway_response || "Paystack refund failed",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return { success: false, status: "failed", message: "Paystack refund failed" };
    }

    return { success: false, isPending: true, status: status || "pending", reference: refundRef };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      error.responseData?.message || error.message || "Failed to verify refund status."
    );
  }
});

/**
 * Utility to fetch DIDIT_WEBHOOK_SECRET from process.env or Firestore settings.
 */
async function getDiditWebhookSecret(): Promise<string> {
  const envSecret = process.env.DIDIT_WEBHOOK_SECRET;
  if (envSecret && envSecret.trim().length > 0) {
    return envSecret.trim();
  }

  try {
    const { db } = getAdmin();
    const doc1 = await db.doc(SETTINGS_DOC_PATH).get();
    if (doc1.exists && doc1.data()?.diditWebhookSecret) {
      return doc1.data().diditWebhookSecret.trim();
    }
    const doc2 = await db.doc("app_settings/didit_settings").get();
    if (doc2.exists && doc2.data()?.diditWebhookSecret) {
      return doc2.data().diditWebhookSecret.trim();
    }
  } catch (err) {
    logger.error("Error reading diditWebhookSecret from Firestore settings:", err);
  }

  return "";
}

/**
 * Constant-time comparison to prevent timing attacks on HMAC signatures.
 */
function safeCompareSignatures(a: string, b: string): boolean {
  if (!a || !b) return false;
  const bufA = Buffer.from(a.trim().toLowerCase(), "utf8");
  const bufB = Buffer.from(b.trim().toLowerCase(), "utf8");
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Helper to produce sorted, unicode-preserved canonical JSON representation
 * of an object for X-Signature-V2 HMAC validation.
 */
function canonicalizeJson(obj: any): string {
  if (obj === null || typeof obj !== "object") {
    return JSON.stringify(obj);
  }
  if (Array.isArray(obj)) {
    return "[" + obj.map(canonicalizeJson).join(",") + "]";
  }
  const sortedKeys = Object.keys(obj).sort();
  const pairs = sortedKeys.map(
    (key) => `${JSON.stringify(key)}:${canonicalizeJson(obj[key])}`
  );
  return "{" + pairs.join(",") + "}";
}

/**
 * Extracts warning and rejection details from Didit decision object V3.
 */
function extractDecisionWarnings(decision: any, body?: any): string {
  if (!decision && !body) return "Verification declined by Didit.";
  const warnings: string[] = [];

  const target = decision || body || {};

  if (Array.isArray(target.decline_reasons)) {
    warnings.push(...target.decline_reasons);
  }
  if (Array.isArray(body?.decline_reasons)) {
    warnings.push(...body.decline_reasons);
  }
  if (Array.isArray(target.warnings)) {
    warnings.push(...target.warnings);
  }
  if (target.decline_reason && typeof target.decline_reason === "string") {
    warnings.push(target.decline_reason);
  }
  if (target.rejection_reason && typeof target.rejection_reason === "string") {
    warnings.push(target.rejection_reason);
  }

  if (Array.isArray(target.reviews)) {
    target.reviews.forEach((r: any) => {
      if (r.comment) warnings.push(r.comment);
      if (r.reason) warnings.push(r.reason);
    });
  }

  const checkArrays = [
    "id_verifications",
    "liveness_checks",
    "face_matches",
    "aml_screenings",
    "poa_verifications",
    "database_validations",
    "business_verifications",
    "registry_checks",
  ];

  for (const key of checkArrays) {
    if (Array.isArray(target[key])) {
      target[key].forEach((item: any) => {
        if (item.warnings && Array.isArray(item.warnings)) {
          warnings.push(...item.warnings);
        }
        if (item.decline_reasons && Array.isArray(item.decline_reasons)) {
          warnings.push(...item.decline_reasons);
        }
        if (item.status && item.status !== "Approved" && item.status !== "PASSED") {
          warnings.push(`${key}: ${item.status}`);
        }
      });
    }
  }

  const unique = Array.from(new Set(warnings.filter((w) => Boolean(w && String(w).trim()))));
  return unique.length > 0 ? unique.join("; ") : "Verification declined.";
}

/**
 * POST /diditWebhook
 * Real-time Didit identity, business entity, and transaction event webhook handler.
 */
export const diditWebhook = onRequest({ cors: false, invoker: "public" }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  // 1. Read raw request body (Buffer and string)
  const rawBodyBuffer = req.rawBody || Buffer.from(JSON.stringify(req.body || {}));
  const rawBodyString = rawBodyBuffer.toString("utf8");

  let body: any;
  try {
    body = JSON.parse(rawBodyString);
  } catch (err) {
    logger.error("Failed to parse Didit webhook raw body as JSON:", rawBodyString);
    res.status(400).send("Invalid JSON body");
    return;
  }

  const secret = await getDiditWebhookSecret();

  // Header signatures
  const sigV2Header = (req.headers["x-signature-v2"] as string) || "";
  const sigV1Header = (req.headers["x-signature"] as string) || "";
  const sigSimpleHeader = (req.headers["x-signature-simple"] as string) || "";

  // 2. Verify HMAC-SHA256 signature if secret is present
  if (secret) {
    let isSignatureValid = false;

    // Option A: X-Signature-V2 (Canonical JSON) - Recommended
    if (sigV2Header) {
      const canonicalPayload = canonicalizeJson(body);
      const computedSigV2 = crypto
        .createHmac("sha256", secret)
        .update(canonicalPayload, "utf8")
        .digest("hex");
      isSignatureValid = safeCompareSignatures(computedSigV2, sigV2Header);
    }

    // Option B: X-Signature (Raw bytes)
    if (!isSignatureValid && sigV1Header) {
      const computedSigV1 = crypto
        .createHmac("sha256", secret)
        .update(rawBodyBuffer)
        .digest("hex");
      isSignatureValid = safeCompareSignatures(computedSigV1, sigV1Header);
    }

    // Option C: X-Signature-Simple (Fallback)
    if (!isSignatureValid && sigSimpleHeader) {
      const simpleString = `${body.timestamp}:${body.session_id}:${body.status}:${body.webhook_type}`;
      const computedSigSimple = crypto
        .createHmac("sha256", secret)
        .update(simpleString, "utf8")
        .digest("hex");
      isSignatureValid = safeCompareSignatures(computedSigSimple, sigSimpleHeader);
    }

    if (!isSignatureValid) {
      logger.error("Didit Webhook HMAC Signature verification failed.", {
        sigV2Header,
        sigV1Header,
        sigSimpleHeader,
        rawBodyString,
      });
      res.status(401).send("Invalid Signature");
      return;
    }
  } else {
    logger.warn("DIDIT_WEBHOOK_SECRET not set in Firestore settings. Proceeding with payload processing.");
  }

  // 3. Parse timestamp field if present
  let bodyTimestampSec: number | null = null;
  if (typeof body.timestamp === "number") {
    bodyTimestampSec = body.timestamp;
  } else if (typeof body.timestamp === "string") {
    bodyTimestampSec = Math.floor(new Date(body.timestamp).getTime() / 1000);
  } else if (typeof body.created_at === "number") {
    bodyTimestampSec = body.created_at;
  } else if (typeof body.created_at === "string") {
    bodyTimestampSec = Math.floor(new Date(body.created_at).getTime() / 1000);
  }

  if (bodyTimestampSec && !isNaN(bodyTimestampSec)) {
    const nowSec = Math.floor(Date.now() / 1000);
    if (Math.abs(nowSec - bodyTimestampSec) > 3600) {
      logger.warn(`Didit Webhook timestamp age warning (> 1h). Event timestamp: ${bodyTimestampSec}, Server timestamp: ${nowSec}`);
    }
  }

  // 4 & 5. Atomic deduplication & idempotent state update
  const { db, FieldValue } = getAdmin();
  const eventId = body.event_id || `${body.session_id}_${body.status}_${body.webhook_type}`;
  const eventRef = db.collection("DiditWebhookEvents").doc(eventId);

  const existingDoc = await eventRef.get();
  if (existingDoc.exists) {
    logger.info(`Didit Webhook event ${eventId} already processed. Returning 200 OK.`);
    res.status(200).json({ status: "ok", message: "Event already processed" });
    return;
  }

  // Atomically record event
  await eventRef.set({
    eventId,
    sessionId: body.session_id || "",
    businessSessionId: body.business_session_id || "",
    status: body.status || "",
    webhookType: body.webhook_type || "",
    vendorData: body.vendor_data || "",
    processedAt: FieldValue.serverTimestamp(),
  });

  // Log raw body and payload for auditing
  try {
    const extractedVendorData = body.vendor_data || body.vendorData || body.vendor_id || body.client_id || body.user_id || "";
    await db.collection("DiditWebhookLogs").add({
      eventId,
      sessionId: body.session_id || "",
      businessSessionId: body.business_session_id || "",
      webhookType: body.webhook_type || "",
      status: body.status || "",
      vendorData: extractedVendorData,
      rawBody: rawBodyString,
      payload: body,
      receivedAt: FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.error("Error creating DiditWebhookLogs entry:", err);
  }

  // Process status & database update across Users and Sellers collections
  try {
    let targetDocRef: any = null;
    const vendorData = body.vendor_data ||
      body.vendorData ||
      body.vendor_id ||
      body.client_id ||
      body.user_id ||
      body.session?.vendor_data ||
      body.decision?.vendor_data ||
      "";

    // A. Match by vendor_data (User UID / Driver UID)
    let cleanUid = "";
    let isKybTrack = false;
    let isKycTrack = false;

    if (vendorData) {
      if (vendorData.startsWith("kyb_")) {
        isKybTrack = true;
        const sub = vendorData.substring(4);
        cleanUid = sub.includes("_") ? sub.split("_")[0] : sub;
      } else if (vendorData.startsWith("kyc_")) {
        isKycTrack = true;
        const sub = vendorData.substring(4);
        cleanUid = sub.includes("_") ? sub.split("_")[0] : sub;
      } else if (vendorData.includes("_")) {
        cleanUid = vendorData.split("_")[0];
      } else {
        cleanUid = vendorData;
      }

      const userDoc = await db.collection("Users").doc(cleanUid).get();
      if (userDoc.exists) {
        targetDocRef = userDoc.ref;
      } else {
        const driverDoc = await db.collection("drivers").doc(cleanUid).get();
        if (driverDoc.exists) {
          targetDocRef = driverDoc.ref;
        } else {
          const sellerDoc = await db.collection("Sellers").doc(cleanUid).get();
          if (sellerDoc.exists) {
            targetDocRef = sellerDoc.ref;
          } else {
            const qUser = await db.collection("Users").where("id", "==", cleanUid).limit(1).get();
            if (!qUser.empty) {
              targetDocRef = qUser.docs[0].ref;
            } else {
              const qDriver = await db.collection("drivers").where("id", "==", cleanUid).limit(1).get();
              if (!qDriver.empty) {
                targetDocRef = qDriver.docs[0].ref;
              }
            }
          }
        }
      }
    }

    // B. Fallback: match by session_id in Users, drivers, & Sellers
    if (!targetDocRef && body.session_id) {
      const qUser = await db.collection("Users").where("diditSessionId", "==", body.session_id).limit(1).get();
      if (!qUser.empty) {
        targetDocRef = qUser.docs[0].ref;
      } else {
        const qDriver = await db.collection("drivers").where("diditSessionId", "==", body.session_id).limit(1).get();
        if (!qDriver.empty) {
          targetDocRef = qDriver.docs[0].ref;
        } else {
          const qSeller = await db.collection("Sellers").where("diditSessionId", "==", body.session_id).limit(1).get();
          if (!qSeller.empty) {
            targetDocRef = qSeller.docs[0].ref;
          }
        }
      }
    }

    // C. Fallback: match by business_session_id
    if (!targetDocRef && body.business_session_id) {
      const qUser = await db.collection("Users").where("diditBusinessSessionId", "==", body.business_session_id).limit(1).get();
      if (!qUser.empty) {
        targetDocRef = qUser.docs[0].ref;
      } else {
        const qDriver = await db.collection("drivers").where("diditBusinessSessionId", "==", body.business_session_id).limit(1).get();
        if (!qDriver.empty) {
          targetDocRef = qDriver.docs[0].ref;
        } else {
          const qSeller = await db.collection("Sellers").where("diditBusinessSessionId", "==", body.business_session_id).limit(1).get();
          if (!qSeller.empty) {
            targetDocRef = qSeller.docs[0].ref;
          }
        }
      }
    }

    // D. Fallback: match user whose diditStatus is 'In Progress' (active session)
    if (!targetDocRef) {
      const qUser = await db.collection("Users").where("diditStatus", "==", "In Progress").limit(1).get();
      if (!qUser.empty) {
        targetDocRef = qUser.docs[0].ref;
      } else {
        const qDriver = await db.collection("drivers").where("diditStatus", "==", "In Progress").limit(1).get();
        if (!qDriver.empty) {
          targetDocRef = qDriver.docs[0].ref;
        } else {
          const qSeller = await db.collection("Sellers").where("diditStatus", "==", "In Progress").limit(1).get();
          if (!qSeller.empty) {
            targetDocRef = qSeller.docs[0].ref;
          }
        }
      }
    }

    if (targetDocRef) {
      const rawStatus = (body.status || body.decision?.status || "").toString();
      const statusLower = rawStatus.toLowerCase();
      const isApproved = statusLower === "approved";
      const isDeclined = statusLower === "declined" || statusLower === "rejected" || statusLower === "failed";
      const statusStr = isApproved ? "Approved" : isDeclined ? "Declined" : (rawStatus || "Unknown");

      const updates: Record<string, any> = {
        diditStatus: statusStr,
        diditWebhookType: body.webhook_type || "",
        diditUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (body.session_id) updates.diditSessionId = body.session_id;
      if (body.business_session_id) updates.diditBusinessSessionId = body.business_session_id;
      if (body.session_kind) updates.diditSessionKind = body.session_kind;
      if (body.decision) updates.diditDecision = body.decision;

      const targetDocSnap = await targetDocRef.get();
      const currentData = targetDocSnap.exists ? targetDocSnap.data() : {};

      const isKybSession = Boolean(
        isKybTrack ||
        body.business_session_id ||
        body.session_kind === "business" ||
        (body.webhook_type && body.webhook_type.toLowerCase().includes("business")) ||
        currentData?.verificationType === "kyb" ||
        (currentData?.accountType === "business" && !isKycTrack)
      );

      const isCurrentBiz = (currentData?.accountType === "business" || currentData?.role === "business_shipper" || currentData?.role === "agent" || currentData?.role === "business_driver");
      const declineReason = extractDecisionWarnings(body.decision, body);

      // Track-specific dual-track updates (KYB vs KYC)
      if (isKybSession) {
        updates.kybStatus = statusStr;
        if (body.session_id || body.business_session_id) {
          updates.kybSessionId = body.business_session_id || body.session_id;
        }
        if (isApproved) {
          updates.kybVerified = true;
          if (currentData?.kybAdminApprovalStatus !== "approved") {
            updates.kybAdminApprovalStatus = "pending";
          }
        } else if (isDeclined) {
          updates.kybVerified = false;
          updates.kybAdminRejectionReason = declineReason;
        }
      } else {
        updates.kycStatus = statusStr;
        if (body.session_id) {
          updates.kycSessionId = body.session_id;
        }
        if (isApproved) {
          updates.kycVerified = true;
          if (currentData?.kycAdminApprovalStatus !== "approved") {
            updates.kycAdminApprovalStatus = "pending";
          }
        } else if (isDeclined) {
          updates.kycVerified = false;
          updates.kycAdminRejectionReason = declineReason;
        }
      }

      // Sync top-level fields if the webhook session corresponds to the user's active profile
      const shouldUpdateTopLevel = (isKybSession && isCurrentBiz) || (!isKybSession && !isCurrentBiz);

      if (shouldUpdateTopLevel) {
        if (isApproved) {
          updates.verificationStatus = "approved";
          updates.verification_status = "approved";
          updates.diditVerified = true;
          updates.isVerified = true;
          updates.verifiedAt = new Date().toISOString();
          // Admin review policy: even after Didit automated KYC/KYB approval,
          // freight operations admin must manually review and approve before activation.
          if (currentData?.adminApprovalStatus !== "approved") {
            updates.adminApprovalStatus = "pending";
            updates.adminApproved = false;
          }
        } else if (isDeclined) {
          updates.verificationStatus = "declined";
          updates.verification_status = "declined";
          updates.diditVerified = false;
          updates.isVerified = false;
          updates.rejectionReason = declineReason;
        } else if (statusLower === "in review" || statusLower === "pending_review") {
          updates.verificationStatus = "pending";
          updates.verification_status = "pending_review";
        } else if (statusLower === "in progress" || statusLower === "in_progress") {
          updates.verificationStatus = "pending";
          updates.verification_status = "in_progress";
        } else if (statusLower === "resubmitted") {
          updates.verificationStatus = "resubmitted";
          updates.verification_status = "resubmitted";
        } else if (statusLower === "abandoned") {
          updates.verificationStatus = "abandoned";
          updates.verification_status = "abandoned";
        } else if (statusLower.includes("expired")) {
          updates.verificationStatus = "expired";
          updates.verification_status = "expired";
        } else {
          updates.verificationStatus = statusLower;
          updates.verification_status = statusLower;
        }
      }

      // Extract KYB business details if present in decision or webhook body
      if (body.decision?.registry_checks?.[0]?.company) {
        const comp = body.decision.registry_checks[0].company;
        if (comp.company_name) updates.companyName = comp.company_name;
        if (comp.registration_number) updates.businessRegistrationNumber = comp.registration_number;
        if (comp.tax_number) updates.taxNumber = comp.tax_number;
        if (comp.registered_address) updates.businessAddress = comp.registered_address;
      } else if (body.company_name) {
        updates.companyName = body.company_name;
        if (body.registration_number) updates.businessRegistrationNumber = body.registration_number;
      }

      await targetDocRef.update(updates);
      logger.info(`Successfully updated document ${targetDocRef.path} with Didit status: ${statusStr}`);

      // Ensure both Users and drivers collections stay synchronized for driver accounts
      const docId = cleanUid || targetDocRef.id;
      if (docId) {
        const collectionsToSync = ["Users", "drivers"];
        for (const col of collectionsToSync) {
          if (targetDocRef.path.startsWith(col)) continue;
          try {
            const syncDocRef = db.collection(col).doc(docId);
            const syncSnap = await syncDocRef.get();
            if (syncSnap.exists) {
              await syncDocRef.set(updates, { merge: true });
              logger.info(`Synchronized ${col}/${docId} with Didit status: ${statusStr}`);
            }
          } catch (syncErr) {
            logger.warn(`Could not sync ${col}/${docId}:`, syncErr);
          }
        }
      }
    } else {
      logger.warn(`No target Seller/User/Driver found for vendor_data=${body.vendor_data}, session_id=${body.session_id}`);
    }
  } catch (err) {
    logger.error("Error updating document from Didit webhook:", err);
  }

  // Fast 2xx response
  res.status(200).json({ status: "ok", event_id: eventId });
});
