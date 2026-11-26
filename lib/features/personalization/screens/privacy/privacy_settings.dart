import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../data/repositories/support/support_config_repository.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../controllers/user_controller.dart';
import '../legal/privacy_policy.dart';
import '../legal/terms_of_service.dart';
import '../verification/didit_verification_screen.dart';
import '../../../../routes/routes.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _checkDevicePermissions();
  }

  Future<void> _checkDevicePermissions() async {
    setState(() => _isLoadingPermissions = true);
    final loc = await Permission.location.status;
    final cam = await Permission.camera.status;
    final notif = await Permission.notification.status;

    if (mounted) {
      setState(() {
        _locationStatus = loc;
        _cameraStatus = cam;
        _notificationStatus = notif;
        _isLoadingPermissions = false;
      });
    }
  }

  Future<void> _requestOrOpenSettings(Permission permission) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    await _checkDevicePermissions();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final user = FirebaseAuth.instance.currentUser;
    final userController = UserController.instance;

    final bgColor = dark ? AvailColors.dark : const Color(0xFFF8FAFC);
    final cardColor = dark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = dark ? Colors.grey.shade400 : Colors.grey.shade700;
    final isWide = SiteLayout.isWideScreen(context);

    return AppPageLayout(
      title: 'Account Privacy & Security',
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: isWide
            ? null
            : const AvailAppbar(
                title: Text(
                  'Account Privacy & Security',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.white),
                ),
                showBackArrow: true,
                showBackgroundColor: true,
                backArrowColor: Colors.white,
              ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: ResponsiveCenter(
          maxWidth: 920,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 1. Hero Security & Shield Banner
            _buildHeroBanner(dark),
            const SizedBox(height: 20),

            // 2. Authentication & Account Identity
            _buildSectionHeader('Authentication & Identity', Iconsax.security_user, dark),
            _buildCard(
              cardColor: cardColor,
              borderColor: borderColor,
              children: [
                _buildConnectedAccountTile(context, user, dark, titleColor, bodyColor),
                Divider(height: 1, color: borderColor),
                _buildPasswordResetTile(user, dark, titleColor, bodyColor),
                Divider(height: 1, color: borderColor),
                _buildVerificationStatusTile(userController, dark, titleColor, bodyColor),
              ],
            ),
            const SizedBox(height: 22),

            // 3. Operational Permissions Center
            _buildSectionHeader('Operational Permissions', Iconsax.key, dark),
            _buildCard(
              cardColor: cardColor,
              borderColor: borderColor,
              children: [
                _buildPermissionTile(
                  icon: Iconsax.location,
                  iconColor: Colors.blue,
                  title: 'Location & Telematics',
                  subtitle: 'Required for accurate pickup/dropoff pinning and live driver route tracking',
                  status: _locationStatus,
                  onTap: () => _requestOrOpenSettings(Permission.location),
                  dark: dark,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                ),
                Divider(height: 1, color: borderColor),
                _buildPermissionTile(
                  icon: Iconsax.camera,
                  iconColor: Colors.amber.shade800,
                  title: 'Camera & Document Capture',
                  subtitle: 'Used for Didit KYC/KYB biometric scans and waybill/cargo invoice uploads',
                  status: _cameraStatus,
                  onTap: () => _requestOrOpenSettings(Permission.camera),
                  dark: dark,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                ),
                Divider(height: 1, color: borderColor),
                _buildPermissionTile(
                  icon: Iconsax.notification,
                  iconColor: Colors.purple,
                  title: 'Push Notifications',
                  subtitle: 'Real-time dispatch alerts, driver arrivals, and payment confirmations',
                  status: _notificationStatus,
                  onTap: () => _requestOrOpenSettings(Permission.notification),
                  dark: dark,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // 4. Data Protection & Cryptographic Safeguards
            _buildSectionHeader('Platform Security Safeguards', Iconsax.shield_tick, dark),
            _buildCard(
              cardColor: cardColor,
              borderColor: borderColor,
              children: [
                _buildSecurityFeatureTile(
                  icon: Iconsax.lock,
                  iconColor: Colors.teal,
                  title: 'End-to-End Encryption in Transit',
                  subtitle: 'All manifest documents, telematics, and account records use TLS 1.3 / AES-256 cloud encryption.',
                  dark: dark,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                ),
                Divider(height: 1, color: borderColor),
                _buildSecurityFeatureTile(
                  icon: Iconsax.card_pos,
                  iconColor: Colors.indigo,
                  title: 'PCI-DSS Compliant Payments',
                  subtitle: 'Payment tokens & Mobile Money are processed via Paystack. Haujzo never stores raw card credentials.',
                  dark: dark,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                ),
                Divider(height: 1, color: borderColor),
                _buildSecurityFeatureTile(
                  icon: Iconsax.eye_slash,
                  iconColor: Colors.green,
                  title: 'Zero Data Brokerage Guarantee',
                  subtitle: 'Haujzo never sells, rents, or monetizes shipper data or freight manifest records to external brokers.',
                  dark: dark,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // 5. Shipper Data Rights & Policy Shortcuts
            _buildSectionHeader('Your Privacy Rights & Disclosures', Iconsax.document_text, dark),
            _buildCard(
              cardColor: cardColor,
              borderColor: borderColor,
              children: [
                _buildNavigationTile(
                  icon: Iconsax.document_download,
                  iconColor: Colors.blueAccent,
                  title: 'Download Account & Manifest Summary',
                  subtitle: 'Copy your official shipper profile details and identifier to clipboard',
                  trailing: const Icon(Iconsax.copy, size: 18, color: AvailColors.primary),
                  onTap: () => _copyAccountSummary(user, userController),
                  dark: dark,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                ),
                Divider(height: 1, color: borderColor),
                _buildNavigationTile(
                  icon: Iconsax.shield_security,
                  iconColor: Colors.orange,
                  title: 'Read Haujzo Privacy Policy',
                  subtitle: 'Comprehensive Google Maps location, Didit KYC, and telemetry disclosures',
                  trailing: const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
                  onTap: () => Get.toNamed(AvailRoutes.privacyPolicy),
                  dark: dark,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                ),
                Divider(height: 1, color: borderColor),
                _buildNavigationTile(
                  icon: Iconsax.receipt_2_1,
                  iconColor: Colors.deepPurple,
                  title: 'Terms of Service & Agreements',
                  subtitle: 'Shipper obligations, refunds, demurrage & anti-fraud rules',
                  trailing: const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
                  onTap: () => Get.toNamed(AvailRoutes.termsOfService),
                  dark: dark,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // 6. Account Danger Zone
            _buildSectionHeader('Account Actions', Iconsax.profile_delete, dark),
            _buildCard(
              cardColor: cardColor,
              borderColor: borderColor,
              children: [
                ListTile(
                  onTap: () => userController.deleteAccountWarningPop(),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Iconsax.trash, color: Colors.red, size: 20),
                  ),
                  title: const Text(
                    'Delete Account & Purge Data',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.red),
                  ),
                  subtitle: Text(
                    'Permanently delete your profile and purge non-statutory records within 30 days',
                    style: TextStyle(fontSize: 11.5, color: bodyColor),
                  ),
                  trailing: const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Footer note
            Center(
              child: Column(
                children: [
                  Text(
                    'Haujzo Shipper Privacy & Data Governance',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: bodyColor),
                  ),
                  const SizedBox(height: 4),
                  Obx(() {
                    final cfg = SupportConfigRepository.instance.supportConfig.value;
                    return Text(
                      'Support: ${cfg.supportEmail} • ${cfg.supportPhone}',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          ),
        ),
      ),
    ),
  );
}

  // ================= UI HELPER WIDGETS =================

  Widget _buildHeroBanner(bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AvailColors.navyGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AvailColors.secondary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AvailColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Iconsax.shield_tick, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haujzo Privacy Guard',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Enterprise Freight Data & Security Governance',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Your business identity, cargo manifests, route coordinates, and financial records are protected by industry-grade encryption, authenticated Didit KYC/KYB, and strict operational access controls.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool dark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required Color cardColor,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildConnectedAccountTile(
    BuildContext context,
    User? user,
    bool dark,
    Color titleColor,
    Color bodyColor,
  ) {
    String provider = 'Email & Password';
    IconData providerIcon = Iconsax.sms;
    Color iconColor = Colors.blue;

    if (user != null && user.providerData.isNotEmpty) {
      final pid = user.providerData.first.providerId;
      if (pid == 'google.com') {
        provider = 'Google Authenticated';
        providerIcon = Icons.g_mobiledata;
        iconColor = Colors.redAccent;
      } else if (pid == 'phone') {
        provider = 'Phone (SMS OTP)';
        providerIcon = Iconsax.call;
        iconColor = Colors.green;
      }
    }

    final email = user?.email ?? 'No email linked';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(providerIcon, color: iconColor, size: 20),
      ),
      title: Text('Connected Sign-In Provider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor)),
      subtitle: Text('$provider • $email', style: TextStyle(fontSize: 11.5, color: bodyColor)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Active',
          style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: () {
        Get.defaultDialog(
          title: 'Connected Sign-In Identity',
          middleText:
              'You are securely authenticated using $provider.\n\nAccount Email: $email\nUser UID: ${user?.uid ?? 'N/A'}\n\nThis provider is used to protect your freight bookings, wallet authorizations, and profile access.',
          textConfirm: 'Done',
          confirmTextColor: Colors.white,
          buttonColor: AvailColors.primary,
          onConfirm: () => Get.back(),
        );
      },
    );
  }

  Widget _buildPasswordResetTile(
    User? user,
    bool dark,
    Color titleColor,
    Color bodyColor,
  ) {
    final email = user?.email ?? '';
    final hasPasswordProvider = user?.providerData.any((p) => p.providerId == 'password') ?? false;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.deepOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Iconsax.key, color: Colors.deepOrange, size: 20),
      ),
      title: Text('Password & Access Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor)),
      subtitle: Text(
        hasPasswordProvider ? 'Send a secure password reset link to your email' : 'Managed via Google sign-in credentials',
        style: TextStyle(fontSize: 11.5, color: bodyColor),
      ),
      trailing: const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
      onTap: () {
        if (!hasPasswordProvider) {
          AvailLoaders.customToast(message: 'Your account is managed via Google Sign-In.');
          return;
        }

        Get.defaultDialog(
          title: 'Reset Password',
          middleText: 'Send a secure password reset link to:\n$email',
          textCancel: 'Cancel',
          textConfirm: 'Send Link',
          confirmTextColor: Colors.white,
          buttonColor: AvailColors.primary,
          onConfirm: () async {
            Get.back();
            try {
              await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
              AvailLoaders.successSnackBar(
                title: 'Reset Email Sent',
                message: 'Check your email ($email) to update your password.',
              );
            } catch (e) {
              AvailLoaders.errorSnackBar(title: 'Failed', message: e.toString());
            }
          },
        );
      },
    );
  }

  Widget _buildVerificationStatusTile(
    UserController userController,
    bool dark,
    Color titleColor,
    Color bodyColor,
  ) {
    return Obx(() {
      final user = userController.user.value;
      final isVerified = user.isVerified;
      final isApproved = user.isApprovedByAdmin;
      final isBusiness = user.isBusiness;

      String badgeText;
      Color badgeColor;
      IconData badgeIcon;

      if (isVerified && isApproved) {
        badgeText = 'Verified & Approved';
        badgeColor = Colors.green;
        badgeIcon = Iconsax.verify;
      } else if (isVerified && !isApproved) {
        badgeText = 'Under Review';
        badgeColor = Colors.orange;
        badgeIcon = Iconsax.clock;
      } else {
        badgeText = 'Action Required';
        badgeColor = Colors.redAccent;
        badgeIcon = Iconsax.info_circle;
      }

      return ListTile(
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(badgeIcon, color: badgeColor, size: 20),
        ),
        title: Text(
          isBusiness ? 'Corporate KYB Standing' : 'Shipper KYC Identity Standing',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor),
        ),
        subtitle: Text(
          'Cryptographic Didit Protocol verification • $badgeText',
          style: TextStyle(fontSize: 11.5, color: bodyColor),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeText,
            style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () => Get.toNamed(AvailRoutes.diditVerification),
      );
    });
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required PermissionStatus status,
    required VoidCallback onTap,
    required bool dark,
    required Color titleColor,
    required Color bodyColor,
  }) {
    final bool isGranted = status.isGranted || status.isLimited;
    final badgeColor = isGranted ? Colors.green : Colors.orange;
    final badgeLabel = _isLoadingPermissions
        ? 'Checking...'
        : (isGranted ? 'Granted' : (status.isPermanentlyDenied ? 'Blocked' : 'Action'));

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11.5, color: bodyColor)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          badgeLabel,
          style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSecurityFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool dark,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11.5, color: bodyColor, height: 1.35)),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    required bool dark,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11.5, color: bodyColor)),
      trailing: trailing,
    );
  }

  void _copyAccountSummary(User? user, UserController userController) {
    final u = userController.user.value;
    final summary = '''
HAUJZO SHIPPER ACCOUNT SUMMARY
=============================
Shipper Name: ${u.fullName}
Account Type: ${u.isBusiness ? 'Corporate Business Shipper' : 'Individual Shipper'}
Company Name: ${u.companyName.isNotEmpty ? u.companyName : 'N/A'}
User UID: ${user?.uid ?? u.id}
Email Address: ${user?.email ?? u.email}
Phone Number: ${u.phoneNumber}
Verification Status: ${u.isVerified ? 'KYC/KYB Verified' : 'Unverified'}
Admin Standing: ${u.isApprovedByAdmin ? 'Approved' : 'Pending Operations Review'}
Generated: ${DateTime.now().toIso8601String()}
Platform: Haujzo Freight Logistics
''';

    Clipboard.setData(ClipboardData(text: summary));
    AvailLoaders.successSnackBar(
      title: 'Summary Copied',
      message: 'Shipper account summary copied to your clipboard.',
    );
  }
}
