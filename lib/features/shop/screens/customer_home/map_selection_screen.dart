import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:truck_booking/commons/widgets/layouts/site_layout.dart';
import 'package:truck_booking/features/shop/controllers/customer/customer_home_controller.dart';
import 'package:truck_booking/features/shop/screens/customer_home/widgets/animated_3d_map_pin.dart';
import 'package:truck_booking/features/shop/screens/customer_home/place_search_screen.dart';
import 'package:truck_booking/utils/constants/colors.dart';
import 'package:truck_booking/utils/constants/sizes.dart';
import 'package:truck_booking/utils/helpers/helper_functions.dart';
import 'package:truck_booking/utils/constants/map_styles.dart';

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({
    super.key,
    required this.locationType,
    this.stopIndex,
  });

  final String locationType;
  final int? stopIndex;

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
      );
    });
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
                  target: controller.pinnedLocation.value ?? controller.currentPosition.value ?? const LatLng(5.6037, -0.1870),
                  zoom: 16,
                ),
                onMapCreated: (mapCtrl) {
                  controller.mapController = mapCtrl;
                  AvailMapStyles.applyThemeStyle(mapCtrl, darkMode);
                  if (controller.pinnedLocation.value != null) {
                    mapCtrl.animateCamera(CameraUpdate.newLatLngZoom(controller.pinnedLocation.value!, 16));
                  }
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapType: controller.mapType.value,
                trafficEnabled: controller.isTrafficEnabled.value,
                padding: const EdgeInsets.only(bottom: 150),
                onCameraMove: (position) {
                  controller.pinnedLocation.value = position.target;
                },
                onCameraIdle: () {
                  if (controller.pinnedLocation.value != null) {
                    controller.updatePinnedAddress(controller.pinnedLocation.value!);
                  }
                },
              ),
            ),

            // 2. Floating Top Header
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: AvailSizes.defaultSpace,
              right: AvailSizes.defaultSpace,
              child: ResponsiveCenter(
                maxWidth: 560,
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
                      onTap: () {
                        controller.exitMapSelectionMode();
                        Get.back();
                      },
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
                        'SELECT ${widget.locationType.toUpperCase()} LOCATION ON MAP',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),

            // 2b. Floating Search Bar for Instant Place Lookup
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: AvailSizes.defaultSpace,
              right: AvailSizes.defaultSpace,
              child: ResponsiveCenter(
                maxWidth: 560,
                child: GestureDetector(
                onTap: () async {
                  final searchResult = await Get.to(
                    () => PlaceSearchScreen(
                      initialValue: controller.pinnedAddress.value != 'Locating address...' ? controller.pinnedAddress.value : '',
                    ),
                    routeName: '/place-search',
                  );
                  if (searchResult != null && searchResult is Map) {
                    final double? lat = (searchResult['lat'] as num?)?.toDouble();
                    final double? lng = (searchResult['lng'] as num?)?.toDouble();
                    final String addr = (searchResult['description'] ?? searchResult['address'] ?? searchResult['name'] ?? '').toString();
                    if (lat != null && lng != null) {
                      final target = LatLng(lat, lng);
                      controller.pinnedLocation.value = target;
                      controller.pinnedAddress.value = addr.isNotEmpty ? addr : 'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
                      controller.mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
                    }
                  }
                },
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: darkMode ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: darkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: darkMode ? 0.35 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.search_normal_1, color: AvailColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Obx(() {
                          final currentAddr = controller.pinnedAddress.value;
                          final hasAddr = currentAddr.isNotEmpty && currentAddr != 'Locating address...' && currentAddr != 'Where to?';
                          return Text(
                            hasAddr ? currentAddr : 'Search address, landmark or terminal...',
                            style: TextStyle(
                              color: hasAddr
                                  ? (darkMode ? Colors.white : const Color(0xFF0F172A))
                                  : (darkMode ? Colors.white54 : const Color(0xFF64748B)),
                              fontSize: 12.5,
                              fontWeight: hasAddr ? FontWeight.w700 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AvailColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AvailColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ),

            // 3. Floating Map Controls (Right Side)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + 130,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_select_recenter',
                    onPressed: () => controller.recenterToCurrentLocation(),
                    backgroundColor: darkMode ? const Color(0xFF0F172A) : Colors.white,
                    foregroundColor: AvailColors.primary,
                    child: const Icon(Iconsax.gps, size: 18),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'map_select_layer',
                    onPressed: () => controller.toggleMapType(),
                    backgroundColor: darkMode ? const Color(0xFF0F172A) : Colors.white,
                    foregroundColor: Colors.blue,
                    child: const Icon(Iconsax.layer, size: 18),
                  ),
                ],
              ),
            ),

            // 4. Center Interactive Pin Widget
            Animated3DMapPin(controller: controller),

            // 5. Bottom Location Confirmation Card
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ResponsiveCenter(
                maxWidth: 560,
                child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: darkMode ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border(
                    top: BorderSide(
                      color: darkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: darkMode ? 0.35 : 0.1), blurRadius: 20)],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.location,
                            color: widget.locationType == 'pickup' ? Colors.blue : (widget.locationType == 'destination' ? Colors.red : Colors.orange),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SET ${widget.locationType.toUpperCase()} LOCATION',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                Obx(() => Text(
                                  controller.pinnedAddress.value.isNotEmpty ? controller.pinnedAddress.value : 'Locating address...',
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
                              onPressed: () {
                                controller.exitMapSelectionMode();
                                Get.back();
                              },
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
                              onPressed: () {
                                final loc = controller.pinnedLocation.value ?? controller.currentPosition.value ?? const LatLng(5.6037, -0.1870);
                                final addr = controller.pinnedAddress.value.isNotEmpty && controller.pinnedAddress.value != 'Locating address...' && controller.pinnedAddress.value != 'Where to?'
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
            ),
          ],
        ),
      ),
    );
  }
}
