import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:truck_booking/features/personalization/controllers/user_controller.dart';
import 'package:truck_booking/features/personalization/controllers/localization_controller.dart';
import 'package:truck_booking/features/shop/controllers/customer/customer_home_controller.dart';
import 'package:truck_booking/features/shop/screens/customer_home/place_search_screen.dart';
import 'package:truck_booking/features/shop/screens/customer_home/map_selection_screen.dart';
import 'package:truck_booking/utils/constants/colors.dart';
import 'package:truck_booking/utils/constants/sizes.dart';
import 'package:truck_booking/utils/helpers/helper_functions.dart';
import 'package:truck_booking/commons/widgets/date_time_picker/custom_date_time_picker.dart';
import 'package:truck_booking/commons/widgets/loader/loaders.dart';
import 'package:truck_booking/features/shop/models/suggested_pickup_spot_model.dart';

class JobForm extends StatelessWidget {
  const JobForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CustomerHomeController.instance;
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return Form(
      key: controller.bookingFormKey,
      child: Obx(() {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. High-Tech 4-Stage Stepper Header (Route -> Cargo -> Schedule -> Review)
            _buildStepperHeader(controller, darkMode),
            const SizedBox(height: 18),

            // Dynamic Active Stage: Wraps exact content height with zero excessive bottom whitespace
            _buildActiveStage(context, controller, darkMode),
          ],
        );
      }),
    );
  }

  Widget _buildActiveStage(BuildContext context, CustomerHomeController controller, bool darkMode) {
    switch (controller.bookingCurrentStep.value) {
      case 0:
        return _buildStage0Route(context, controller, darkMode);
      case 1:
        return _buildStage1Cargo(context, controller, darkMode);
      case 2:
        return _buildStage2Schedule(context, controller, darkMode);
      case 3:
        return _buildStage3Review(context, controller, darkMode);
      default:
        return _buildStage0Route(context, controller, darkMode);
    }
  }

  // ================= 0. MODERN 4-STAGE STEPPER HEADER =================
  Widget _buildStepperHeader(CustomerHomeController controller, bool darkMode) {
    final currentStep = controller.bookingCurrentStep.value;
    final steps = [
      {'title': 'Route', 'subtitle': 'Point A & B', 'icon': Iconsax.route_square},
      {'title': 'Cargo', 'subtitle': 'Vehicle & specs', 'icon': Iconsax.truck_fast},
      {'title': 'Schedule', 'subtitle': 'Time & care', 'icon': Iconsax.calendar_tick},
      {'title': 'Review', 'subtitle': 'Contacts & fare', 'icon': Iconsax.receipt_21},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: darkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: darkMode ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                // Connecting line
                final stepIndex = index ~/ 2;
                final isCompleted = currentStep > stepIndex;
                return Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : (darkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }

              // Step Node
              final stepIndex = index ~/ 2;
              final isCurrent = currentStep == stepIndex;
              final isCompleted = currentStep > stepIndex;
              final stepData = steps[stepIndex];

              return InkWell(
                onTap: () => controller.jumpToBookingStep(stepIndex),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? AvailColors.primary
                              : (isCompleted
                                  ? const Color(0xFF10B981)
                                  : (darkMode
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9))),
                          border: Border.all(
                            color: isCurrent
                                ? AvailColors.primary
                                : (isCompleted
                                    ? const Color(0xFF10B981)
                                    : (darkMode
                                        ? const Color(0xFF475569)
                                        : const Color(0xFFCBD5E1))),
                            width: isCurrent ? 2 : 1.2,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AvailColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : Icon(
                                  stepData['icon'] as IconData,
                                  size: 15,
                                  color: isCurrent
                                      ? Colors.white
                                      : (darkMode ? Colors.grey[400] : Colors.grey[600]),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stepData['title'] as String,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                          color: isCurrent
                              ? (darkMode ? Colors.white : const Color(0xFF0F172A))
                              : (isCompleted
                                  ? const Color(0xFF10B981)
                                  : (darkMode ? Colors.grey[500] : Colors.grey[500])),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ================= STAGE 0: ROUTE & ROAD CONFIRMATION =================
  Widget _buildStage0Route(BuildContext context, CustomerHomeController controller, bool darkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '1. LOGISTICS ROUTE & ROAD CONFIRMATION',
          subtitle: 'Define pickup, intermediate stops & delivery destination with live road snapping',
          icon: Iconsax.route_square,
        ),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildRouteSection(context, controller, darkMode),
        const SizedBox(height: 20),

        // Continue to Cargo Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => controller.nextBookingStep(),
            icon: const Icon(Iconsax.arrow_right_3, color: Colors.white, size: 18),
            label: const Text(
              'CONTINUE TO CARGO & VEHICLE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AvailColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  // ================= STAGE 1: CARGO & VEHICLE SPECIFICATIONS =================
  Widget _buildStage1Cargo(BuildContext context, CustomerHomeController controller, bool darkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '2. VEHICLE & CARGO SPECIFICATIONS',
          subtitle: 'Select vehicle type and compatible freight cargo',
          icon: Iconsax.truck_fast,
        ),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildTruckTypeSelector(controller, darkMode),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildCargoTypeSelector(controller, darkMode),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildTripTypeSelector(controller, darkMode),
        const SizedBox(height: AvailSizes.spaceBtwSections),

        const SectionHeader(
          title: 'CARGO DIMENSIONS & CONTAINER CONTROLS',
          subtitle: 'Specify weight, ISO container size, and tare snapping',
          icon: Iconsax.weight,
        ),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildCargoDetails(context, controller, darkMode),
        const SizedBox(height: AvailSizes.spaceBtwSections),

        // Itemized inventory (only for loaded general, container, or refrigerated cargo)
        Obx(() {
          final cargo = controller.selectedCargoType.value;
          final status = controller.selectedContainerStatus.value;
          final bool isEmptyContainer = cargo == 'Container' && status == 'Empty';

          if (cargo == 'Bulk / Loose Material' || cargo == 'Heavy Machinery' || isEmptyContainer) {
            return const SizedBox();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'ITEMIZED MANIFEST INVENTORY',
                subtitle: 'List specific cargo items for accurate tracking',
                icon: Iconsax.task_square,
              ),
              const SizedBox(height: AvailSizes.spaceBtwItems),
              _buildInventorySection(controller, darkMode),
              const SizedBox(height: AvailSizes.spaceBtwSections),
            ],
          );
        }),

        // Stage 1 Navigation Buttons
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => controller.previousBookingStep(),
                icon: const Icon(Iconsax.arrow_left_2, size: 16),
                label: const Text('Route', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                onPressed: () => controller.nextBookingStep(),
                icon: const Icon(Iconsax.arrow_right_3, size: 18, color: Colors.white),
                label: const Text(
                  'CONTINUE TO SCHEDULE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AvailColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================= STAGE 2: DISPATCH PLANNING, SCHEDULE & HANDLING =================
  Widget _buildStage2Schedule(BuildContext context, CustomerHomeController controller, bool darkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '3. DISPATCH PLANNING & VALUATION',
          subtitle: 'Set schedule and declared cargo value',
          icon: Iconsax.calendar_tick,
        ),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildDispatchPlanning(context, controller, darkMode),
        const SizedBox(height: AvailSizes.spaceBtwSections),

        const SectionHeader(
          title: 'HANDLING & SPECIAL SURCHARGES',
          subtitle: 'Configure fragile, hazardous cargo care & ground labor assistance',
          icon: Iconsax.shield_tick,
        ),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildLogisticsOptions(controller, darkMode),
        const SizedBox(height: AvailSizes.spaceBtwSections),

        const SectionHeader(
          title: 'FREIGHT DOCUMENTATION',
          subtitle: 'Attach waybills, invoices, or cargo photos',
          icon: Iconsax.document_text,
        ),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildDocumentSection(context, controller, darkMode),
        const SizedBox(height: 20),

        // Stage 2 Navigation Buttons
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => controller.previousBookingStep(),
                icon: const Icon(Iconsax.arrow_left_2, size: 16),
                label: const Text('Cargo', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                onPressed: () => controller.nextBookingStep(),
                icon: const Icon(Iconsax.arrow_right_3, size: 18, color: Colors.white),
                label: const Text(
                  'CONTINUE TO CONTACTS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AvailColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================= STAGE 3: LOGISTICS CONTACTS & FINAL REVIEW =================
  Widget _buildStage3Review(BuildContext context, CustomerHomeController controller, bool darkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '4. LOGISTICS CONTACTS',
          subtitle: 'Provide sender & receiver details for dispatch coordination',
          icon: Iconsax.user_square,
        ),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildContactSection(controller, darkMode),
        const SizedBox(height: AvailSizes.spaceBtwSections),

        const SectionHeader(
          title: 'ITEMIZED FARE BREAKDOWN',
          subtitle: 'Real-time fare summary from Logistics Pricing Engine',
          icon: Iconsax.receipt_21,
        ),
        const SizedBox(height: AvailSizes.spaceBtwItems),
        _buildItemizedFareCard(controller, darkMode),
        const SizedBox(height: 24),

        // Stage 3 Navigation Buttons
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => controller.previousBookingStep(),
                icon: const Icon(Iconsax.arrow_left_2, size: 16),
                label: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (controller.validateBookingStep(3)) {
                    _showManifestReviewSheet(context, controller, darkMode);
                  }
                },
                icon: const Icon(Iconsax.document_text, color: Colors.white, size: 18),
                label: Obx(() => Text(
                  controller.editingBookingId.value.isNotEmpty
                      ? 'REVIEW & UPDATE'
                      : 'REVIEW & DISPATCH',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AvailColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================= 1. RECONSTRUCTED LOGISTICS ROUTE SECTION =================
  Future<void> _searchPickup(CustomerHomeController controller) async {
    final initialVal = controller.pickupAddressController.text.isNotEmpty &&
            controller.pickupAddressController.text != 'Current Location' &&
            controller.pickupAddressController.text != 'My Current Location'
        ? controller.pickupAddressController.text
        : (controller.pickupName.value != 'Select pickup point' &&
                controller.pickupName.value != 'Current Location' &&
                controller.pickupName.value != 'My Current Location'
            ? controller.pickupName.value
            : '');

    final result = await Get.to(
      () => PlaceSearchScreen(initialValue: initialVal),
      routeName: '/place-search',
    );
    if (result != null) {
      if (result == 'SELECT_ON_MAP') {
        final confirmResult = await Get.to(
          () => MapSelectionScreen(
            locationType: 'pickup',
            initialLocation: controller.pickupLocation.value,
            initialAddress: controller.pickupName.value,
          ),
          routeName: '/map-selection',
        );
        if (confirmResult != null && confirmResult is Map) {
          final cLat = (confirmResult['lat'] as num?)?.toDouble();
          final cLng = (confirmResult['lng'] as num?)?.toDouble();
          final cAddr = (confirmResult['description'] as String?) ?? '';
          if (cLat != null && cLng != null) {
            controller.setPickup(LatLng(cLat, cLng), cAddr.isNotEmpty ? cAddr : controller.pickupName.value);
          }
        }
      } else if (result is Map) {
        String addressText = (result['description'] ?? result['address'] ?? result['title'] ?? result['formatted_address'] ?? result['name'] ?? '').toString();
        final double? lat = (result['lat'] as num?)?.toDouble();
        final double? lng = (result['lng'] as num?)?.toDouble();
        if (addressText.isNotEmpty && lat != null && lng != null) {
          if (addressText.toLowerCase().contains('current location')) {
            final resolved = await controller.reverseGeocode(LatLng(lat, lng));
            if (resolved.isNotEmpty && !resolved.toLowerCase().contains('current location')) {
              addressText = resolved;
            }
          }
          // Uber style: Open MapSelectionScreen pre-centered on this search result for pinpoint curb confirmation & access spots
          controller.pinnedLocation.value = LatLng(lat, lng);
          controller.pinnedAddress.value = addressText;
          final confirmResult = await Get.to(
            () => MapSelectionScreen(
              locationType: 'pickup',
              initialLocation: LatLng(lat, lng),
              initialAddress: addressText,
            ),
            routeName: '/map-selection',
          );
          if (confirmResult != null && confirmResult is Map) {
            final cLat = (confirmResult['lat'] as num?)?.toDouble() ?? lat;
            final cLng = (confirmResult['lng'] as num?)?.toDouble() ?? lng;
            final cAddr = (confirmResult['description'] as String?) ?? addressText;
            controller.setPickup(LatLng(cLat, cLng), cAddr);
          } else {
            controller.setPickup(LatLng(lat, lng), addressText);
          }
        } else if (addressText.isNotEmpty) {
          final coords = await controller.geocodeAddressToLatLng(addressText);
          controller.setPickup(coords ?? const LatLng(5.6037, -0.1870), addressText);
        }
      }
    }
  }

  Future<void> _searchDestination(CustomerHomeController controller) async {
    final initialVal = controller.dropoffAddressController.text.isNotEmpty
        ? controller.dropoffAddressController.text
        : (controller.destinationName.value != 'Where to?' && controller.destinationName.value != 'Select destination / dropoff'
            ? controller.destinationName.value
            : '');

    final result = await Get.to(
      () => PlaceSearchScreen(initialValue: initialVal),
      routeName: '/place-search',
    );
    if (result != null) {
      if (result == 'SELECT_ON_MAP') {
        final confirmResult = await Get.to(
          () => MapSelectionScreen(
            locationType: 'destination',
            initialLocation: controller.destinationLocation.value,
            initialAddress: controller.destinationName.value,
          ),
          routeName: '/map-selection',
        );
        if (confirmResult != null && confirmResult is Map) {
          final cLat = (confirmResult['lat'] as num?)?.toDouble();
          final cLng = (confirmResult['lng'] as num?)?.toDouble();
          final cAddr = (confirmResult['description'] as String?) ?? '';
          if (cLat != null && cLng != null) {
            controller.setDestination(LatLng(cLat, cLng), cAddr.isNotEmpty ? cAddr : controller.destinationName.value);
          }
        }
      } else if (result is Map) {
        String addressText = (result['description'] ?? result['address'] ?? result['title'] ?? result['formatted_address'] ?? result['name'] ?? '').toString();
        final double? lat = (result['lat'] as num?)?.toDouble();
        final double? lng = (result['lng'] as num?)?.toDouble();
        if (addressText.isNotEmpty && lat != null && lng != null) {
          if (addressText.toLowerCase().contains('current location')) {
            final resolved = await controller.reverseGeocode(LatLng(lat, lng));
            if (resolved.isNotEmpty && !resolved.toLowerCase().contains('current location')) {
              addressText = resolved;
            }
          }
          // Direct destination assignment: cleanly store the exact searched name and coordinates
          controller.setDestination(LatLng(lat, lng), addressText);
        } else if (addressText.isNotEmpty) {
          final coords = await controller.geocodeAddressToLatLng(addressText);
          controller.setDestination(coords ?? const LatLng(5.6037, -0.1870), addressText);
        }
      }
    }
  }

  Future<void> _searchStop(CustomerHomeController controller, int idx, String stopAddress, double? lat, double? lng) async {
    final result = await Get.to(
      () => PlaceSearchScreen(initialValue: stopAddress),
      routeName: '/place-search',
    );
    if (result != null) {
      if (result == 'SELECT_ON_MAP') {
        await Get.to(
          () => MapSelectionScreen(locationType: 'stop', stopIndex: idx),
          routeName: '/map-selection',
        );
      } else if (result is Map) {
        String addressText = (result['description'] ?? result['address'] ?? result['title'] ?? result['formatted_address'] ?? result['name'] ?? '').toString();
        final double? sLat = (result['lat'] as num?)?.toDouble() ?? lat;
        final double? sLng = (result['lng'] as num?)?.toDouble() ?? lng;
        if (addressText.isNotEmpty) {
          if (addressText.toLowerCase().contains('current location') && sLat != null && sLng != null) {
            final resolved = await controller.reverseGeocode(LatLng(sLat, sLng));
            if (resolved.isNotEmpty && !resolved.toLowerCase().contains('current location')) {
              addressText = resolved;
            }
          }
          controller.additionalStops[idx] = {'address': addressText, 'lat': sLat ?? 0.0, 'lng': sLng ?? 0.0};
          controller.drawRoute();
        }
      }
    }
  }

  Future<void> _addStop(CustomerHomeController controller) async {
    final result = await Get.to(
      () => const PlaceSearchScreen(),
      routeName: '/place-search',
    );
    if (result != null) {
      if (result == 'SELECT_ON_MAP') {
        await Get.to(
          () => const MapSelectionScreen(locationType: 'stop'),
          routeName: '/map-selection',
        );
      } else if (result is Map) {
        String addressText = (result['description'] ?? result['address'] ?? result['title'] ?? result['formatted_address'] ?? result['name'] ?? '').toString();
        final double? lat = (result['lat'] as num?)?.toDouble();
        final double? lng = (result['lng'] as num?)?.toDouble();
        if (addressText.toLowerCase().contains('current location') && lat != null && lng != null) {
          final resolved = await controller.reverseGeocode(LatLng(lat, lng));
          if (resolved.isNotEmpty && !resolved.toLowerCase().contains('current location')) {
            addressText = resolved;
          }
        }
        final String finalAddress = addressText.isNotEmpty
            ? addressText
            : (lat != null && lng != null ? 'Stop: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}' : 'New Stop');
        controller.additionalStops.add({
          'address': finalAddress,
          'lat': lat ?? 0.0,
          'lng': lng ?? 0.0,
        });
        controller.drawRoute();
      }
    }
  }

  Widget _buildRouteSection(BuildContext context, CustomerHomeController controller, bool darkMode) {
    final cardColor = darkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = darkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final inputBg = darkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = darkMode ? Colors.white : const Color(0xFF0F172A);
    final hintColor = darkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: darkMode ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ORIGIN (Point A)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Point A Squircle Badge (26x26)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(7.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Reconstructed Point A Interactive Container (Tap opens Search Location)
              Expanded(
                child: InkWell(
                  onTap: () => _searchPickup(controller),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: darkMode ? 0.2 : 0.03),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Accent Indicator Pill
                        Container(
                          width: 3.5,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Micro Accent Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: darkMode ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PICKUP',
                            style: TextStyle(
                              fontSize: 8.5,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 22, color: borderColor),
                        const SizedBox(width: 8),

                        // Reactive Pickup Location Display
                        Expanded(
                          child: Obx(() {
                            final name = controller.pickupName.value.trim();
                            final ctrlText = controller.pickupAddressController.text.trim();
                            final resolved = (name.isNotEmpty &&
                                    name != 'Select pickup point' &&
                                    name != 'Current Location' &&
                                    name != 'My Current Location')
                                ? name
                                : (ctrlText.isNotEmpty &&
                                        ctrlText != 'Current Location' &&
                                        ctrlText != 'My Current Location'
                                    ? ctrlText
                                    : '');
                            final hasLocation = resolved.isNotEmpty;

                            return Text(
                              hasLocation ? resolved : 'Search pickup location...',
                              style: TextStyle(
                                color: hasLocation ? textColor : hintColor,
                                fontSize: 13,
                                fontWeight: hasLocation ? FontWeight.w700 : FontWeight.w500,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          }),
                        ),

                        const SizedBox(width: 4),

                        // Quick Map Picker Action
                        Tooltip(
                          message: 'Pin on Map',
                          child: InkWell(
                            onTap: () async {
                              final confirmResult = await Get.to(
                                () => MapSelectionScreen(
                                  locationType: 'pickup',
                                  initialLocation: controller.pickupLocation.value,
                                  initialAddress: controller.pickupName.value,
                                ),
                                routeName: '/map-selection',
                              );
                              if (confirmResult != null && confirmResult is Map) {
                                final cLat = (confirmResult['lat'] as num?)?.toDouble();
                                final cLng = (confirmResult['lng'] as num?)?.toDouble();
                                final cAddr = (confirmResult['description'] as String?) ?? '';
                                if (cLat != null && cLng != null) {
                                  controller.setPickup(LatLng(cLat, cLng), cAddr.isNotEmpty ? cAddr : controller.pickupName.value);
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Iconsax.map, size: 18, color: Color(0xFF10B981)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Swap Pickup & Destination Button
              Tooltip(
                message: 'Swap pickup & destination',
                child: InkWell(
                  onTap: () => controller.swapPickupAndDestination(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: darkMode ? const Color(0xFF334155) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.swap_vert_rounded, size: 16, color: AvailColors.primary),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Uber-Style Suggested Pickup Access Spots
          _buildSuggestedPickupPills(controller, darkMode),

          // 2. TIMELINE ROUTE CONNECTOR & INTERMEDIATE STOPS (Strictly in between A and B!)
          Obx(() {
            final stops = controller.additionalStops;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Directional conduit from Point A downwards
                _buildRouteConnector(
                  startColor: const Color(0xFF10B981),
                  endColor: stops.isNotEmpty ? const Color(0xFFF59E0B) : AvailColors.primary,
                  darkMode: darkMode,
                  height: 18,
                ),

                // Reorderable list of intermediate stops
                if (stops.isNotEmpty)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: stops.length,
                    onReorder: (oldIdx, newIdx) => controller.reorderStop(oldIdx, newIdx),
                    itemBuilder: (context, idx) {
                      final stop = stops[idx];
                      final String stopAddress = (stop['address'] ?? stop['description'] ?? stop['title'] ?? stop['name'] ?? '').toString().trim();
                      final double? lat = (stop['lat'] as num?)?.toDouble();
                      final double? lng = (stop['lng'] as num?)?.toDouble();

                      return Container(
                        key: ValueKey('stop_row_${idx}_${stopAddress.hashCode}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Stop Number Squircle (26x26)
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(7.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Stop Details Container (Tap opens Search Location)
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _searchStop(controller, idx, stopAddress, lat, lng),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      constraints: const BoxConstraints(minHeight: 52),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: inputBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: borderColor, width: 1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: darkMode ? 0.2 : 0.03),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Left Accent Indicator Pill
                                          Container(
                                            width: 3.5,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Micro Accent Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withValues(alpha: darkMode ? 0.25 : 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'STOP ${idx + 1}',
                                              style: const TextStyle(
                                                fontSize: 8.5,
                                                color: Color(0xFFB45309),
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(width: 1, height: 22, color: borderColor),
                                          const SizedBox(width: 8),

                                          // Stop Address Display
                                          Expanded(
                                            child: Text(
                                              stopAddress.isNotEmpty ? stopAddress : 'Search stop location...',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: stopAddress.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
                                                color: stopAddress.isNotEmpty ? textColor : hintColor,
                                                height: 1.25,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                          const SizedBox(width: 4),

                                          // Map Pin Action for this stop
                                          Tooltip(
                                            message: 'Pin on Map',
                                            child: InkWell(
                                              onTap: () async {
                                                await Get.to(
                                                  () => MapSelectionScreen(locationType: 'stop', stopIndex: idx),
                                                  routeName: '/map-selection',
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(6),
                                              child: const Padding(
                                                padding: EdgeInsets.all(5),
                                                child: Icon(Iconsax.map, size: 17, color: Color(0xFFF59E0B)),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 2),

                                          // Delete Stop
                                          Tooltip(
                                            message: 'Remove Stop',
                                            child: InkWell(
                                              onTap: () => controller.removeStop(idx),
                                              borderRadius: BorderRadius.circular(6),
                                              child: const Padding(
                                                padding: EdgeInsets.all(5),
                                                child: Icon(Iconsax.close_circle, size: 17, color: Colors.red),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Drag Handle to Reorder Stops
                                ReorderableDragStartListener(
                                  index: idx,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: darkMode ? const Color(0xFF334155) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.drag_indicator_rounded, size: 16, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Downward directional connector between consecutive intermediate stops
                            if (idx < stops.length - 1)
                              _buildRouteConnector(
                                startColor: const Color(0xFFF59E0B),
                                endColor: const Color(0xFFF59E0B),
                                darkMode: darkMode,
                                height: 16,
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                // Directional connector from last stop to Add Stop
                _buildRouteConnector(
                  startColor: stops.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  endColor: AvailColors.primary,
                  darkMode: darkMode,
                  height: 16,
                ),

                // Add Stop Action Row (In Between Stops and Point B)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Vertical conduit track through Add Stop level
                    SizedBox(
                      width: 26,
                      height: 30,
                      child: Center(
                        child: Container(
                          width: 2,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (stops.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.65),
                                const Color(0xFFEF4444).withValues(alpha: 0.65),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Add Stop Pill Button (Tap opens Search Location)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _addStop(controller),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AvailColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AvailColors.primary.withValues(alpha: 0.35)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Iconsax.add_circle, size: 14, color: AvailColors.primary),
                                      SizedBox(width: 5),
                                      Text(
                                        'Add Stop',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AvailColors.primary,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Quick Place Search for Adding Stop
                              Tooltip(
                                message: 'Search Stop by Name',
                                child: InkWell(
                                  onTap: () => _addStop(controller),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: darkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Icon(Iconsax.search_normal_1, size: 13, color: darkMode ? Colors.white70 : Colors.grey.shade600),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Estimated Distance Chip
                          Obx(() {
                            final dist = controller.estimatedDistance.value;
                            final hasDist = dist.isNotEmpty && dist != '0 km';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: darkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Iconsax.routing, size: 12, color: hasDist ? AvailColors.primary : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    dist,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: hasDist ? textColor : hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),

                // Directional conduit from Add Stop downwards into Point B
                _buildRouteConnector(
                  startColor: AvailColors.primary,
                  endColor: const Color(0xFFEF4444),
                  darkMode: darkMode,
                  height: 18,
                ),
              ],
            );
          }),

          // 3. DESTINATION (Point B)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Point B Squircle Badge (26x26)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(7.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Reconstructed Point B Interactive Container (Tap opens Search Location)
              Expanded(
                child: InkWell(
                  onTap: () => _searchDestination(controller),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: darkMode ? 0.2 : 0.03),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Accent Indicator Pill
                        Container(
                          width: 3.5,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Micro Accent Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: darkMode ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DROPOFF',
                            style: TextStyle(
                              fontSize: 8.5,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 22, color: borderColor),
                        const SizedBox(width: 8),

                        // Reactive Destination Location Display
                        Expanded(
                          child: Obx(() {
                            final name = controller.destinationName.value.trim();
                            final ctrlText = controller.dropoffAddressController.text.trim();
                            final resolved = (name.isNotEmpty && name != 'Where to?' && name != 'Select destination / dropoff')
                                ? name
                                : (ctrlText.isNotEmpty ? ctrlText : '');
                            final hasLocation = resolved.isNotEmpty;

                            return Text(
                              hasLocation ? resolved : 'Search dropoff destination...',
                              style: TextStyle(
                                color: hasLocation ? textColor : hintColor,
                                fontSize: 13,
                                fontWeight: hasLocation ? FontWeight.w700 : FontWeight.w500,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          }),
                        ),

                        const SizedBox(width: 4),

                        // Quick Map Picker Action
                        Tooltip(
                          message: 'Pin on Map',
                          child: InkWell(
                            onTap: () async {
                              final confirmResult = await Get.to(
                                () => MapSelectionScreen(
                                  locationType: 'destination',
                                  initialLocation: controller.destinationLocation.value,
                                  initialAddress: controller.destinationName.value,
                                ),
                                routeName: '/map-selection',
                              );
                              if (confirmResult != null && confirmResult is Map) {
                                final cLat = (confirmResult['lat'] as num?)?.toDouble();
                                final cLng = (confirmResult['lng'] as num?)?.toDouble();
                                final cAddr = (confirmResult['description'] as String?) ?? '';
                                if (cLat != null && cLng != null) {
                                  controller.setDestination(LatLng(cLat, cLng), cAddr.isNotEmpty ? cAddr : controller.destinationName.value);
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Iconsax.map, size: 18, color: Color(0xFFEF4444)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 36), // Balances with the swap button width on Point A row
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedPickupPills(CustomerHomeController controller, bool darkMode) {
    return Obx(() {
      final spots = controller.suggestedPickupSpots;
      if (spots.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: darkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: darkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Iconsax.location_tick, size: 13, color: Color(0xFF10B981)),
                const SizedBox(width: 5),
                Text(
                  'RECOMMENDED TRUCK CURB / GATE ACCESS',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: darkMode ? const Color(0xFF10B981) : const Color(0xFF047857),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: spots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final spot = spots[index];
                  final isSelected = controller.selectedSuggestedSpot.value?.id == spot.id;

                  return InkWell(
                    onTap: () => controller.applySuggestedPickupSpotToForm(spot),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF10B981)
                            : (darkMode ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : (darkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : const Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            spot.title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (darkMode ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '• ${spot.distanceMeters.toStringAsFixed(0)}m',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white70
                                  : (darkMode ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Sleek downward route timeline connector with directional indicator
  Widget _buildRouteConnector({
    required Color startColor,
    required Color endColor,
    required bool darkMode,
    bool showArrow = true,
    double height = 22,
  }) {
    final centerColor = Color.lerp(startColor, endColor, 0.5) ?? startColor;
    final chipBg = darkMode ? const Color(0xFF0F172A) : Colors.white;

    return SizedBox(
      width: 26, // Exactly aligns with the 26px squircle node badges
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Continuous vertical route conduit
          Container(
            width: 2,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  startColor.withValues(alpha: 0.65),
                  endColor.withValues(alpha: 0.65),
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (showArrow)
            // Polished miniature downward route direction arrow badge
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: chipBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: centerColor.withValues(alpha: 0.75),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: centerColor.withValues(alpha: 0.22),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 11,
                  color: centerColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================= 2. VEHICLE PREFERENCE SELECTOR =================
  Widget _buildTruckTypeSelector(CustomerHomeController controller, bool darkMode) {
    final trucks = [
      {
        'name': 'Pickup / Mini Truck',
        'desc': 'Light cargo, local delivery & last-mile',
        'capacity': 'Max 2T',
        'icon': Iconsax.truck_fast,
      },
      {
        'name': 'Tipper / Dumper',
        'desc': 'Loose bulk, aggregate, sand & gravel',
        'capacity': 'Max 20T',
        'icon': Iconsax.truck_tick,
      },
      {
        'name': 'Flatbed / Platform Truck',
        'desc': 'Containers, pallets & heavy machinery',
        'capacity': 'Max 30T',
        'icon': Iconsax.truck,
      },
      {
        'name': 'Refrigerated Truck',
        'desc': 'Cold-chain, perishable & pharma freight',
        'capacity': 'Max 15T',
        'icon': Icons.ac_unit,
      },
      {
        'name': 'Heavy Duty / 30-Ton',
        'desc': 'Outsized machinery, 40ft containers & rigging',
        'capacity': 'Max 45T',
        'icon': Iconsax.truck_remove,
      },
    ];

    return Obx(() {
      final activeTrucks = controller.activeTruckTypes;
      final visibleTrucks = activeTrucks.isNotEmpty
          ? trucks.where((t) => activeTrucks.contains(t['name'])).toList()
          : trucks;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SELECT VEHICLE TYPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 8),
          ...visibleTrucks.map((truck) {
            final isSelected = controller.selectedTruckType.value == truck['name'];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.updateTruckType(truck['name'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AvailColors.primary.withValues(alpha: 0.12)
                      : (darkMode ? const Color(0xFF1E293B) : Colors.white),
                  border: Border.all(
                    color: isSelected ? AvailColors.primary : (darkMode ? const Color(0xFF334155) : Colors.grey.shade200),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AvailColors.primary : (darkMode ? const Color(0xFF334155) : Colors.grey.shade200),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        truck['icon'] as IconData,
                        color: isSelected ? Colors.white : (darkMode ? Colors.white70 : Colors.black54),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                truck['name'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 13,
                                  color: darkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AvailColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  truck['capacity'] as String,
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AvailColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            truck['desc'] as String, 
                            style: TextStyle(
                              fontSize: 10, 
                              color: darkMode ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    });
  }

  // ================= CARGO TYPE SELECTOR (FILTERED DYNAMICALLY BY TRUCK COMPATIBILITY) =================
  Widget _buildCargoTypeSelector(CustomerHomeController controller, bool darkMode) {
    final allCargoTypes = [
      {'name': 'Container', 'desc': '20ft/40ft Shipping', 'icon': Iconsax.box_1},
      {'name': 'General Freight', 'desc': 'Pallets & Goods', 'icon': Iconsax.archive_book},
      {'name': 'Bulk / Loose Material', 'desc': 'Raw / Loose Sand & Grain', 'icon': Iconsax.truck_tick},
      {'name': 'Heavy Machinery', 'desc': 'Machinery & Equipment', 'icon': Iconsax.weight},
      {'name': 'Refrigerated Goods', 'desc': 'Cold Chain Perishables', 'icon': Icons.ac_unit},
    ];

    return Obx(() {
      final allowedTypes = controller.getActiveCargoTypesForTruck(controller.selectedTruckType.value);
      final compatibleList = allCargoTypes.where((c) => allowedTypes.contains(c['name'])).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('COMPATIBLE CARGO LOAD TYPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
              Text(
                'Allowed for ${controller.selectedTruckType.value.split('/')[0]}',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AvailColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: compatibleList.map((type) {
              final isSelected = controller.selectedCargoType.value == type['name'];
              final String typeName = type['name'] as String;

              return ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        size: 18,
                        color: isSelected ? Colors.white : AvailColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        typeName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (darkMode ? Colors.white : Colors.black87),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                selected: isSelected,
                selectedColor: AvailColors.primary,
                backgroundColor: darkMode ? const Color(0xFF1E293B) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AvailColors.primary : (darkMode ? const Color(0xFF334155) : Colors.grey.shade300),
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    controller.updateCargoType(typeName);
                  }
                },
              );
            }).toList(),
          ),
        ],
      );
    });
  }

  // ================= TRIP TYPE & ROUND TRIP LEG MODE SELECTOR =================
  Widget _buildTripTypeSelector(CustomerHomeController controller, bool darkMode) {
    return Obx(() {
      final isRound = controller.tripType.value == 'round_trip';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TRIP DIRECTION & LEG DYNAMICS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.updateTripType('single'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !isRound ? AvailColors.primary : (darkMode ? const Color(0xFF1E293B) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: !isRound ? AvailColors.primary : (darkMode ? const Color(0xFF334155) : Colors.grey.shade300)),
                    ),
                    child: Center(
                      child: Text(
                        'Single Trip (1-Way)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: !isRound ? Colors.white : (darkMode ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.updateTripType('round_trip'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isRound ? AvailColors.primary : (darkMode ? const Color(0xFF1E293B) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isRound ? AvailColors.primary : (darkMode ? const Color(0xFF334155) : Colors.grey.shade300)),
                    ),
                    child: Center(
                      child: Text(
                        'Round Trip (2-Way)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isRound ? Colors.white : (darkMode ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Round Trip Leg Mode Dropdown
          if (isRound) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: darkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AvailColors.primary.withValues(alpha: 0.4)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: controller.selectedLegMode.value,
                  dropdownColor: darkMode ? const Color(0xFF1E293B) : Colors.white,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'loaded_loaded', child: Text('Loaded In - Loaded Out (Full 2-Way Payload)')),
                    DropdownMenuItem(value: 'loaded_empty', child: Text('Loaded In - Empty Return Out')),
                    DropdownMenuItem(value: 'empty_loaded', child: Text('Empty In - Loaded Return Out')),
                    DropdownMenuItem(value: 'empty_empty', child: Text('Empty In - Empty Return Out')),
                  ],
                  onChanged: (val) {
                    if (val != null) controller.updateLegMode(val);
                  },
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  // ================= 3. DISPATCH PLANNING & SCHEDULE =================
  Widget _buildDispatchPlanning(BuildContext context, CustomerHomeController controller, bool darkMode) {
    final cardColor = darkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = darkMode ? const Color(0xFF334155) : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              CustomDateTimePickerModal.show(
                context: context,
                initialDateTime: controller.scheduledDateTime.value,
                onDateTimeSelected: (dateTime) {
                  controller.scheduledDateTime.value = dateTime;
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: darkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA),
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.calendar_1, color: AvailColors.primary, size: 22),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DISPATCH SCHEDULE',
                        style: TextStyle(fontSize: 9, color: darkMode ? Colors.white60 : Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Obx(() => Text(
                        controller.scheduledDateTime.value == null
                            ? 'Immediate Dispatch (ASAP)'
                            : DateFormat('EEE, MMM dd, yyyy • HH:mm').format(controller.scheduledDateTime.value!),
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 13,
                          color: darkMode ? Colors.white : Colors.black87,
                        ),
                      )),
                    ],
                  ),
                  const Spacer(),
                  Icon(Iconsax.edit, size: 16, color: darkMode ? Colors.white60 : Colors.grey),
                ],
              ),
            ),
          ),

          Obx(() {
            final bool isEmptyContainer = controller.selectedCargoType.value == 'Container' && controller.selectedContainerStatus.value == 'Empty';
            if (isEmptyContainer) return const SizedBox();

            return Column(
              children: [
                const SizedBox(height: 14),
                TextFormField(
                  controller: controller.cargoValueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Declared Cargo Value (GHS)',
                    prefixIcon: Icon(Iconsax.wallet_money),
                    hintText: 'e.g. 150000',
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ================= 4. CARGO DETAILS & CONTAINER CONTROLS =================
  Widget _buildCargoDetails(BuildContext context, CustomerHomeController controller, bool darkMode) {
    return Column(
      children: [
        Obx(() {
          final cargo = controller.selectedCargoType.value;
          final status = controller.selectedContainerStatus.value;
          final bool isEmptyContainer = cargo == 'Container' && status == 'Empty';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ISO Container Specific Selector Controls (Size & Status)
              if (cargo == 'Container') ...[
                const Text('ISO CONTAINER SPECIFICATIONS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 8),

                // Size Selector Options: 20ft, twin_20ft, 40ft
                Row(
                  children: [
                    _buildContainerSizeOption('20ft', '1x 20ft Standard', controller, darkMode),
                    const SizedBox(width: 8),
                    _buildContainerSizeOption('twin_20ft', '2x 20ft Twin', controller, darkMode),
                    const SizedBox(width: 8),
                    _buildContainerSizeOption('40ft', '1x 40ft / 40ft HC', controller, darkMode),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Selector Options: Loaded, 1 Loaded + 1 Empty, Empty
                Row(
                  children: [
                    _buildContainerStatusOption('Loaded', 'Loaded', controller, darkMode),
                    const SizedBox(width: 8),
                    _buildContainerStatusOption('loaded_empty', '1 Loaded + 1 Empty', controller, darkMode),
                    const SizedBox(width: 8),
                    _buildContainerStatusOption('Empty', 'Empty Return', controller, darkMode),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  // Weight Input
                  if (!isEmptyContainer) ...[
                    Expanded(
                      child: TextFormField(
                        controller: controller.weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Weight (Tons)',
                          prefixIcon: Icon(Iconsax.weight),
                          hintText: 'e.g. 25',
                        ),
                        onChanged: (val) {
                          controller.loadWeight.value = double.tryParse(val) ?? 0.0;
                          final distKm = double.tryParse(controller.estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
                          controller.calculatePrice(distKm);
                        },
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Weight required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  if (cargo == 'Bulk / Loose Material') ...[
                    Expanded(
                      child: TextFormField(
                        controller: controller.materialTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Bulk Material',
                          hintText: 'e.g. Sand / Clinker',
                          prefixIcon: Icon(Iconsax.mask),
                        ),
                      ),
                    ),
                  ] else if (cargo == 'Heavy Machinery') ...[
                    Expanded(
                      child: TextFormField(
                        controller: controller.heavyEquipmentModelController,
                        decoration: const InputDecoration(
                          labelText: 'Machine / Rig Model',
                          hintText: 'e.g. CAT 320 Excavator',
                          prefixIcon: Icon(Iconsax.setting_2),
                        ),
                      ),
                    ),
                  ] else if (cargo == 'Refrigerated Goods') ...[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: ['Frozen (-18°C)', 'Chilled (2°C - 8°C)', 'Ambient (15°C - 25°C)'].contains(controller.selectedRefrigeratedTemp.value)
                            ? controller.selectedRefrigeratedTemp.value
                            : 'Chilled (2°C - 8°C)',
                        isExpanded: true,
                        items: ['Frozen (-18°C)', 'Chilled (2°C - 8°C)', 'Ambient (15°C - 25°C)']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) controller.selectedRefrigeratedTemp.value = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Temp Control',
                          prefixIcon: Icon(Icons.ac_unit),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Tare Weight Auto-Snapping Info Badge for Empty Container
              if (isEmptyContainer) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.info_circle, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ISO Tare Weight Auto-Snapped: ${controller.weightController.text} Tons (${controller.selectedContainerSize.value.toUpperCase()} Empty)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        }),

        // Container Serial Number
        Obx(() {
          if (controller.selectedCargoType.value != 'Container') return const SizedBox();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.containerNumberController,
                onChanged: (val) => controller.validateContainerNumber(val),
                decoration: const InputDecoration(
                  labelText: 'Container Serial Number (Optional)',
                  prefixIcon: Icon(Iconsax.barcode),
                  hintText: 'e.g. CGMU 234579 2',
                ),
              ),
              Obx(() {
                if (controller.isContainerNumberValid.value) return const SizedBox();

                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Iconsax.warning_2, size: 14, color: Colors.orange),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Invalid Container number. Check and revise or ignore if non-standard.',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        }),

        const SizedBox(height: 12),
        TextFormField(
          controller: controller.loadDescriptionController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Detailed Cargo Description & Handling Instructions',
            prefixIcon: Icon(Iconsax.document),
            hintText: 'e.g. 500 Bags of Rice, fragile packaging, keep upright',
          ),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Cargo description required' : null,
        ),
      ],
    );
  }

  Widget _buildContainerSizeOption(String code, String label, CustomerHomeController controller, bool darkMode) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.updateContainerSize(code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: controller.selectedContainerSize.value == code
                ? AvailColors.primary
                : (darkMode ? const Color(0xFF1E293B) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: controller.selectedContainerSize.value == code
                  ? AvailColors.primary
                  : (darkMode ? const Color(0xFF334155) : Colors.grey.shade300),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: controller.selectedContainerSize.value == code
                    ? Colors.white
                    : (darkMode ? Colors.white70 : Colors.black87),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContainerStatusOption(String code, String label, CustomerHomeController controller, bool darkMode) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.updateContainerStatus(code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: controller.selectedContainerStatus.value == code
                ? AvailColors.primary
                : (darkMode ? const Color(0xFF1E293B) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: controller.selectedContainerStatus.value == code
                  ? AvailColors.primary
                  : (darkMode ? const Color(0xFF334155) : Colors.grey.shade300),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: controller.selectedContainerStatus.value == code
                    ? Colors.white
                    : (darkMode ? Colors.white70 : Colors.black87),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // ================= 5. INVENTORY SECTION =================
  Widget _buildInventorySection(CustomerHomeController controller, bool darkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: darkMode ? const Color(0xFF334155) : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: controller.inventoryItemNameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g. Solar Inverter',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: controller.inventoryItemQuantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    hintText: 'e.g. 50',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => controller.addInventoryItem(),
                icon: const Icon(Iconsax.add_circle, color: AvailColors.primary, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() => ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.inventoryItems.length,
            itemBuilder: (context, index) {
              final item = controller.inventoryItems[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: darkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: darkMode ? const Color(0xFF334155) : Colors.transparent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item['name']} x${item['quantity']}', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 12,
                        color: darkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.trash, size: 16, color: Colors.red),
                      onPressed: () => controller.removeInventoryItem(index),
                    ),
                  ],
                ),
              );
            },
          )),
        ],
      ),
    );
  }

  // ================= 6. HANDLING & SPECIAL SURCHARGES =================
  Widget _buildLogisticsOptions(CustomerHomeController controller, bool darkMode) {
    return Column(
      children: [
        _buildOptionTile(
          title: 'Fragile / Delicate Cargo',
          subtitle: 'Special lashing, padding & vibration protection',
          icon: Iconsax.glass,
          value: controller.isFragile,
          onChanged: (val) {
            controller.isFragile.value = val;
            final distKm = double.tryParse(controller.estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
            controller.calculatePrice(distKm);
          },
          darkMode: darkMode,
        ),
        const SizedBox(height: 10),
        _buildOptionTile(
          title: 'Hazardous / Dangerous Goods Surcharge',
          subtitle: 'HAZMAT placards, safety clearance & chemical handling',
          icon: Iconsax.warning_2,
          value: controller.isHazardous,
          onChanged: (val) {
            controller.isHazardous.value = val;
            final distKm = double.tryParse(controller.estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
            controller.calculatePrice(distKm);
          },
          darkMode: darkMode,
        ),
        const SizedBox(height: 10),
        _buildOptionTile(
          title: 'Loading & Offloading Crew',
          subtitle: 'Dispatch ground labor assistance at origin & drop-off',
          icon: Iconsax.profile_2user,
          value: controller.requiresAssistance,
          onChanged: (val) {
            controller.requiresAssistance.value = val;
            final distKm = double.tryParse(controller.estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
            controller.calculatePrice(distKm);
          },
          darkMode: darkMode,
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required RxBool value,
    required Function(bool) onChanged,
    required bool darkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(color: darkMode ? const Color(0xFF334155) : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Obx(() => SwitchListTile(
        value: value.value,
        onChanged: onChanged,
        activeColor: AvailColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: value.value ? AvailColors.primary.withValues(alpha: 0.15) : (darkMode ? const Color(0xFF0F172A) : Colors.grey.shade200),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: value.value ? AvailColors.primary : (darkMode ? Colors.white54 : Colors.grey),
            size: 20,
          ),
        ),
        title: Text(
          title, 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 13,
            color: darkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle, 
          style: TextStyle(
            fontSize: 10, 
            color: darkMode ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
      )),
    );
  }

  // ================= 7. DOCUMENTATION SECTION =================
  Widget _buildDocumentSection(BuildContext context, CustomerHomeController controller, bool darkMode) {
    return Column(
      children: [
        Obx(() => ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.pickedDocuments.length,
          itemBuilder: (context, index) {
            final doc = controller.pickedDocuments[index];
            final path = (doc['path'] ?? '') as String;
            final url = (doc['url'] ?? '') as String;
            final target = url.isNotEmpty ? url : path;
            final isNetwork = target.startsWith('http');
            final isImage = doc['type'] == 'image' || target.toLowerCase().contains('.jpg') || target.toLowerCase().contains('.png') || target.toLowerCase().contains('.jpeg');

            Widget thumbnail;
            if (isImage) {
              if (isNetwork) {
                thumbnail = Image.network(target, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Iconsax.image));
              } else {
                thumbnail = Image.file(File(path), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Iconsax.image));
              }
            } else {
              thumbnail = Container(width: 48, height: 48, color: AvailColors.primary.withValues(alpha: 0.1), child: const Icon(Iconsax.document, color: AvailColors.primary));
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: darkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: darkMode ? const Color(0xFF334155) : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: thumbnail),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (doc['name'] as String? ?? '').isNotEmpty ? doc['name'] as String : 'Waybill / Cargo Document ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 12,
                        color: darkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.trash, size: 18, color: Colors.red),
                    onPressed: () => controller.removeDocument(index),
                  ),
                ],
              ),
            );
          },
        )),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showDocumentSourcePicker(context, controller, darkMode),
            icon: const Icon(Iconsax.document_upload, size: 18),
            label: const Text('UPLOAD WAYBILL OR INVOICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  void _showDocumentSourcePicker(BuildContext context, CustomerHomeController controller, bool darkMode) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: darkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ATTACH FREIGHT DOCUMENTATION', 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 14,
                  color: darkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSourceOption('Camera', Iconsax.camera, () {
                    Get.back();
                    controller.pickDocument('CAMERA');
                  }, darkMode: darkMode),
                  _buildSourceOption('Gallery', Iconsax.gallery, () {
                    Get.back();
                    controller.pickDocument('GALLERY');
                  }, darkMode: darkMode),
                  _buildSourceOption('Files', Iconsax.folder_open, () {
                    Get.back();
                    controller.pickDocument('FILE');
                  }, darkMode: darkMode),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(String label, IconData icon, VoidCallback onTap, {required bool darkMode}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AvailColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AvailColors.primary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label, 
            style: TextStyle(
              fontWeight: FontWeight.w600, 
              fontSize: 11,
              color: darkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ================= 8. CONTACT PERSONS & PROFILE AUTO-FILL =================
  Widget _buildContactSection(CustomerHomeController controller, bool darkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: darkMode ? const Color(0xFF334155) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                final user = UserController.instance.user.value;
                if (user.fullName.isNotEmpty) controller.senderNameController.text = user.fullName;
                if (user.phoneNumber.isNotEmpty) controller.senderPhoneController.text = user.phoneNumber;
              },
              icon: const Icon(Iconsax.user_edit, size: 14, color: AvailColors.primary),
              label: const Text('Fill Sender Info From Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller.senderNameController,
            decoration: const InputDecoration(labelText: 'Sender Full Name', prefixIcon: Icon(Iconsax.user)),
            validator: (value) => value!.isEmpty ? 'Sender name required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.senderPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Sender Phone Number', prefixIcon: Icon(Iconsax.call)),
            validator: (value) => value!.isEmpty ? 'Sender phone required' : null,
          ),
          const SizedBox(height: 16),
          Divider(color: darkMode ? const Color(0xFF334155) : Colors.grey.shade200),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller.receiverNameController,
            decoration: const InputDecoration(labelText: 'Receiver Full Name', prefixIcon: Icon(Iconsax.user_tick)),
            validator: (value) => value!.isEmpty ? 'Receiver name required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.receiverPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Receiver Phone Number', prefixIcon: Icon(Iconsax.call)),
            validator: (value) => value!.isEmpty ? 'Receiver phone required' : null,
          ),
        ],
      ),
    );
  }

  // ================= 9. ITEMIZED FARE BREAKDOWN CARD WITH CURRENCY CONVERSION =================
  Widget _buildItemizedFareCard(CustomerHomeController controller, bool darkMode) {
    return Obx(() {
      final breakdown = controller.calculatedBreakdown;
      final locController = LocalizationController.instance;

      String fmt(double usdAmount) {
        return locController.getFormattedPrice(usdAmount);
      }

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: darkMode ? const Color(0xFF1E293B) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: darkMode ? const Color(0xFF334155) : Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: darkMode ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LOGISTICS FARE RECEIPT', 
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: FontWeight.bold, 
                    color: darkMode ? Colors.white60 : Colors.grey, 
                    letterSpacing: 1.1,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'CURRENCY:', 
                      style: TextStyle(
                        fontSize: 9, 
                        fontWeight: FontWeight.bold, 
                        color: darkMode ? Colors.white60 : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: locController.selectedCurrency.value,
                      dropdownColor: darkMode ? const Color(0xFF1E293B) : Colors.white,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AvailColors.primary),
                      isDense: true,
                      underline: const SizedBox(),
                      items: locController.supportedCurrencies.keys.map((code) {
                        final option = locController.supportedCurrencies[code]!;
                        final String cCode = option['name'] ?? code;
                        final String cSym = option['symbol'] ?? '';
                        return DropdownMenuItem(value: code, child: Text('$cCode ($cSym)'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) controller.updateCurrency(val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 20, color: darkMode ? const Color(0xFF334155) : Colors.grey.shade200),

            _buildFareLine('Base Fare (${breakdown.journeyCategory} ${breakdown.baseFareMultiplier.toStringAsFixed(2)}x)', fmt(breakdown.effectiveBaseFare), darkMode),
            _buildFareLine('Distance Fare (${controller.estimatedDistance.value} x ${controller.tripType.value == 'round_trip' ? '1.8x Return' : '1x'})', fmt(breakdown.distanceFare), darkMode),

            if (breakdown.containerSizeSurcharge > 0)
              _buildFareLine('ISO Container Deck Surcharge (${breakdown.containerSize})', '+${fmt(breakdown.containerSizeSurcharge)}', darkMode),

            if (breakdown.emptyContainerDiscount > 0)
              _buildFareLine('Empty Container Return Discount (${breakdown.containerStatus})', '-${fmt(breakdown.emptyContainerDiscount)}', darkMode, isDiscount: true),

            if (breakdown.excessWeightKg > 0)
              _buildFareLine('Excess Weight (${(breakdown.excessWeightKg / 1000.0).toStringAsFixed(1)} Tons)', '+${fmt(breakdown.weightFare)}', darkMode),

            if (breakdown.roadAllowance > 0)
              _buildFareLine('Driver Road Allowance (Food/Rest)', '+${fmt(breakdown.roadAllowance)}', darkMode),

            if (breakdown.fragileSurcharge > 0)
              _buildFareLine('Fragile Cargo Surcharge', '+${fmt(breakdown.fragileSurcharge)}', darkMode),

            if (breakdown.hazardousSurcharge > 0)
              _buildFareLine('Hazardous Material Surcharge', '+${fmt(breakdown.hazardousSurcharge)}', darkMode),

            if (breakdown.roundTripAdjustment > 0)
              _buildFareLine('Round-Trip Incentive Discount', '-${fmt(breakdown.roundTripAdjustment)}', darkMode, isDiscount: true),

            Divider(height: 24, color: darkMode ? const Color(0xFF334155) : Colors.grey.shade200),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL ESTIMATED FARE', 
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 13,
                    color: darkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  fmt(breakdown.totalPrice),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AvailColors.primary),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFareLine(String label, String amountStr, bool darkMode, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12, 
                color: isDiscount ? Colors.green.shade400 : (darkMode ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountStr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDiscount ? Colors.green.shade400 : (darkMode ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // ================= MANIFEST REVIEW SHEET =================
  void _showManifestReviewSheet(BuildContext context, CustomerHomeController controller, bool darkMode) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: darkMode ? AvailColors.dark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FREIGHT MANIFEST SUMMARY',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        const Text('Review details before dispatch confirmation', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AvailColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.document_text, color: AvailColors.primary, size: 22),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Route Timeline
                _buildReviewRow('ORIGIN', controller.pickupName.value, Icons.location_on, Colors.blue),
                ...controller.additionalStops.asMap().entries.map((entry) =>
                  _buildReviewRow('STOP ${entry.key + 1}', entry.value['address'], Icons.location_on, Colors.orange)
                ),
                _buildReviewRow('DESTINATION', controller.destinationName.value, Icons.location_on, Colors.red),

                const Divider(height: 30),

                // Cargo Summary Metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildReviewMetric(
                      'CARGO TYPE',
                      controller.selectedCargoType.value == 'Container'
                          ? '${controller.selectedContainerSize.value} (${controller.selectedContainerStatus.value})'
                          : controller.selectedCargoType.value,
                    ),
                    _buildReviewMetric('VEHICLE', controller.selectedTruckType.value),
                    _buildReviewMetric('WEIGHT', '${controller.weightController.text} Tons'),
                    _buildReviewMetric(
                      'DISPATCH',
                      controller.scheduledDateTime.value == null
                          ? 'Immediate'
                          : DateFormat('MMM dd, HH:mm').format(controller.scheduledDateTime.value!),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Itemized Inventory Badges
                if (controller.inventoryItems.isNotEmpty) ...[
                  const Text('INVENTORY PREVIEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: controller.inventoryItems.map((item) => Chip(
                      label: Text('${item['name']} x${item['quantity']}', style: const TextStyle(fontSize: 11)),
                      backgroundColor: AvailColors.primary.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Itemized Fare Breakdown Card
                _buildItemizedFareCard(controller, darkMode),

                const SizedBox(height: 24),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.back();
                      controller.saveBooking();
                    },
                    icon: const Icon(Iconsax.send_1, color: Colors.white, size: 20),
                    label: Obx(() => Text(
                      controller.editingBookingId.value.isNotEmpty
                          ? 'UPDATE FREIGHT MANIFEST'
                          : 'CONFIRM & DISPATCH FREIGHT',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AvailColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildReviewRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AvailColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AvailColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: darkMode ? Colors.grey[300] : Colors.grey[800],
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: darkMode ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}
