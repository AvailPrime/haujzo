import '../shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../features/personalization/controllers/user_controller.dart';
import '../../../features/personalization/screens/profile/profile.dart';
import '../../../routes/routes.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/image_strings.dart';
import '../images/avail_circular_image.dart';

import 'package:truck_booking/navigation_menu.dart';

class AvailUserProfileTile extends StatelessWidget {
  const AvailUserProfileTile({
    super.key,
    this.onPressed,
  });

  final VoidCallback? onPressed;

  void _onProfileTap(bool isGuest) {
    if (onPressed != null) {
      onPressed!();
    } else if (isGuest) {
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

  @override
  Widget build(BuildContext context) {
    final controller = UserController.instance;
    final isGuest = FirebaseAuth.instance.currentUser == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onProfileTap(isGuest),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                /// -- Glowing Dual-Ring Avatar with Status Badge
                Obx(() {
                  if (controller.profileLoading.value ||
                      controller.imageUploading.value) {
                    return const AvailShimmerEffect(
                        height: 64, width: 64, radius: 64);
                  }
                  final user = controller.user.value;
                  final profileImage = user.profilePicture;
                  final isNetwork = profileImage.isNotEmpty && !isGuest;
                  final isApproved = !isGuest && user.canWork;
                  final isUnderReview = !isGuest && user.isUnderAdminReview;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AvailColors.lineargradient,
                          boxShadow: [
                            BoxShadow(
                              color: AvailColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B1D35),
                            shape: BoxShape.circle,
                          ),
                          child: AvailCircularImage(
                            image: isNetwork ? profileImage : AvailImages.user,
                            isNetworkImage: isNetwork,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            padding: 0,
                            applyImageRadius: true,
                          ),
                        ),
                      ),
                      if (!isGuest)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isApproved
                                  ? const Color(0xFF10B981)
                                  : (isUnderReview
                                      ? const Color(0xFFF59E0B)
                                      : AvailColors.primary),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF0B1D35),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isApproved
                                  ? Icons.check
                                  : (isUnderReview
                                      ? Iconsax.clock
                                      : Iconsax.shield_tick),
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(width: 14),

                /// -- Name, Tier & Verification Status
                Expanded(
                  child: Obx(() {
                    if (controller.profileLoading.value) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AvailShimmerEffect(height: 16, width: 140),
                          SizedBox(height: 6),
                          AvailShimmerEffect(height: 12, width: 170),
                        ],
                      );
                    }

                    final user = controller.user.value;
                    final displayName = isGuest
                        ? 'Guest Shipper'
                        : (user.fullName.trim().isNotEmpty
                            ? user.fullName
                            : 'Haujzo Member');
                    final isApproved = !isGuest && user.canWork;
                    final isUnderReview = !isGuest && user.isUnderAdminReview;
                    final roleLabel = isGuest
                        ? 'GUEST ACCESS'
                        : (user.role == 'driver'
                            ? 'FLEET OPERATOR'
                            : (user.isBusiness
                                ? 'CORPORATE SHIPPER'
                                : 'INDIVIDUAL SHIPPER'));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            if (!isGuest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
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
                                child: Text(
                                  isApproved
                                      ? 'VERIFIED'
                                      : (isUnderReview
                                          ? 'IN REVIEW'
                                          : 'UNVERIFIED'),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: isApproved
                                        ? const Color(0xFF34D399)
                                        : (isUnderReview
                                            ? const Color(0xFFFBBF24)
                                            : const Color(0xFFFF9E5E)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isGuest
                              ? 'Sign in to dispatch & track freight live'
                              : user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user.isBusiness
                                        ? Iconsax.building_4
                                        : Iconsax.user_tick,
                                    size: 10,
                                    color: AvailColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    roleLabel,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isGuest && user.phoneNumber.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  user.formattedPhoneNo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.68),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(width: 10),

                /// -- Action Pill Button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: AvailColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AvailColors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGuest ? Iconsax.login : Iconsax.edit_2,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isGuest ? 'Login' : 'Edit',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
