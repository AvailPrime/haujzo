import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/images/avail_circular_image.dart';
import '../../../../commons/widgets/shimmer/shimmer.dart';
import './widgets/profile_menu.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:get/get.dart';

import '../../../../commons/widgets/custom_shapes/containers/primary_header_container.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../controllers/user_controller.dart';
import '../verification/didit_verification_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  double _calculateProfileCompletion(UserController controller) {
    final u = controller.user.value;
    int score = 0;
    const int total = 6;
    if (u.fullName.trim().isNotEmpty) score++;
    if (u.username.trim().isNotEmpty) score++;
    if (u.email.trim().isNotEmpty) score++;
    if (u.phoneNumber.trim().isNotEmpty) score++;
    if (u.gender.trim().isNotEmpty) score++;
    if (u.profilePicture.trim().isNotEmpty || u.isVerified) score++;
    return (score / total).clamp(0.15, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final controller = UserController.instance;
    final dark = AvailHelperFunctions.isDarkMode(context);
    final isWide = SiteLayout.isWideScreen(context);

    final profileIdentityCard = _ProfileSectionCard(
      dark: dark,
      icon: Iconsax.user_octagon,
      accent: AvailColors.primary,
      title: 'Profile Identity',
      subtitle: 'Public display credentials across freight manifests',
      children: [
        Obx(() => AvailProfileMenu(
              leadingIcon: Iconsax.user,
              accentColor: AvailColors.primary,
              icon: Iconsax.edit_2,
              onPressed: () => Get.toNamed(AvailRoutes.changeName),
              title: 'Full Legal Name',
              value: controller.user.value.fullName,
            )),
        Obx(() => AvailProfileMenu(
              leadingIcon: Iconsax.tag_user,
              accentColor: const Color(0xFF0284C7),
              icon: Iconsax.edit_2,
              onPressed: () => Get.toNamed(AvailRoutes.changeUsername),
              title: 'Shipper Username',
              value: controller.user.value.username.isNotEmpty
                  ? '@${controller.user.value.username}'
                  : 'Not Set',
            )),
        Obx(() {
          final user = controller.user.value;
          final isApproved = user.canWork;
          final isUnderReview = user.isUnderAdminReview;
          return AvailProfileMenu(
            leadingIcon: Iconsax.verify5,
            accentColor: isApproved
                ? const Color(0xFF10B981)
                : (isUnderReview
                    ? const Color(0xFFF59E0B)
                    : AvailColors.primary),
            badgeText: isApproved
                ? 'APPROVED'
                : (isUnderReview ? 'PENDING ADMIN' : 'ACTION NEEDED'),
            icon: Iconsax.arrow_right_3,
            onPressed: () {
              if (Get.isRegistered<NavigationController>()) {
                NavigationController.instance.openSubScreen(
                  const DiditVerificationScreen(),
                  title: 'Identity Verification',
                );
              } else {
                Get.toNamed(AvailRoutes.diditVerification);
              }
            },
            title: 'DIDIT KYC / KYB Verification',
            value: isApproved
                ? 'Verified & Approved for Dispatch'
                : (isUnderReview
                    ? 'Identity Verified • Awaiting Operations Approval'
                    : 'Tap to complete KYC/KYB verification'),
          );
        }),
      ],
    );

    final personalDetailsCard = _ProfileSectionCard(
      dark: dark,
      icon: Iconsax.personalcard,
      accent: const Color(0xFF0284C7),
      title: 'Personal & Contact Dossier',
      subtitle: 'Direct communication channels & system identifiers',
      children: [
        Obx(() => AvailProfileMenu(
              leadingIcon: Iconsax.hashtag,
              accentColor: const Color(0xFF6366F1),
              badgeText: 'TAP TO COPY',
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: controller.user.value.id));
                AvailLoaders.successSnackBar(
                  title: 'Copied to Clipboard',
                  message: 'Your Shipper Account ID has been copied.',
                );
              },
              title: 'Account ID',
              value: controller.user.value.id,
              icon: Iconsax.copy,
            )),
        Obx(() => AvailProfileMenu(
              leadingIcon: Iconsax.sms,
              accentColor: const Color(0xFF10B981),
              badgeText: 'VERIFIED',
              isLocked: true,
              onPressed: () {
                AvailLoaders.customToast(
                  message: 'Primary email address is cryptographically bound to your account.',
                );
              },
              title: 'Primary E-mail Address',
              value: controller.user.value.email,
              icon: Iconsax.lock,
            )),
        Obx(() => AvailProfileMenu(
              leadingIcon: Iconsax.call,
              accentColor: AvailColors.primary,
              icon: Iconsax.edit_2,
              onPressed: () => Get.toNamed(AvailRoutes.changePhoneNumber),
              title: 'Phone Number',
              value: controller.user.value.formattedPhoneNo.isNotEmpty
                  ? controller.user.value.formattedPhoneNo
                  : 'Tap to add phone number',
            )),
        Obx(() => AvailProfileMenu(
              leadingIcon: Iconsax.user_tick,
              accentColor: const Color(0xFF8B5CF6),
              icon: Iconsax.arrow_down_1,
              onPressed: () => _showGenderPicker(context, controller, dark),
              title: 'Gender',
              value: controller.user.value.gender.isNotEmpty
                  ? controller.user.value.gender
                  : 'Not Set',
            )),
      ],
    );

    return AppPageLayout(
      title: 'My Profile',
      child: Scaffold(
        backgroundColor: dark ? AvailColors.dark : const Color(0xFFF1F5F9),
        appBar: isWide
            ? null
            : AvailAppbar(
                showBackArrow: true,
                showBackgroundColor: true,
                backgroundColor: const Color(0xFF0B1D35),
                leadingOnPressed: () {
                  if (Get.isRegistered<NavigationController>() &&
                      NavigationController.instance.subScreen.value != null) {
                    NavigationController.instance.closeSubScreen();
                  } else if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROFILE DOSSIER',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Manage Identity & Contact Credentials',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              /// -- Executive Hero Profile Header
              AvailPrimaryHeaderContainer(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                    child: Column(
                      children: [
                        /// -- Glowing Avatar with Floating Camera Action Button
                        Obx(() {
                          final networkImage =
                              controller.user.value.profilePicture;
                          final image = networkImage.isNotEmpty
                              ? networkImage
                              : AvailImages.user;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AvailColors.lineargradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AvailColors.primary
                                          .withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0B1D35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: controller.imageUploading.value
                                      ? const AvailShimmerEffect(
                                          width: 104,
                                          height: 104,
                                          radius: 104,
                                        )
                                      : AvailCircularImage(
                                          image: image,
                                          width: 104,
                                          height: 104,
                                          padding: 0,
                                          applyImageRadius: true,
                                          isNetworkImage:
                                              networkImage.isNotEmpty,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () =>
                                      controller.uploadProfilePicture(),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: AvailColors.lineargradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF0B1D35),
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Iconsax.camera,
                                      size: 17,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 12),

                        /// -- User Full Name & Badges
                        Obx(() {
                          final user = controller.user.value;
                          final isApproved = user.canWork;
                          final isUnderReview = user.isUnderAdminReview;
                          return Column(
                            children: [
                              Text(
                                user.fullName.trim().isNotEmpty
                                    ? user.fullName
                                    : 'Haujzo Member',
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          user.isBusiness
                                              ? Iconsax.building_4
                                              : Iconsax.user_tick,
                                          size: 12,
                                          color: AvailColors.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          user.isBusiness
                                              ? 'CORPORATE SHIPPER'
                                              : 'INDIVIDUAL SHIPPER',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isApproved
                                              ? const Color(0xFF10B981)
                                              : (isUnderReview
                                                  ? const Color(0xFFF59E0B)
                                                  : AvailColors.primary))
                                          .withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: (isApproved
                                                ? const Color(0xFF10B981)
                                                : (isUnderReview
                                                    ? const Color(0xFFF59E0B)
                                                    : AvailColors.primary))
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isApproved
                                              ? Iconsax.verify5
                                              : Iconsax.shield_security,
                                          size: 12,
                                          color: isApproved
                                              ? const Color(0xFF34D399)
                                              : (isUnderReview
                                                  ? const Color(0xFFFBBF24)
                                                  : const Color(0xFFFF9E5E)),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isApproved
                                              ? 'KYC / KYB VERIFIED'
                                              : (isUnderReview
                                                  ? 'UNDER ADMIN REVIEW'
                                                  : 'VERIFICATION PENDING'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: isApproved
                                                ? const Color(0xFF34D399)
                                                : (isUnderReview
                                                    ? const Color(0xFFFBBF24)
                                                    : const Color(0xFFFF9E5E)),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              /// -- Profile Completion Meter Pill
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 420),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.14),
                                    ),
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      final progress =
                                          _calculateProfileCompletion(
                                              controller);
                                      final pct = (progress * 100).round();
                                      return Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'PROFILE DOSSIER STRENGTH',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white70,
                                                  letterSpacing: 0.7,
                                                ),
                                              ),
                                              Text(
                                                '$pct% COMPLETE',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: pct == 100
                                                      ? const Color(0xFF34D399)
                                                      : AvailColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              minHeight: 6,
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.15),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                pct == 100
                                                    ? const Color(0xFF10B981)
                                                    : AvailColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              /// -- Details Cards
              ResponsiveCenter(
                maxWidth: 980,
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    ResponsiveTwoColumn(
                      breakpoint: 780,
                      spacing: 20,
                      left: profileIdentityCard,
                      right: personalDetailsCard,
                    ),

                    const SizedBox(height: 20),

                    /// -- Account Security & Danger Zone Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF132238) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFEF4444)
                              .withValues(alpha: dark ? 0.35 : 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Iconsax.warning_2,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Danger Zone • Account Termination',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: dark
                                        ? Colors.white
                                        : AvailColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Permanently erase your shipper profile, saved hubs, and manifest archives.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: dark
                                        ? Colors.grey.shade400
                                        : AvailColors.darkgrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                controller.deleteAccountWarningPop(),
                            icon: const Icon(
                              Iconsax.trash,
                              size: 15,
                              color: Color(0xFFEF4444),
                            ),
                            label: const Text(
                              'Delete',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AvailSizes.spacebtwsections),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenderPicker(
      BuildContext context, UserController controller, bool dark) {
    final currentGender = controller.user.value.gender;
    final options = [
      {'label': 'Male', 'icon': Iconsax.man, 'color': const Color(0xFF0284C7)},
      {
        'label': 'Female',
        'icon': Iconsax.woman,
        'color': const Color(0xFFEC4899)
      },
      {
        'label': 'Other',
        'icon': Iconsax.user_octagon,
        'color': const Color(0xFF8B5CF6)
      },
    ];

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF0F1E33) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Select Gender',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : AvailColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose how your gender appears on your account dossier',
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey.shade400 : AvailColors.darkgrey,
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final label = opt['label'] as String;
                final icon = opt['icon'] as IconData;
                final color = opt['color'] as Color;
                final isSelected =
                    currentGender.toLowerCase() == label.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      controller.updateGender(label);
                      Get.back();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.12)
                            : (dark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : (dark
                                  ? const Color(0xFF1E3A5F)
                                  : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 19),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color:
                                    dark ? Colors.white : AvailColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Iconsax.tick_circle5, color: color, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.dark,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final bool dark;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF132238) : Colors.white,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: accent),
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
                        color:
                            dark ? Colors.grey.shade400 : AvailColors.darkgrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
