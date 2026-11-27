import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:truck_booking/commons/widgets/appBar/appbar.dart';
import 'package:truck_booking/commons/widgets/layouts/app_page_layout.dart';
import 'package:truck_booking/commons/widgets/layouts/site_layout.dart';
import 'package:truck_booking/features/personalization/controllers/user_controller.dart';
import 'package:truck_booking/features/shop/controllers/customer/customer_home_controller.dart';
import 'package:truck_booking/utils/constants/colors.dart';
import 'package:truck_booking/utils/constants/sizes.dart';
import 'package:truck_booking/utils/helpers/helper_functions.dart';
import 'package:truck_booking/navigation_menu.dart';
import 'package:truck_booking/routes/routes.dart';
import 'widgets/freight_booking_form.dart';
import 'widgets/route_suggestions_selector.dart';

class JobDispatchScreen extends StatelessWidget {
  const JobDispatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CustomerHomeController.instance;
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    final isWide = SiteLayout.isWideScreen(context);

    return AppPageLayout(
      title: 'Cargo Job Dispatch',
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            controller.mapController = controller.homeMapController;
            if (controller.editingBookingId.value.isNotEmpty) {
              controller.resetForm();
            }
          }
        },
        child: Scaffold(
          backgroundColor: darkMode ? AvailColors.dark : const Color(0xFFF4F6F9),
          appBar: isWide
              ? null
              : AvailAppbar(
                  showBackgroundColor: true,
                  showBackArrow: true,
                  backArrowColor: Colors.white,
                  leadingOnPressed: () {
                    controller.mapController = controller.homeMapController;
                    if (controller.editingBookingId.value.isNotEmpty) {
                      controller.resetForm();
                    }
                    if (Get.isRegistered<NavigationController>() &&
                        NavigationController.instance.subScreen.value != null) {
                      NavigationController.instance.closeSubScreen();
                    } else if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Text(
                controller.editingBookingId.value.isNotEmpty
                    ? 'EDIT FREIGHT MANIFEST'
                    : 'DISPATCH CARGO JOB',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              )),
              Obx(
                () => Text(
                  controller.estimatedDistance.value != '0 km'
                      ? '${controller.estimatedDistance.value} • ${controller.estimatedTime.value}'
                      : 'Configure Route & Freight Details',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Obx(() {
              final price = controller.calculatedPrice.value;
              if (price <= 0) return const SizedBox();
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AvailColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AvailColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.wallet_3, size: 14, color: AvailColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      controller.formattedTotalPrice,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: AvailColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isSplit = constraints.maxWidth >= 960;

            return SingleChildScrollView(
              controller: controller.dispatchScrollController,
              padding: EdgeInsets.symmetric(
                horizontal: isSplit ? 24 : 0,
                vertical: isSplit ? 20 : 0,
              ),
              child: ResponsiveCenter(
                maxWidth: 1320,
                child: Column(
                  children: [
                    // 0. Verification & Admin Review Warning Banner
                    _buildVerificationBanner(isSplit),

                    if (isSplit)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Route Map + Suggestions + Quick Summary
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildRouteMapCard(controller, darkMode, height: 340),
                                const SizedBox(height: 14),
                                const RouteSuggestionsSelector(),
                                const SizedBox(height: 14),
                                _buildLiveEstimateCard(controller, darkMode),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right Column: Main Freight Booking Form Card
                          Expanded(
                            flex: 6,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: darkMode ? const Color(0xFF132238) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: darkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: darkMode ? 0.25 : 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const JobForm(),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AvailSizes.defaultSpace,
                          AvailSizes.sm,
                          AvailSizes.defaultSpace,
                          0,
                        ),
                        child: _buildRouteMapCard(controller, darkMode, height: 180),
                      ),
                      const RouteSuggestionsSelector(),
                      const Padding(
                        padding: EdgeInsets.all(AvailSizes.defaultSpace),
                        child: JobForm(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildVerificationBanner(bool isSplit) {
    return Obx(() {
      final userController = Get.isRegistered<UserController>()
          ? UserController.instance
          : Get.put(UserController());
      final user = userController.user.value;
      if (user.canWork || user.id.isEmpty) return const SizedBox.shrink();

      final isUnderReview = user.isUnderAdminReview;
      final isRejected = user.isAdminRejected;

      final Color bg = isRejected
          ? Colors.red.shade50
          : (isUnderReview ? Colors.orange.shade50 : Colors.blue.shade50);
      final Color border = isRejected
          ? Colors.red.shade300
          : (isUnderReview ? Colors.orange.shade300 : Colors.blue.shade300);
      final Color textCol = isRejected
          ? Colors.red.shade900
          : (isUnderReview ? Colors.orange.shade900 : Colors.blue.shade900);
      final IconData icon = isRejected
          ? Iconsax.close_circle
          : (isUnderReview ? Iconsax.clock : Iconsax.shield_security);

      final String msg = isRejected
          ? 'Account Declined: ${user.adminRejectionReason.isNotEmpty ? user.adminRejectionReason : "Admin approval required."}'
          : (isUnderReview
              ? 'Under Admin Review: Identity verified. Operations admin is reviewing your account before you can confirm dispatch.'
              : 'Verification Required: Complete KYC/KYB identity verification before dispatching cargo.');

      return Padding(
        padding: EdgeInsets.fromLTRB(
          isSplit ? 0 : AvailSizes.defaultSpace,
          AvailSizes.sm,
          isSplit ? 0 : AvailSizes.defaultSpace,
          isSplit ? 16 : 0,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, color: textCol, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(fontSize: 11.5, color: textCol, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Get.toNamed(AvailRoutes.diditVerification),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 32),
                  backgroundColor: border,
                ),
                child: const Text(
                  'View',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildRouteMapCard(
    CustomerHomeController controller,
    bool darkMode, {
    required double height,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: darkMode ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Obx(
              () => GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: controller.pickupLocation.value ?? const LatLng(5.6037, -0.1870),
                  zoom: 14,
                ),
                onMapCreated: controller.onMapCreated,
                markers: controller.markers.toSet(),
                polylines: controller.polylines.toSet(),
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Obx(() {
                final routes = controller.suggestedRoutes;
                final selectedIdx = controller.selectedRouteIndex.value.clamp(
                  0,
                  routes.isNotEmpty ? routes.length - 1 : 0,
                );
                final color =
                    routes.isNotEmpty ? routes[selectedIdx].trafficStatusColor : Colors.green;
                final text = routes.isNotEmpty
                    ? '${controller.trafficCondition.value} • ${routes.length} Option${routes.length > 1 ? "s" : ""}'
                    : 'Interactive Route Preview';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (darkMode ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: darkMode ? Colors.white12 : Colors.black12,
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: darkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveEstimateCard(CustomerHomeController controller, bool darkMode) {
    return Obx(() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AvailColors.navyGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AvailColors.secondary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Iconsax.calculator, color: AvailColors.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'LIVE DISPATCH ESTIMATE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.calculatedPrice.value > 0
                          ? controller.formattedTotalPrice
                          : 'Set Route & Cargo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${controller.estimatedDistance.value} • ${controller.estimatedTime.value}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    controller.selectedTruckType.value.isNotEmpty
                        ? controller.selectedTruckType.value
                        : 'Select Truck',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
