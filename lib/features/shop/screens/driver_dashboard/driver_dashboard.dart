import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../controllers/driver/driver_dashboard_controller.dart';
import 'package:truck_booking/features/personalization/controllers/localization_controller.dart';
import '../../../../commons/widgets/texts/section_heading.dart';
import '../../models/booking_model.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DriverDashboardController());
    final dark = AvailHelperFunctions.isDarkMode(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSplit = constraints.maxWidth >= 900;

          final mapStack = Stack(
            children: [
              // Google Map
              Obx(
                () => GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: controller.currentPosition.value ??
                        const LatLng(5.6037, -0.1870),
                    zoom: 15,
                  ),
                  markers: controller.markers,
                  polylines: controller.polylines,
                  onMapCreated: controller.onMapCreated,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  padding: EdgeInsets.only(bottom: isSplit ? 24 : 200),
                ),
              ),

              // Header with Online/Offline Toggle
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: (dark ? const Color(0xFF0F1E33) : Colors.white)
                        .withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dark
                          ? const Color(0xFF1E3A5F)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Status Indicator
                      Obx(
                        () => Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: (controller.isOnline.value
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444))
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (controller.isOnline.value
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444))
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            controller.isOnline.value
                                ? Iconsax.truck_fast
                                : Iconsax.truck,
                            color: controller.isOnline.value
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Obx(
                              () => Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: controller.isOnline.value
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    controller.isOnline.value
                                        ? 'ONLINE • DISPATCH READY'
                                        : 'OFFLINE • STANDBY',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: dark
                                          ? Colors.white
                                          : AvailColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Obx(
                              () => Text(
                                controller.isOnline.value
                                    ? 'Receiving live freight manifests nearby'
                                    : 'Switch online to accept cargo jobs',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: dark
                                      ? Colors.grey.shade400
                                      : AvailColors.darkgrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Toggle Switch
                      Obx(
                        () => Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: controller.isOnline.value,
                            onChanged: (_) => controller.toggleOnlineStatus(),
                            thumbColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFF10B981);
                              }
                              return const Color(0xFFEF4444);
                            }),
                            trackColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFF10B981)
                                    .withValues(alpha: 0.35);
                              }
                              return const Color(0xFFEF4444)
                                  .withValues(alpha: 0.35);
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Current Location Button
              Positioned(
                right: 20,
                bottom: 260,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor:
                      dark ? const Color(0xFF132238) : Colors.white,
                  onPressed: () {
                    if (controller.currentPosition.value != null) {
                      controller.mapController?.animateCamera(
                        CameraUpdate.newLatLng(
                            controller.currentPosition.value!),
                      );
                    }
                  },
                  child:
                      const Icon(Iconsax.location, color: AvailColors.primary),
                ),
              ),
            ],
          );

          final bookingsListBody = Obx(() {
            if (!controller.isOnline.value) {
              return _buildOfflineView(context, dark);
            }
            if (controller.availableBookings.isEmpty) {
              return _buildEmptyBookingsView(context, dark);
            }
            return Column(
              children: controller.availableBookings
                  .map((booking) =>
                      _buildBookingCard(context, booking, controller, dark))
                  .toList(),
            );
          });

          if (isSplit) {
            return Row(
              children: [
                Expanded(child: mapStack),
                Container(
                  width: 400,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: dark ? AvailColors.dark : const Color(0xFFF8FAFC),
                    border: Border(
                      left: BorderSide(
                        color: dark
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const AvailSectionHeading(
                          title: 'Available Freight Jobs',
                          showActionButton: false,
                        ),
                        const SizedBox(height: 15),
                        bookingsListBody,
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              mapStack,
              DraggableScrollableSheet(
                initialChildSize: 0.34,
                minChildSize: 0.25,
                maxChildSize: 0.9,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: dark ? AvailColors.dark : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              const AvailSectionHeading(
                                title: 'Available Freight Jobs',
                                showActionButton: false,
                              ),
                              const SizedBox(height: 14),
                              bookingsListBody,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOfflineView(BuildContext context, bool dark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.radar, size: 46, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            Text(
              'You are currently Offline',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : AvailColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Toggle the switch above to receive live freight dispatches nearby',
              style: TextStyle(
                fontSize: 12,
                color: dark ? Colors.grey.shade400 : AvailColors.darkgrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBookingsView(BuildContext context, bool dark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            const CircularProgressIndicator(
              color: AvailColors.primary,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Scanning for freight dispatches in your corridor...',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.grey.shade400 : AvailColors.darkgrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    BookingModel booking,
    DriverDashboardController controller,
    bool dark,
  ) {
    return GestureDetector(
      onTap: () => controller.drawRouteForBooking(booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF132238) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: dark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.22 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AvailColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AvailColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.truck_fast,
                        size: 13,
                        color: AvailColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        booking.truckType.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AvailColors.primary,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  LocalizationController.instance
                      .getFormattedPrice(booking.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AvailColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (booking.containerSize.isNotEmpty &&
                booking.containerSize != 'None')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Iconsax.box,
                        size: 15, color: AvailColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${booking.cargoType} • Container: ${booking.containerSize}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: dark ? Colors.white : AvailColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

            if (booking.loadDescription.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  booking.loadDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: dark
                        ? Colors.grey.shade400
                        : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Route Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF0C1829)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.location5,
                          color: Color(0xFF10B981), size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          booking.pickupAddress,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color:
                                dark ? Colors.white : AvailColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Iconsax.flag5,
                          color: Color(0xFFEF4444), size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          booking.dropoffAddress,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color:
                                dark ? Colors.white : AvailColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Freight Metrics Row
            Row(
              children: [
                const Icon(Iconsax.weight, size: 15, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  '${booking.weight} Tons',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Iconsax.routing, size: 15, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  '${booking.distance.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => controller.acceptBooking(booking),
                icon: const Icon(Iconsax.tick_circle,
                    size: 18, color: Colors.white),
                label: const Text(
                  'ACCEPT FREIGHT DISPATCH',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AvailColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
