import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:truck_booking/features/shop/controllers/customer/customer_home_controller.dart';
import 'package:truck_booking/features/shop/screens/customer_home/job_dispatch_screen.dart';
import 'package:truck_booking/utils/constants/colors.dart';
import 'package:truck_booking/utils/constants/sizes.dart';
import 'package:truck_booking/utils/constants/image_strings.dart';
import 'package:truck_booking/utils/helpers/helper_functions.dart';

import 'package:truck_booking/data/repositories/bookings/booking_repository.dart';
import 'package:truck_booking/features/shop/models/booking_model.dart';
import 'package:truck_booking/features/personalization/controllers/user_controller.dart';
import 'package:truck_booking/features/personalization/controllers/localization_controller.dart';
import 'package:truck_booking/features/personalization/controllers/notification_controller.dart';
import 'package:truck_booking/features/personalization/screens/notifications/notifications.dart';
import 'package:truck_booking/features/personalization/screens/profile/profile.dart';

import '../bookings/booking_details_screen.dart';
import '../chat/trip_chat_screen.dart';
import 'package:truck_booking/commons/widgets/images/driver_profile_avatar.dart';
import 'package:truck_booking/commons/widgets/layouts/site_layout.dart';
import 'widgets/animated_3d_map_pin.dart';
import 'widgets/route_telemetry_hud.dart';
import 'package:truck_booking/features/personalization/screens/verification/didit_verification_screen.dart';
import 'package:truck_booking/routes/routes.dart';
import 'package:truck_booking/navigation_menu.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CustomerHomeController.instance;
    final userController = Get.isRegistered<UserController>() ? UserController.instance : Get.put(UserController());
    final notifController = Get.isRegistered<NotificationController>() ? NotificationController.instance : Get.put(NotificationController());
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return PopScope(
      canPop: !controller.isSelectingOnMap.value,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && controller.isSelectingOnMap.value) {
          controller.exitMapSelectionMode();
        }
      },
      child: Scaffold(
        body: Stack(
        children: [
          // 1. Full Screen Interactive Map
          Obx(
            () => GoogleMap(
              initialCameraPosition: CameraPosition(
                target: controller.currentPosition.value ?? const LatLng(5.6037, -0.1870),
                zoom: 15,
              ),
              onMapCreated: controller.onHomeMapCreated,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: controller.mapType.value,
              trafficEnabled: controller.isTrafficEnabled.value,
              markers: controller.isSelectingOnMap.value ? <Marker>{}.toSet() : controller.markers.toSet(),
              polylines: controller.isSelectingOnMap.value ? <Polyline>{}.toSet() : controller.polylines.toSet(),
              padding: EdgeInsets.only(bottom: controller.isSelectingOnMap.value ? 120 : 130),
              onCameraMove: (position) {
                if (controller.isSelectingOnMap.value) {
                  controller.updatePinnedAddress(position.target);
                }
              },
            ),
          ),

          // 2. Minimal Top Header Controls (Active Job Header or Minimal Avatar & Notification Controls)
          Obx(() {
            final isWide = SiteLayout.isWideScreen(context);
            final isEmbedded = isWide && !Navigator.canPop(context);
            if (controller.selectedJobOnMap.value != null) {
              return Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: AvailSizes.defaultSpace,
                right: isWide ? null : AvailSizes.defaultSpace,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 460 : double.infinity,
                  ),
                  child: _buildActiveJobHeader(controller, darkMode),
                ),
              );
            }
            if (isEmbedded) return const SizedBox.shrink();
            return _buildMinimalTopHeader(context, userController, notifController, darkMode);
          }),

          // 2.2 Verification & Admin Operations Approval Status Alert Banner
          Obx(() => _buildVerificationStatusBanner(context, userController, darkMode)),

          // 2.5 Floating Map Control Buttons (Right Side: Re-center, Traffic, Layers)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 65,
            child: Obx(() => Column(
              children: [
                // Re-center GPS Location Button
                FloatingActionButton.small(
                  heroTag: 'home_recenter_btn',
                  onPressed: () => controller.recenterToCurrentLocation(),
                  backgroundColor: darkMode ? const Color(0xFF0F172A) : Colors.white,
                  foregroundColor: AvailColors.primary,
                  child: const Icon(Iconsax.gps, size: 18),
                ),
                const SizedBox(height: 8),

                // Live Traffic Toggle Button
                FloatingActionButton.small(
                  heroTag: 'home_traffic_btn',
                  onPressed: () => controller.toggleTraffic(),
                  backgroundColor: controller.isTrafficEnabled.value ? Colors.green : (darkMode ? const Color(0xFF0F172A) : Colors.white),
                  foregroundColor: controller.isTrafficEnabled.value ? Colors.white : (darkMode ? Colors.white : Colors.black87),
                  child: const Icon(Iconsax.routing, size: 18),
                ),
                const SizedBox(height: 8),

                // Map Layer Switcher Button
                FloatingActionButton.small(
                  heroTag: 'home_layer_btn',
                  onPressed: () => controller.toggleMapType(),
                  backgroundColor: darkMode ? const Color(0xFF0F172A) : Colors.white,
                  foregroundColor: Colors.blue,
                  child: const Icon(Iconsax.layer, size: 18),
                ),

                // 3D Follow Mode Toggle (When active job is selected)
                if (controller.selectedJobOnMap.value != null) ...[
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'home_3d_btn',
                    onPressed: () {
                      controller.is3DFollowMode.value = !controller.is3DFollowMode.value;
                      if (controller.is3DFollowMode.value && controller.driverLocation.value != null) {
                        controller.mapController?.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: controller.driverLocation.value!,
                              zoom: 18.0,
                              tilt: 58.0,
                            ),
                          ),
                        );
                      }
                    },
                    backgroundColor: controller.is3DFollowMode.value ? AvailColors.primary : (darkMode ? const Color(0xFF0F172A) : Colors.white),
                    foregroundColor: controller.is3DFollowMode.value ? Colors.white : AvailColors.primary,
                    child: const Icon(Iconsax.radar5, size: 18),
                  ),
                ],

                const SizedBox(height: 8),
                // Fullscreen Map / Zen Mode Toggle Button
                FloatingActionButton.small(
                  heroTag: 'home_fullscreen_btn',
                  onPressed: () => controller.isMapFullscreen.value = !controller.isMapFullscreen.value,
                  backgroundColor: controller.isMapFullscreen.value ? AvailColors.primary : (darkMode ? const Color(0xFF0F172A) : Colors.white),
                  foregroundColor: controller.isMapFullscreen.value ? Colors.white : AvailColors.primary,
                  child: Icon(controller.isMapFullscreen.value ? Icons.fullscreen_exit : Icons.fullscreen, size: 20),
                ),
              ],
            )),
          ),

          // 3. Draggable Job Tracker Button
          Obx(() {
            if (controller.isMapFullscreen.value) return const SizedBox.shrink();
            return Positioned(
              left: controller.draggableButtonPosition.value.dx,
              top: controller.draggableButtonPosition.value.dy,
              child: Draggable(
                feedback: _buildDraggableButton(darkMode, isDragging: true),
                childWhenDragging: const SizedBox(),
                onDragEnd: (details) {
                  double dx = details.offset.dx.clamp(0, MediaQuery.of(context).size.width - 60);
                  double dy = details.offset.dy.clamp(120, MediaQuery.of(context).size.height - 250);
                  controller.draggableButtonPosition.value = Offset(dx, dy);
                },
                child: GestureDetector(
                  onTap: () => _showJobsBottomSheet(context, controller, darkMode),
                  child: _buildDraggableButton(darkMode),
                ),
              ),
            );
          }),

          // 3.5 Floating Route Telemetry HUD (With sleek compact mode to maximize map area)
          Obx(() {
            if (controller.isSelectingOnMap.value || controller.isMapFullscreen.value) {
              return const SizedBox.shrink();
            }
            final routeData = controller.currentRouteData.value;
            if (routeData == null || !controller.isRouteHUDVisible.value) {
              return const SizedBox.shrink();
            }

            final bool isWide = SiteLayout.isWideScreen(context);
            final bool hasJob = controller.selectedJobOnMap.value != null;
            final double bottomOffset = hasJob
                ? (controller.isJobCardExpanded.value ? 230 : 95)
                : 16;

            return Positioned(
              bottom: bottomOffset,
              left: isWide ? AvailSizes.defaultSpace : 0,
              right: isWide ? null : 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 460 : double.infinity,
                ),
                child: RouteTelemetryHUD(
                  routeData: routeData,
                  initiallyCompact: false,
                  suggestedRoutes: controller.suggestedRoutes,
                  selectedRouteIndex: controller.selectedRouteIndex.value,
                  onSelectRoute: (idx) => controller.selectSuggestedRoute(idx),
                  onClearRoute: () => controller.clearCurrentRoute(),
                  onRecenter: () => controller.recenterRoute(),
                  onReverseRoute: () => controller.reverseRoute(),
                ),
              ),
            );
          }),

          // 4. Dynamic Overlay (Bottom Sheet)
          Obx(() {
            if (controller.isMapFullscreen.value) {
              return Positioned(
                bottom: 25,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => controller.isMapFullscreen.value = false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AvailColors.secondary.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen_exit, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Exit Fullscreen Map',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            if (controller.isSelectingOnMap.value) return _buildMapPinOverlay(context, controller, darkMode);
            
            final job = controller.selectedJobOnMap.value;
            if (job == null) {
              // When Route HUD is active, hide default Register Manifest card to give 85%+ screen real estate to the map
              if (controller.isRouteHUDVisible.value) {
                return const SizedBox.shrink();
              }
              return _buildDefaultBottomCard(context, controller, darkMode);
            }
            return _buildJobSummaryOverlay(context, controller, job, darkMode);
          }),

          // 5. Floating Mode Header (for Map Selection)
          Obx(() {
            if (!controller.isSelectingOnMap.value) return const SizedBox();
            return Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: AvailSizes.defaultSpace,
              right: AvailSizes.defaultSpace,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AvailColors.secondary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15)],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => controller.exitMapSelectionMode(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.arrow_left, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select ${controller.selectingLocationType.value} location on map',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // 6. Custom 3D Professional Map Pin Widget
          Animated3DMapPin(controller: controller),
        ],
      ),
    ),
  );
}

  // Minimal Top Header: Profile Avatar (Left) & Notification Bell Button (Right)
  Widget _buildMinimalTopHeader(
    BuildContext context, 
    UserController userController, 
    NotificationController notifController, 
    bool darkMode,
  ) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: AvailSizes.defaultSpace,
      right: AvailSizes.defaultSpace,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Left: User Profile Avatar
          GestureDetector(
            onTap: () {
              if (Get.isRegistered<NavigationController>()) {
                NavigationController.instance.openSubScreen(
                  const ProfileScreen(),
                  title: 'My Profile',
                );
              } else {
                Get.toNamed(AvailRoutes.userProfile);
              }
            },
            child: Obx(() {
              final user = userController.user.value;
              return Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: (darkMode ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AvailColors.primary.withValues(alpha: 0.15),
                  backgroundImage: user.profilePicture.isNotEmpty 
                    ? NetworkImage(user.profilePicture) 
                    : const AssetImage(AvailImages.user) as ImageProvider,
                ),
              );
            }),
          ),

          // Top Right: Notification Bell Button with Red Unread Badge Counter
          Obx(() {
            final unreadCount = notifController.allNotifications.where((n) => !n.isRead).length;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () {
                    if (Get.isRegistered<NavigationController>()) {
                      NavigationController.instance.selectedIndex.value = 5;
                    } else {
                      Get.toNamed(AvailRoutes.notifications);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (darkMode ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Icon(
                      Iconsax.notification, 
                      size: 20, 
                      color: darkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMapPinOverlay(BuildContext context, CustomerHomeController controller, bool darkMode) {
    final isWide = SiteLayout.isWideScreen(context);
    return Positioned(
      bottom: isWide ? 20 : 0,
      left: isWide ? AvailSizes.defaultSpace : 0,
      right: isWide ? null : 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 440 : double.infinity),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: darkMode ? AvailColors.secondary : Colors.white,
            borderRadius: isWide
                ? BorderRadius.circular(24)
                : const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 20)],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.location, color: controller.selectingLocationType.value == 'pickup' ? Colors.blue : Colors.red),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SET ${controller.selectingLocationType.value.toUpperCase()} LOCATION', 
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          Obx(() => Text(
                            controller.pinnedAddress.value, 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.exitMapSelectionMode(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => controller.confirmPinnedLocation(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AvailColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Confirm Location', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableButton(bool darkMode, {bool isDragging = false}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AvailColors.secondary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDragging ? 0.3 : 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: const Icon(Iconsax.radar5, color: AvailColors.primary, size: 28),
    );
  }

  Widget _buildActiveJobHeader(CustomerHomeController controller, bool darkMode) {
    final job = controller.selectedJobOnMap.value!;
    final String bookingId = job.bookingId.isNotEmpty ? job.bookingId : job.id;
    String displayId = bookingId.toUpperCase();
    if (!displayId.startsWith('FT')) {
      displayId = "FT-$displayId";
    }

    final routeData = controller.currentRouteData.value;
    final trafficColor = routeData?.trafficStatusColor ?? const Color(0xFF10B981);
    final trafficStatus = routeData?.trafficStatus ?? 'Live Traffic Active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AvailColors.secondary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15)],
      ),
      child: Row(
        children: [
          const Icon(Iconsax.truck_fast, color: AvailColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  'Tracking: #$displayId',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: trafficColor),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    trafficStatus,
                    style: TextStyle(color: trafficColor, fontSize: 10, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.clearMapTracking(),
            child: const Icon(Icons.close, color: Colors.white54, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildJobSummaryOverlay(BuildContext context, CustomerHomeController controller, BookingModel job, bool darkMode) {
    final isWide = SiteLayout.isWideScreen(context);
    return Positioned(
      bottom: 20,
      left: AvailSizes.defaultSpace,
      right: isWide ? null : AvailSizes.defaultSpace,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 440 : double.infinity),
        child: Obx(() {
        final bool isExpanded = controller.isJobCardExpanded.value;

        if (!isExpanded) {
          // Ultra-Sleek Compact Bottom Card leaving 85%+ of screen to the map
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: darkMode ? AvailColors.secondary : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: darkMode ? 0.35 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildSummaryIcon(Iconsax.routing, AvailColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${job.cargoType.toUpperCase()} • ${job.distance.toStringAsFixed(1)} KM',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocalizationController.instance.getFormattedPrice(job.price),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AvailColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (Get.isRegistered<NavigationController>()) {
                      NavigationController.instance.openSubScreen(
                        BookingDetailsScreen(booking: job),
                        title: 'Manifest Details',
                      );
                    } else {
                      Get.toNamed(AvailRoutes.bookingDetails, arguments: job);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AvailColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('DETAILS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => controller.isJobCardExpanded.value = true,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.keyboard_arrow_up, size: 18, color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        }

        // Expanded Bottom Card with Visual Stepper, Driver info, and Collapse button
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: darkMode ? AvailColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: darkMode ? 0.35 : 0.12),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildSummaryIcon(Iconsax.routing, AvailColors.primary),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.cargoType.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text('${job.distance.toStringAsFixed(1)} KM Trip', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        LocalizationController.instance.getFormattedPrice(job.price),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AvailColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => controller.shareManifest(job),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AvailColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AvailColors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.share_rounded,
                                  size: 13,
                                  color: AvailColors.primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Share',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AvailColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => controller.isJobCardExpanded.value = false,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              
              // Visual Journey Tracker
              _buildJourneyStepper(job.status),
              const SizedBox(height: 16),

              if (job.driverName != null) ...[
                _buildDriverInfo(job),
                const Divider(height: 24),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniMetric('WEIGHT', '${job.weight}T', Colors.grey),
                  _buildMiniMetric('ID', 'FT-${job.bookingId.length >= 4 ? job.bookingId.substring(0, 4).toUpperCase() : (job.bookingId.isEmpty ? "0000" : job.bookingId.toUpperCase())}', Colors.grey),
                  ElevatedButton(
                    onPressed: () {
                      if (Get.isRegistered<NavigationController>()) {
                        NavigationController.instance.openSubScreen(
                          BookingDetailsScreen(booking: job),
                          title: 'Manifest Details',
                        );
                      } else {
                        Get.toNamed(AvailRoutes.bookingDetails, arguments: job);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AvailColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('DETAILS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
      ),
    );
  }

  Widget _buildSummaryIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildJourneyStepper(String status) {
    final stages = ['pending', 'confirmed', 'pickedUp', 'inTransit', 'delivered'];
    final labels = ['Pending', 'Confirmed', 'Picked Up', 'In Transit', 'Delivered'];
    int currentStage = stages.indexOf(status);
    if (status == 'onTheWayToPickup') currentStage = 1;
    if (currentStage == -1) currentStage = 0;

    const Color completedColor = Color(0xFF10B981);
    final Color currentColor = currentStage == 4 ? completedColor : AvailColors.primary;
    final Color inactiveLine = Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(stages.length, (index) {
        final bool isCompleted = index < currentStage;
        final bool isCurrent = index == currentStage;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2.5,
                        color: index == 0
                            ? Colors.transparent
                            : (index <= currentStage
                                ? completedColor
                                : inactiveLine),
                      ),
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? completedColor
                            : (isCurrent ? currentColor : Colors.grey.shade200),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted
                              ? completedColor
                              : (isCurrent ? currentColor : Colors.grey.shade300),
                          width: 1,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: currentColor.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted || (isCurrent && currentStage == 4)
                            ? const Icon(
                                Icons.check_rounded,
                                size: 9,
                                color: Colors.white,
                              )
                            : (isCurrent
                                ? Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2.5,
                        color: index == stages.length - 1
                            ? Colors.transparent
                            : (index < currentStage
                                ? completedColor
                                : inactiveLine),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 24,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    height: 1.1,
                    fontWeight: isCurrent
                        ? FontWeight.w900
                        : (isCompleted ? FontWeight.w700 : FontWeight.w500),
                    color: isCurrent
                        ? currentColor
                        : (isCompleted
                            ? completedColor
                            : Colors.grey.shade500),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDriverInfo(BookingModel job) {
    final controller = CustomerHomeController.instance;
    return Row(
      children: [
        DriverProfileAvatar(
          driverImage: job.driverImage,
          driverId: job.driverId,
          radius: 22.5,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.driverName ?? 'Unknown Driver', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${job.vehiclePlate} • ${job.vehicleModel}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
        if (job.canChatWithDriver) ...[
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => Get.to(() => TripChatScreen(booking: job)),
                icon: const Icon(Iconsax.messages_2,
                    color: AvailColors.primary, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AvailColors.primary.withValues(alpha: 0.12),
                ),
                tooltip: 'Chat with Driver',
              ),
              Positioned(
                right: -2,
                top: -2,
                child: ShipperUnreadChatBadge(booking: job, compact: true),
              ),
            ],
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => controller.callDriver(job.driverPhone),
            icon: const Icon(Iconsax.call5, color: Colors.green, size: 20),
            style: IconButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.1)),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 12),
              const SizedBox(width: 4),
              Text(job.driverRating?.toStringAsFixed(1) ?? '5.0', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // Compact & Sleek "Register Your Job Card"
  Widget _buildDefaultBottomCard(BuildContext context, CustomerHomeController controller, bool darkMode) {
    final isWide = SiteLayout.isWideScreen(context);
    return Positioned(
      bottom: 16,
      left: AvailSizes.defaultSpace,
      right: isWide ? null : AvailSizes.defaultSpace,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 440 : double.infinity),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: (darkMode ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: darkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: darkMode ? 0.35 : 0.12), blurRadius: 15, offset: const Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, Live Stats Badge & Action Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AvailColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.truck_fast, color: AvailColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Register Manifest',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      Obx(() => Text(
                        '${controller.activeJobsCount.value} In Transit • ${controller.totalTonsShipped.value.toStringAsFixed(1)}T Shipped',
                        style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                      )),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!controller.checkShipperVerificationAndApproval()) return;
                    controller.resetForm();
                    if (Get.isRegistered<NavigationController>()) {
                      NavigationController.instance.openSubScreen(
                        const JobDispatchScreen(),
                        title: 'Cargo Job Dispatch',
                      );
                    } else {
                      Get.toNamed(AvailRoutes.jobDispatch);
                    }
                  },
                  icon: const Icon(Iconsax.add, size: 16, color: Colors.white),
                  label: const Text('Add Job', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AvailColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 38),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Compact Cargo Categories Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCargoCategoryChip('Container', Iconsax.box, controller),
                  const SizedBox(width: 6),
                  _buildCargoCategoryChip('Bulk', Iconsax.truck_tick, controller),
                  const SizedBox(width: 6),
                  _buildCargoCategoryChip('Heavy', Iconsax.weight, controller),
                  const SizedBox(width: 6),
                  _buildCargoCategoryChip('General', Iconsax.archive, controller),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCargoCategoryChip(String label, IconData icon, CustomerHomeController controller) {
    return Obx(() {
      final isSelected = controller.selectedCargoType.value.toLowerCase().contains(label.toLowerCase().split(' ')[0]);
      return GestureDetector(
        onTap: () {
          if (!controller.checkShipperVerificationAndApproval()) return;
          controller.resetForm();
          controller.updateCargoType(label.contains('Container')
              ? 'Container'
              : (label.contains('Bulk')
                  ? 'Bulk / Loose Material'
                  : (label.contains('General') ? 'General Freight' : 'Heavy Machinery')));
          if (Get.isRegistered<NavigationController>()) {
            NavigationController.instance.openSubScreen(
              const JobDispatchScreen(),
              title: 'Cargo Job Dispatch',
            );
          } else {
            Get.toNamed(AvailRoutes.jobDispatch);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AvailColors.primary : AvailColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AvailColors.primary : AvailColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 12, color: isSelected ? Colors.white : AvailColors.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AvailColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Verification & Admin Approval Alert Banner on Home Screen Map
  Widget _buildVerificationStatusBanner(BuildContext context, UserController userController, bool darkMode) {
    final user = userController.user.value;
    if (user.canWork || user.id.isEmpty) return const SizedBox.shrink();

    final isUnderReview = user.isUnderAdminReview;
    final isRejected = user.isAdminRejected;

    Color bg;
    Color border;
    IconData icon;
    String text;
    String actionLabel;

    if (isRejected) {
      bg = Colors.red.shade900.withValues(alpha: 0.92);
      border = Colors.red.shade400;
      icon = Iconsax.close_circle;
      text = 'Account Declined: Action required to activate bookings';
      actionLabel = 'Details';
    } else if (isUnderReview) {
      bg = Colors.orange.shade900.withValues(alpha: 0.92);
      border = Colors.orange.shade400;
      icon = Iconsax.clock;
      text = 'Under Admin Review: KYC verified, approval in progress';
      actionLabel = 'Status';
    } else {
      bg = AvailColors.primary.withValues(alpha: 0.95);
      border = Colors.white24;
      icon = Iconsax.shield_security;
      text = 'Verification Required: Complete KYC to book trucks';
      actionLabel = 'Verify';
    }

    final isWide = SiteLayout.isWideScreen(context);
    final isEmbedded = isWide && !Navigator.canPop(context);
    return Positioned(
      top: isEmbedded ? 16 : MediaQuery.of(context).padding.top + 58,
      left: AvailSizes.defaultSpace,
      right: isWide ? null : 70, // Leaves room for right-side GPS / Layer buttons
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 460 : double.infinity),
        child: GestureDetector(
          onTap: () {
            if (Get.isRegistered<NavigationController>()) {
              NavigationController.instance.openSubScreen(
                const DiditVerificationScreen(),
                title: 'Identity Verification',
              );
            } else {
              Get.toNamed(AvailRoutes.diditVerification);
            }
          },
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showJobsBottomSheet(BuildContext context, CustomerHomeController controller, bool darkMode) {
    final isWide = SiteLayout.isWideScreen(context);
    final sheetContent = Container(
      height: isWide ? 560 : MediaQuery.of(context).size.height * 0.65,
      width: isWide ? 540 : double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkMode ? AvailColors.dark : Colors.white,
        borderRadius: isWide
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(30)),
      ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACTIVE MANIFESTS', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      const Text('Track your ongoing freight operations', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  const Icon(Iconsax.radar, color: AvailColors.primary, size: 24),
                ],
              ),
              const SizedBox(height: 25),
              Expanded(
                child: StreamBuilder<List<BookingModel>>(
                  stream: BookingRepository.instance.getUserBookingsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final bookings = snapshot.data ?? [];
                    if (bookings.isEmpty) return const Center(child: Text('No active jobs found.'));

                    return ListView.separated(
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final job = bookings[index];
                        return InkWell(
                          onTap: () {
                            controller.showJobOnMap(job);
                            Get.back();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: darkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8F9FA),
                              border: Border.all(color: darkMode ? Colors.white10 : Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: AvailColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                                      child: Icon(_getCargoIcon(job.cargoType), color: AvailColors.primary, size: 22),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Builder(builder: (context) {
                                            final String bookingId = job.bookingId.isNotEmpty ? job.bookingId : job.id;
                                            String displayId = bookingId.toUpperCase();
                                            if (!displayId.startsWith('FT')) {
                                              displayId = "FT-$displayId";
                                            }
                                            return Text('#$displayId', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AvailColors.primary));
                                          }),
                                          Text(job.pickupAddress, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          Text('To: ${job.dropoffAddress}', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    _buildStatusChip(job.status),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildMiniInfo(Iconsax.routing, '${job.distance.toStringAsFixed(1)} KM'),
                                    _buildMiniInfo(Iconsax.wallet_3, LocalizationController.instance.getFormattedPrice(job.price)),
                                    _buildMiniInfo(Iconsax.weight, '${job.weight} Tons'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    if (isWide) {
      Get.dialog(Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: sheetContent,
      ));
    } else {
      Get.bottomSheet(sheetContent, isScrollControlled: true);
    }
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.orange;
    if (status == 'confirmed') color = Colors.blue;
    if (status == 'delivered') color = Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildMiniInfo(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
      ],
    );
  }

  IconData _getCargoIcon(String type) {
    switch (type) {
      case 'Container': return Iconsax.box;
      case 'Bulk': return Iconsax.truck_tick;
      case 'Heavy': return Iconsax.weight;
      default: return Iconsax.archive;
    }
  }
}
