import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:truck_booking/commons/widgets/layouts/site_layout.dart';
import 'package:truck_booking/features/shop/controllers/customer/customer_home_controller.dart';
import 'package:truck_booking/features/shop/screens/customer_home/widgets/animated_3d_map_pin.dart';
import 'package:truck_booking/features/shop/screens/customer_home/place_search_screen.dart';
import 'package:truck_booking/utils/constants/colors.dart';
import 'package:truck_booking/utils/helpers/helper_functions.dart';
import 'package:truck_booking/utils/constants/map_styles.dart';

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({
    super.key,
    required this.locationType,
    this.stopIndex,
    this.initialLocation,
    this.initialAddress,
  });

  final String locationType;
  final int? stopIndex;
  final LatLng? initialLocation;
  final String? initialAddress;

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  final controller = CustomerHomeController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.enterMapSelectionMode(
        widget.locationType,
        stopIndex: widget.stopIndex,
        fromDispatch: false,
        initialLocation: widget.initialLocation,
        initialAddress: widget.initialAddress,
      );
      if (widget.locationType == 'pickup') {
        Future.wait([
          controller.getGreenCurbDotMarkerIcon(forceRefresh: true),
          controller.getSelectedPickupSpotMarkerIcon(forceRefresh: true),
        ]).then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  Set<Marker> _buildSuggestedSpotMarkers(CustomerHomeController controller) {
    if (controller.greenCurbDotMarkerIcon == null) return {};
    return controller.suggestedPickupSpots.map((spot) {
      final isSelected = controller.selectedSuggestedSpot.value?.id == spot.id;
      final icon = (isSelected && controller.selectedPickupSpotMarkerIcon != null)
          ? controller.selectedPickupSpotMarkerIcon!
          : controller.greenCurbDotMarkerIcon!;
      final anchor = isSelected ? const Offset(0.5, 0.8333) : const Offset(0.5, 0.5);

      return Marker(
        markerId: MarkerId(spot.id),
        position: spot.location,
        icon: icon,
        anchor: anchor,
        zIndex: isSelected ? 35 : 15,
        onTap: () {
          controller.selectSuggestedPickupSpot(spot);
          if (mounted) setState(() {});
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          controller.isSelectingOnMap.value = false;
          controller.mapController = controller.homeMapController;
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Google Map
            Obx(
              () => GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.initialLocation ??
                      controller.pinnedLocation.value ??
                      controller.currentPosition.value ??
                      const LatLng(5.6037, -0.1870),
                  zoom: 17,
                ),
                onMapCreated: (mapCtrl) {
                  controller.mapController = mapCtrl;
                  AvailMapStyles.applyThemeStyle(mapCtrl, darkMode);
                  final target = widget.initialLocation ?? controller.pinnedLocation.value;
                  if (target != null) {
                    mapCtrl.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
                  }
                },
                markers: widget.locationType == 'pickup' ? _buildSuggestedSpotMarkers(controller) : const {},
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapType: controller.mapType.value,
                trafficEnabled: controller.isTrafficEnabled.value,
                padding: EdgeInsets.only(bottom: widget.locationType == 'pickup' ? 320 : 230),
                onCameraMove: (position) {
                  controller.pinnedLocation.value = position.target;
                },
                onCameraIdle: () {
                  if (controller.pinnedLocation.value != null &&
                      (controller.pinnedAddress.value.isEmpty ||
                          controller.pinnedAddress.value == 'Locating address...' ||
                          controller.pinnedAddress.value == 'Where to?')) {
                    controller.updatePinnedAddress(controller.pinnedLocation.value!);
                  }
                },
              ),
            ),

            // 2. Clean Uber-Style Top Back Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              left: 18,
              child: GestureDetector(
                onTap: () {
                  controller.exitMapSelectionMode();
                  Get.back();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: darkMode ? const Color(0xFF1E293B) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: darkMode ? 0.4 : 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_back,
                      color: darkMode ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // 3. Floating Map Controls (Right Side)
            Positioned(
              right: 18,
              top: MediaQuery.of(context).padding.top + 14,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_select_recenter',
                    onPressed: () => controller.recenterToCurrentLocation(),
                    backgroundColor: darkMode ? const Color(0xFF1E293B) : Colors.white,
                    foregroundColor: AvailColors.primary,
                    child: const Icon(Iconsax.gps, size: 18),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'map_select_layer',
                    onPressed: () => controller.toggleMapType(),
                    backgroundColor: darkMode ? const Color(0xFF1E293B) : Colors.white,
                    foregroundColor: Colors.blue,
                    child: const Icon(Iconsax.layer, size: 18),
                  ),
                ],
              ),
            ),

            // 4. Center Interactive Pin Widget (Only for destination/stops where user positions pin freely)
            if (widget.locationType != 'pickup') Animated3DMapPin(controller: controller),

            // 5. Bottom Confirmation Sheet (Exact Uber Style Matching User Screenshot)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ResponsiveCenter(
                maxWidth: 560,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  decoration: BoxDecoration(
                    color: darkMode ? const Color(0xFF121B28) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      top: BorderSide(
                        color: darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: darkMode ? 0.5 : 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: widget.locationType == 'pickup'
                        ? _buildUberPickupConfirmationCard(controller, darkMode)
                        : _buildStandardConfirmationCard(controller, darkMode),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Authentic Uber-Style Pickup Confirmation Card
  Widget _buildUberPickupConfirmationCard(CustomerHomeController controller, bool darkMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header: "Confirm the pick-up spot" + Subtitle Place Name + Search Icon
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm the pick-up spot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: darkMode ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Obx(() {
                    final addr = controller.pinnedAddress.value;
                    final displaySubtitle = addr.isNotEmpty && addr != 'Locating address...'
                        ? (addr.contains('•') ? addr.split('•').last.trim() : addr)
                        : (widget.initialAddress ?? 'Tema Bonded Terminal');
                    return Text(
                      displaySubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: darkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final searchResult = await Get.to(
                  () => PlaceSearchScreen(
                    initialValue: controller.pinnedAddress.value != 'Locating address...'
                        ? controller.pinnedAddress.value
                        : '',
                  ),
                  routeName: '/place-search',
                );
                if (searchResult != null && searchResult is Map) {
                  final double? lat = (searchResult['lat'] as num?)?.toDouble();
                  final double? lng = (searchResult['lng'] as num?)?.toDouble();
                  final String addr = (searchResult['description'] ??
                          searchResult['address'] ??
                          searchResult['name'] ??
                          '')
                      .toString();
                  if (lat != null && lng != null) {
                    final target = LatLng(lat, lng);
                    controller.pinnedLocation.value = target;
                    controller.pinnedAddress.value = addr;
                    controller.generateSuggestedPickupSpots(target, addr);
                    controller.mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(target, 17),
                    );
                    if (mounted) setState(() {});
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: darkMode ? const Color(0xFF1E293B) : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.search_normal_1,
                  size: 19,
                  color: darkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Selectable Spot Cards (Matching Uber Screenshot: Spot #3, Spot #4...)
        Obx(() {
          final spots = controller.suggestedPickupSpots;
          if (spots.isEmpty) return const SizedBox.shrink();

          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: spots.length.clamp(0, 3),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final spot = spots[index];
                final isSelected = controller.selectedSuggestedSpot.value?.id == spot.id;

                return InkWell(
                  onTap: () {
                    controller.selectSuggestedPickupSpot(spot);
                    if (mounted) setState(() {});
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: darkMode
                          ? (isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
                          : (isSelected ? Colors.white : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? (darkMode ? Colors.white : const Color(0xFF0F172A))
                            : (darkMode ? const Color(0xFF26354A) : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spot.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: darkMode ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                spot.subtitle,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: darkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (spot.distanceMeters > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '${spot.distanceMeters.toStringAsFixed(0)}m',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: darkMode ? Colors.grey[400] : Colors.grey[500],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
        const SizedBox(height: 18),

        // 3. Full-Width "Confirm pick-up" Button (Uber Screenshot Style)
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              final loc = controller.pinnedLocation.value ??
                  controller.currentPosition.value ??
                  const LatLng(5.6037, -0.1870);
              final addr = controller.pinnedAddress.value.isNotEmpty &&
                      controller.pinnedAddress.value != 'Locating address...' &&
                      controller.pinnedAddress.value != 'Where to?'
                  ? controller.pinnedAddress.value
                  : 'GPS: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';

              controller.wasOpenedFromDispatchForm.value = false;
              controller.confirmPinnedLocation(stopIndex: widget.stopIndex);
              Get.back(result: {
                'description': addr,
                'lat': loc.latitude,
                'lng': loc.longitude,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: darkMode ? Colors.white : const Color(0xFF0F172A),
              foregroundColor: darkMode ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text(
              'Confirm pick-up',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Standard Confirmation Card for Destination and Intermediate Stops
  Widget _buildStandardConfirmationCard(CustomerHomeController controller, bool darkMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.locationType == 'destination' ? 'Confirm delivery spot' : 'Confirm stop location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: darkMode ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Obx(() => Text(
                    controller.pinnedAddress.value.isNotEmpty && controller.pinnedAddress.value != 'Locating address...'
                        ? controller.pinnedAddress.value
                        : (widget.initialAddress ?? 'Align pin on map'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: darkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final searchResult = await Get.to(
                  () => PlaceSearchScreen(
                    initialValue: controller.pinnedAddress.value != 'Locating address...'
                        ? controller.pinnedAddress.value
                        : '',
                  ),
                  routeName: '/place-search',
                );
                if (searchResult != null && searchResult is Map) {
                  final double? lat = (searchResult['lat'] as num?)?.toDouble();
                  final double? lng = (searchResult['lng'] as num?)?.toDouble();
                  final String addr = (searchResult['description'] ??
                          searchResult['address'] ??
                          searchResult['name'] ??
                          '')
                      .toString();
                  if (lat != null && lng != null) {
                    final target = LatLng(lat, lng);
                    controller.pinnedLocation.value = target;
                    controller.pinnedAddress.value = addr;
                    controller.mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(target, 17),
                    );
                    if (mounted) setState(() {});
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: darkMode ? const Color(0xFF1E293B) : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.search_normal_1,
                  size: 19,
                  color: darkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Iconsax.routing_2, size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Move map to position exact road access or delivery gate',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: darkMode ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              final loc = controller.pinnedLocation.value ??
                  controller.currentPosition.value ??
                  const LatLng(5.6037, -0.1870);
              final addr = controller.pinnedAddress.value.isNotEmpty &&
                      controller.pinnedAddress.value != 'Locating address...' &&
                      controller.pinnedAddress.value != 'Where to?'
                  ? controller.pinnedAddress.value
                  : 'GPS: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';

              controller.wasOpenedFromDispatchForm.value = false;
              controller.confirmPinnedLocation(stopIndex: widget.stopIndex);
              Get.back(result: {
                'description': addr,
                'lat': loc.latitude,
                'lng': loc.longitude,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: darkMode ? Colors.white : AvailColors.primary,
              foregroundColor: darkMode ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              widget.locationType == 'destination' ? 'Confirm delivery spot' : 'Confirm stop spot',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
