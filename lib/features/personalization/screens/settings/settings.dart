import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/custom_shapes/containers/primary_header_container.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../commons/widgets/list_tiles/profile_menu_tile.dart';
import '../../../../commons/widgets/list_tiles/user_profile_tile.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../../../utils/notifications/push_notification_service.dart';
import '../../controllers/user_controller.dart';
import '../legal/about_us.dart';
import '../legal/help_support.dart';
import '../legal/privacy_policy.dart';
import '../legal/terms_of_service.dart';
import '../privacy/privacy_settings.dart';
import '../profile/profile.dart';
import '../verification/didit_verification_screen.dart';
import 'package:truck_booking/navigation_menu.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pushService = PushNotificationService.instance;
    final isGuest = FirebaseAuth.instance.currentUser == null;
    final dark = AvailHelperFunctions.isDarkMode(context);
    final isWide = SiteLayout.isWideScreen(context);
    final isEmbedded = isWide && !Navigator.canPop(context);

    final userController = UserController.instance;
    final isDriver = userController.user.value.role == 'driver';

    void openVerification() {
      if (isGuest) {
        Get.toNamed(AvailRoutes.signIn);
      } else if (Get.isRegistered<NavigationController>()) {
        NavigationController.instance.openSubScreen(
          const DiditVerificationScreen(),
          title: 'Identity Verification',
        );
      } else {
        Get.toNamed(AvailRoutes.diditVerification);
      }
    }

    void openProfileDetails() {
      if (isGuest) {
        Get.toNamed(AvailRoutes.signIn);
      } else if (Get.isRegistered<NavigationController>()) {
        NavigationController.instance.openSubScreen(
          const ProfileScreen(),
          title: 'My Profile',
        );
      } else {
        Get.toNamed(AvailRoutes.userProfile);
      }
    }

    void openPrivacySecurity() {
      if (isGuest) {
        Get.toNamed(AvailRoutes.signIn);
      } else if (Get.isRegistered<NavigationController>()) {
        NavigationController.instance.openSubScreen(
          const PrivacySettingsScreen(),
          title: 'Privacy & Security',
        );
      } else {
        Get.toNamed(AvailRoutes.privacySettings);
      }
    }

    final accountSettingsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          dark: dark,
          icon: Iconsax.setting_2,
          title: 'Account & Logistics Controls',
          subtitle: 'Manage dispatches, fleet specs, wallets & identity',
          accent: AvailColors.primary,
        ),
        const SizedBox(height: 10),
        if (!isDriver) ...[
          AvailProfileMenuTile(
            icon: Iconsax.safe_home,
            iconColor: const Color(0xFF0284C7),
            title: 'My Addresses & Hubs',
            subtitle: 'Set default pickup depots and delivery warehouses',
            onTap: () {
              if (isGuest) {
                Get.toNamed(AvailRoutes.signIn);
              } else if (Get.isRegistered<NavigationController>()) {
                NavigationController.instance.selectedIndex.value = 4;
              } else {
                Get.toNamed(AvailRoutes.userAddress);
              }
            },
          ),
          _buildSoftDivider(dark),
          AvailProfileMenuTile(
            icon: Iconsax.bag_tick,
            iconColor: AvailColors.primary,
            badgeText: 'LIVE',
            badgeColor: AvailColors.primary,
            title: 'My Freight Manifests',
            subtitle: 'Track in-transit cargo jobs, waybills & delivery history',
            onTap: () {
              if (isGuest) {
                Get.toNamed(AvailRoutes.signIn);
              } else if (Get.isRegistered<NavigationController>()) {
                NavigationController.instance.selectedIndex.value = 1;
              } else {
                Get.toNamed(AvailRoutes.myBookings);
              }
            },
          ),
          _buildSoftDivider(dark),
        ],
        AvailProfileMenuTile(
          icon: Iconsax.truck_fast,
          iconColor: const Color(0xFF4F46E5),
          title: 'Truck Details & Fleet Specs',
          subtitle: 'Payload capacities, cargo compatibility & deck dimensions',
          onTap: () {
            if (Get.isRegistered<NavigationController>()) {
              NavigationController.instance.selectedIndex.value = 2;
            } else {
              Get.toNamed(AvailRoutes.truckDetails);
            }
          },
        ),
        _buildSoftDivider(dark),
        AvailProfileMenuTile(
          icon: Iconsax.wallet_3,
          iconColor: const Color(0xFF10B981),
          title: 'Payment Methods & Wallets',
          subtitle: 'Manage Mobile Money accounts & digital payment methods',
          onTap: () {
            if (isGuest) {
              Get.toNamed(AvailRoutes.signIn);
            } else if (Get.isRegistered<NavigationController>()) {
              NavigationController.instance.selectedIndex.value = 3;
            } else {
              Get.toNamed(AvailRoutes.userPaymentMethods);
            }
          },
        ),
        _buildSoftDivider(dark),
        AvailProfileMenuTile(
          icon: Iconsax.notification,
          iconColor: const Color(0xFFF59E0B),
          title: 'Notifications & Alerts',
          subtitle: 'Real-time dispatch updates, driver arrivals & POD alerts',
          onTap: () {
            if (isGuest) {
              Get.toNamed(AvailRoutes.signIn);
            } else if (Get.isRegistered<NavigationController>()) {
              NavigationController.instance.selectedIndex.value = 5;
            } else {
              Get.toNamed(AvailRoutes.notifications);
            }
          },
          trailing: Obx(
            () => Transform.scale(
              scale: 0.85,
              child: Switch(
                value: pushService.isPermissionGranted.value,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AvailColors.primary;
                  }
                  return null;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AvailColors.primary.withValues(alpha: 0.35);
                  }
                  return null;
                }),
                onChanged: (value) async {
                  if (isGuest) {
                    Get.toNamed(AvailRoutes.signIn);
                    return;
                  }
                  if (value) {
                    await pushService.requestPermission();
                  } else {
                    Get.snackbar(
                      'Notice',
                      'To disable notifications, please go to App Settings.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                    await pushService.checkPermissionStatus();
                  }
                },
              ),
            ),
          ),
        ),
        _buildSoftDivider(dark),
        AvailProfileMenuTile(
          icon: Iconsax.security_card,
          iconColor: const Color(0xFF8B5CF6),
          title: 'Account Privacy & Security',
          subtitle: 'Authentication, device permissions & data rights',
          onTap: openPrivacySecurity,
        ),
        _buildSoftDivider(dark),
        Obx(() {
          final user = userController.user.value;
          final isVerified = !isGuest && user.canWork;
          final isUnderReview = !isGuest && user.isUnderAdminReview;
          return AvailProfileMenuTile(
            icon: Iconsax.verify,
            iconColor: isVerified
                ? const Color(0xFF10B981)
                : (isUnderReview
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF0EA5E9)),
            badgeText: isGuest
                ? null
                : (isVerified
                    ? 'APPROVED'
                    : (isUnderReview ? 'IN REVIEW' : 'REQUIRED')),
            badgeColor: isVerified
                ? const Color(0xFF10B981)
                : (isUnderReview
                    ? const Color(0xFFF59E0B)
                    : AvailColors.primary),
            title: 'Identity & Business Verification',
            subtitle: 'DIDIT KYC/KYB cryptographic identity verification',
            onTap: openVerification,
          );
        }),
      ],
    );

    final supportLegalColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          dark: dark,
          icon: Iconsax.shield_tick,
          title: 'Support, Governance & Legal',
          subtitle: '24/7 dispatch assistance, compliance & policies',
          accent: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 10),
        AvailProfileMenuTile(
          icon: Iconsax.support,
          iconColor: AvailColors.primary,
          badgeText: '24/7',
          badgeColor: const Color(0xFF10B981),
          title: 'Help & Support Desk',
          subtitle: '24/7 Dispatch desk, ticket center & FAQs',
          onTap: () {
            if (Get.isRegistered<NavigationController>()) {
              NavigationController.instance.openSubScreen(
                const HelpSupportScreen(),
                title: 'Help & Support',
              );
            } else {
              Get.toNamed(AvailRoutes.helpSupport);
            }
          },
        ),
        _buildSoftDivider(dark),
        AvailProfileMenuTile(
          icon: Iconsax.info_circle,
          iconColor: const Color(0xFF0284C7),
          title: 'About Haujzo Freight',
          subtitle: 'Learn more about the Haujzo freight ecosystem',
          onTap: () {
            if (Get.isRegistered<NavigationController>()) {
              NavigationController.instance.openSubScreen(
                const AboutUsScreen(),
                title: 'About Haujzo',
              );
            } else {
              Get.toNamed(AvailRoutes.aboutUs);
            }
          },
        ),
        _buildSoftDivider(dark),
        AvailProfileMenuTile(
          icon: Iconsax.document_text,
          iconColor: const Color(0xFF6366F1),
          title: 'Terms of Service',
          subtitle: 'Shipper, corporate KYB, demurrage & anti-fraud rules',
          onTap: () {
            if (Get.isRegistered<NavigationController>()) {
              NavigationController.instance.openSubScreen(
                const TermsOfServiceScreen(),
                title: 'Terms of Service',
              );
            } else {
              Get.toNamed(AvailRoutes.termsOfService);
            }
          },
        ),
        _buildSoftDivider(dark),
        AvailProfileMenuTile(
          icon: Iconsax.security_safe,
          iconColor: const Color(0xFF10B981),
          title: 'Privacy Policy',
          subtitle: 'Location disclosures, Didit KYC/KYB & data protection',
          onTap: () {
            if (Get.isRegistered<NavigationController>()) {
              NavigationController.instance.openSubScreen(
                const PrivacyPolicyScreen(),
                title: 'Privacy Policy',
              );
            } else {
              Get.toNamed(AvailRoutes.privacyPolicy);
            }
          },
        ),
      ],
    );

    return Scaffold(
      backgroundColor: dark ? AvailColors.dark : const Color(0xFFF1F5F9),
      appBar: isEmbedded
          ? null
          : AvailAppbar(
              showBackgroundColor: true,
              backgroundColor: const Color(0xFF0B1D35),
              showBackArrow: Navigator.canPop(context),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AvailColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AvailColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Iconsax.user_octagon,
                      size: 17,
                      color: AvailColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXECUTIVE ACCOUNT',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Profile, Security & Preferences',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                if (!isGuest)
                  IconButton(
                    tooltip: 'Profile Details',
                    onPressed: openProfileDetails,
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Iconsax.user_edit,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// -- Mobile curved primary header vs Wide sleek profile banner
            if (!isWide)
              AvailPrimaryHeaderContainer(
                child: Column(
                  children: [
                    const AvailUserProfileTile(),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: _buildQuickStatusStrip(
                        context: context,
                        userController: userController,
                        isGuest: isGuest,
                        onTapProfile: openProfileDetails,
                        onTapVerification: openVerification,
                        onTapSecurity: openPrivacySecurity,
                      ),
                    ),
                  ],
                ),
              )
            else
              ResponsiveCenter(
                maxWidth: 1120,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0B1D35),
                        Color(0xFF122F51),
                        Color(0xFF1A3E6B),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AvailColors.secondary.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const AvailUserProfileTile(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        child: _buildQuickStatusStrip(
                          context: context,
                          userController: userController,
                          isGuest: isGuest,
                          onTapProfile: openProfileDetails,
                          onTapVerification: openVerification,
                          onTapSecurity: openPrivacySecurity,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            /// -- Body Content
            ResponsiveCenter(
              maxWidth: 1120,
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 24 : 16,
                vertical: isWide ? 12 : 4,
              ),
              child: Column(
                children: [
                  if (isWide)
                    ResponsiveTwoColumn(
                      breakpoint: 800,
                      spacing: 20,
                      left: _SettingsSectionCard(
                          dark: dark, child: accountSettingsColumn),
                      right: _SettingsSectionCard(
                          dark: dark, child: supportLegalColumn),
                    )
                  else ...[
                    _SettingsSectionCard(
                        dark: dark, child: accountSettingsColumn),
                    const SizedBox(height: 16),
                    _SettingsSectionCard(
                        dark: dark, child: supportLegalColumn),
                  ],

                  /// -- Logout / Login & Account Deletion Card
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: isWide ? 460 : double.infinity),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF132238) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: dark
                              ? const Color(0xFF1E3A5F)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: dark ? 0.2 : 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isGuest
                          ? Column(
                              children: [
                                const Text(
                                  'Ready to ship or haul freight?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        Get.toNamed(AvailRoutes.signIn),
                                    icon: const Icon(Iconsax.login,
                                        size: 18, color: Colors.white),
                                    label: const Text('Sign In to Account'),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: () => UserController.instance
                                        .logOutAccountWarningPop(),
                                    icon: Icon(
                                      Iconsax.logout_1,
                                      size: 18,
                                      color: dark
                                          ? Colors.white
                                          : AvailColors.secondary,
                                    ),
                                    label: Text(
                                      'Sign Out of Account',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: dark
                                            ? Colors.white
                                            : AvailColors.secondary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: dark
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : const Color(0xFFF8FAFC),
                                      side: BorderSide(
                                        color: dark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: TextButton.icon(
                                    onPressed: () => UserController.instance
                                        .deleteAccountWarningPop(),
                                    icon: const Icon(Iconsax.trash,
                                        size: 16, color: Color(0xFFEF4444)),
                                    label: const Text(
                                      'Delete Account Permanently',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444)
                                          .withValues(alpha: 0.08),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  /// -- Executive App Footer
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'HAUJZO LOGISTICS NETWORK • v1.0.1',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: dark
                                    ? Colors.grey.shade400
                                    : AvailColors.darkgrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'End-to-End Encrypted Freight & DIDIT KYB Verified',
                          style: TextStyle(
                            fontSize: 10,
                            color: dark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AvailSizes.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatusStrip({
    required BuildContext context,
    required UserController userController,
    required bool isGuest,
    required VoidCallback onTapProfile,
    required VoidCallback onTapVerification,
    required VoidCallback onTapSecurity,
  }) {
    return Obx(() {
      final user = userController.user.value;
      final isVerified = !isGuest && user.canWork;
      final isUnderReview = !isGuest && user.isUnderAdminReview;

      final String kycLabel = isGuest
          ? 'Sign In'
          : (isVerified
              ? 'Approved'
              : (isUnderReview ? 'In Review' : 'Action Due'));
      final Color kycColor = isVerified
          ? const Color(0xFF34D399)
          : (isUnderReview
              ? const Color(0xFFFBBF24)
              : const Color(0xFFFF8A3D));

      final String tierLabel = isGuest
          ? 'Guest'
          : (user.isBusiness ? 'Corporate' : 'Individual');

      return Row(
        children: [
          Expanded(
            child: _QuickHeaderPill(
              icon: Iconsax.verify5,
              label: 'KYC / KYB',
              value: kycLabel,
              accent: kycColor,
              onTap: onTapVerification,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickHeaderPill(
              icon: user.isBusiness ? Iconsax.building_4 : Iconsax.user_octagon,
              label: 'ACCOUNT TIER',
              value: tierLabel,
              accent: const Color(0xFF38BDF8),
              onTap: onTapProfile,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickHeaderPill(
              icon: Iconsax.shield_tick5,
              label: 'SECURITY',
              value: 'Protected',
              accent: const Color(0xFFA78BFA),
              onTap: onTapSecurity,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSectionTitle({
    required bool dark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : AvailColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: dark ? Colors.grey.shade400 : AvailColors.darkgrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftDivider(bool dark) {
    return Divider(
      height: 1,
      indent: 64,
      endIndent: 10,
      color: dark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF1F5F9),
    );
  }
}

class _QuickHeaderPill extends StatelessWidget {
  const _QuickHeaderPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF132238) : AvailColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
