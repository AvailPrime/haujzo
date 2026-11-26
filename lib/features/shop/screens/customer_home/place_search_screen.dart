import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../controllers/customer/customer_home_controller.dart';
import '../../controllers/customer/place_search_controller.dart';

class PlaceSearchScreen extends StatelessWidget {
  const PlaceSearchScreen({super.key, this.initialValue});

  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PlaceSearchController());
    final TextEditingController textController = TextEditingController(text: initialValue);
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    // If there's an initial value, trigger search immediately to show suggestions
    if (initialValue != null && initialValue!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.findPlaceAutocomplete(initialValue!);
      });
    }

    final bgColor = darkMode ? const Color(0xFF0F172A) : Colors.white;
    final searchInputBg = darkMode ? const Color(0xFF1E293B) : Colors.grey[100];
    final textColor = darkMode ? Colors.white : Colors.black87;
    final hintColor = darkMode ? Colors.white38 : Colors.black38;
    final dividerColor = darkMode ? const Color(0xFF334155) : Colors.black12;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Search Location',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: textColor),
          onPressed: () => Get.back(),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 760,
        child: Column(
          children: [
          // Elegant Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: searchInputBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: darkMode ? const Color(0xFF334155) : Colors.transparent),
              ),
              child: TextField(
                controller: textController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Where would you like to go?',
                  hintStyle: TextStyle(color: hintColor),
                  prefixIcon: const Icon(Iconsax.search_normal, color: AvailColors.primary, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.close, size: 20, color: darkMode ? Colors.white60 : Colors.black54),
                    onPressed: () {
                      textController.clear();
                      controller.placePredictions.clear();
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onChanged: (value) {
                  controller.findPlaceAutocomplete(value);
                },
                onSubmitted: (value) async {
                  if (value.trim().isEmpty) return;
                  if (controller.placePredictions.isNotEmpty) {
                    final first = controller.placePredictions.first;
                    final details = await controller.getPlaceDetails(first['place_id']);
                    if (details != null) {
                      final placeData = {
                        'description': first['description'],
                        'lat': details['lat'],
                        'lng': details['lng'],
                      };
                      controller.addToRecent(placeData);
                      Get.back(result: placeData);
                      return;
                    }
                  }
                  // Geocode fallback
                  final geocoded = await controller.geocodeAddress(value);
                  if (geocoded != null) {
                    controller.addToRecent(geocoded);
                    Get.back(result: geocoded);
                  } else {
                    Get.back(result: {'description': value.trim()});
                  }
                },
              ),
            ),
          ),
          
          Divider(thickness: 1, color: dividerColor),

          // Search Results
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: AvailColors.primary));
              }

              if (controller.placePredictions.isEmpty && textController.text.isEmpty) {
                return _buildRecentSuggestions(darkMode);
              }

              if (controller.placePredictions.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AvailColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.location, size: 20, color: AvailColors.primary),
                      ),
                      title: Text(
                        'Use "${textController.text.trim()}"',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                      ),
                      subtitle: Text('Tap to set this custom location', style: TextStyle(color: hintColor, fontSize: 12)),
                      onTap: () async {
                        final val = textController.text.trim();
                        final geocoded = await controller.geocodeAddress(val);
                        if (geocoded != null) {
                          controller.addToRecent(geocoded);
                          Get.back(result: geocoded);
                        } else {
                          Get.back(result: {'description': val});
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    Divider(height: 1, thickness: 0.5, color: dividerColor),
                    const SizedBox(height: 20),
                    Center(child: Text('No further online suggestions found.', style: TextStyle(color: hintColor))),
                  ],
                );
              }

              return ListView.separated(
                itemCount: controller.placePredictions.length,
                padding: const EdgeInsets.symmetric(vertical: 10),
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(left: 70),
                  child: Divider(height: 1, thickness: 0.5, color: dividerColor),
                ),
                itemBuilder: (context, index) {
                  final prediction = controller.placePredictions[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: darkMode ? const Color(0xFF1E293B) : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Iconsax.location, size: 20, color: darkMode ? Colors.white70 : Colors.black54),
                    ),
                    title: Text(
                      prediction['description'],
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      prediction['structured_formatting']?['secondary_text'] ?? 'Location Details',
                      style: TextStyle(color: hintColor, fontSize: 12),
                    ),
                    onTap: () async {
                      final details = await controller.getPlaceDetails(prediction['place_id']);
                      if (details != null) {
                        final placeData = {
                          'description': prediction['description'],
                          'lat': details['lat'],
                          'lng': details['lng'],
                        };
                        controller.addToRecent(placeData);
                        Get.back(result: placeData);
                      }
                    },
                  );
                },
              );
            }),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildRecentSuggestions(bool darkMode) {
    final controller = PlaceSearchController.instance;
    final homeController = CustomerHomeController.instance;

    final hubs = [
      {'title': 'MPS Tema Terminal 3 (Port Gate)', 'subtitle': 'Container Terminal Gate 1', 'lat': 5.6322, 'lng': -0.0166, 'icon': Iconsax.ship},
      {'title': 'Takoradi Harbor Commercial Gate', 'subtitle': 'Container & Bulk Jetty', 'lat': 4.8872, 'lng': -1.7542, 'icon': Iconsax.ship},
      {'title': 'Kotoka Air Cargo Terminal (KIA)', 'subtitle': 'Air Freight Depot Gate 4', 'lat': 5.6052, 'lng': -0.1668, 'icon': Iconsax.airplane},
      {'title': 'Spintex Heavy Industrial Enclave', 'subtitle': 'Logistics & Warehousing Yard', 'lat': 5.6288, 'lng': -0.1142, 'icon': Iconsax.building},
      {'title': 'Boankra Inland Port / Depot (Kumasi)', 'subtitle': 'Inland Container Depot (ICD)', 'lat': 6.6885, 'lng': -1.6244, 'icon': Iconsax.truck_fast},
    ];

    final dividerColor = darkMode ? const Color(0xFF334155) : Colors.black12;
    final headerColor = darkMode ? Colors.white54 : Colors.black38;

    return Obx(() {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildRecentItem(
            Iconsax.map,
            'Pin Location on Map',
            'Select exact pickup or drop-off spot on interactive map',
            onTap: () {
              Get.back(result: 'SELECT_ON_MAP');
            },
            iconColor: AvailColors.primary,
            darkMode: darkMode,
          ),

          _buildRecentItem(
            Iconsax.gps,
            'Current GPS Location',
            homeController.pickupName.value.isNotEmpty &&
                    !homeController.pickupName.value.toLowerCase().contains('current location') &&
                    !homeController.pickupName.value.toLowerCase().contains('select pickup')
                ? homeController.pickupName.value
                : 'Your device\'s live GPS coordinates',
            onTap: () async {
              LatLng? pos = homeController.currentPosition.value;
              if (pos == null) {
                await homeController.getCurrentLocation();
                pos = homeController.currentPosition.value;
              }
              if (pos != null) {
                String resolved = '';
                final currentPickup = homeController.pickupName.value.trim();
                if (currentPickup.isNotEmpty &&
                    !currentPickup.toLowerCase().contains('current location') &&
                    !currentPickup.toLowerCase().contains('select pickup') &&
                    homeController.pickupLocation.value == pos) {
                  resolved = currentPickup;
                } else {
                  resolved = await homeController.reverseGeocode(pos);
                }

                final String finalAddress = resolved.isNotEmpty
                    ? resolved
                    : 'GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';

                Get.back(result: {
                  'description': finalAddress,
                  'formatted_address': finalAddress,
                  'name': finalAddress,
                  'address': finalAddress,
                  'lat': pos.latitude,
                  'lng': pos.longitude,
                });
              }
            },
            iconColor: Colors.blue,
            darkMode: darkMode,
          ),
          
          // Firebase Saved Addresses Section
          if (controller.userSavedAddresses.isNotEmpty || controller.userBusinessAddress.value.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 0.5, color: dividerColor),
            const SizedBox(height: 15),
            Text(
              'SAVED ACCOUNT ADDRESSES (FIREBASE)',
              style: TextStyle(color: headerColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 10),

            if (controller.userBusinessAddress.value.isNotEmpty)
              _buildRecentItem(
                Iconsax.building,
                'Business Headquarters',
                controller.userBusinessAddress.value,
                iconColor: const Color(0xFF10B981),
                darkMode: darkMode,
                onTap: () async {
                  final addr = controller.userBusinessAddress.value;
                  final geocoded = await controller.geocodeAddress(addr);
                  final placeData = {
                    'description': addr,
                    'lat': geocoded?['lat'] ?? 5.6037,
                    'lng': geocoded?['lng'] ?? -0.1870,
                  };
                  controller.addToRecent(placeData);
                  Get.back(result: placeData);
                },
              ),

            ...controller.userSavedAddresses.map((addr) => _buildRecentItem(
              Iconsax.location_tick,
              addr.name.isNotEmpty ? addr.name : '${addr.city}, ${addr.country}',
              '${addr.street}, ${addr.city}, ${addr.country}',
              iconColor: const Color(0xFF0088FF),
              darkMode: darkMode,
              onTap: () async {
                final fullAddr = '${addr.street}, ${addr.city}, ${addr.country}';
                final geocoded = await controller.geocodeAddress(fullAddr);
                final placeData = {
                  'description': addr.name.isNotEmpty ? '${addr.name} (${addr.city})' : fullAddr,
                  'lat': geocoded?['lat'] ?? 5.6037,
                  'lng': geocoded?['lng'] ?? -0.1870,
                };
                controller.addToRecent(placeData);
                Get.back(result: placeData);
              },
            )),
          ],

          const SizedBox(height: 10),
          Divider(height: 1, thickness: 0.5, color: dividerColor),
          const SizedBox(height: 15),

          Text(
            'MAJOR LOGISTICS HUBS & PORTS',
            style: TextStyle(color: headerColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
          ),
          const SizedBox(height: 10),

          ...hubs.map((hub) => _buildRecentItem(
            hub['icon'] as IconData,
            hub['title'] as String,
            hub['subtitle'] as String,
            iconColor: AvailColors.primary,
            darkMode: darkMode,
            onTap: () {
              final placeData = {
                'description': hub['title'],
                'lat': hub['lat'],
                'lng': hub['lng'],
              };
              controller.addToRecent(placeData);
              Get.back(result: placeData);
            },
          )),

          if (controller.recentSearches.isNotEmpty) ...[
            const SizedBox(height: 15),
            Divider(height: 1, thickness: 0.5, color: dividerColor),
            const SizedBox(height: 15),
            Text(
              'RECENT SEARCHES',
              style: TextStyle(color: headerColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 10),
            ...controller.recentSearches.map((place) => _buildRecentItem(
                  Iconsax.clock,
                  place['description'],
                  'Ghana',
                  darkMode: darkMode,
                  onTap: () => Get.back(result: place),
                )),
          ],
        ],
      );
    });
  }

  Widget _buildRecentItem(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    Color? iconColor,
    required bool darkMode,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: darkMode ? const Color(0xFF1E293B) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor ?? (darkMode ? Colors.white54 : Colors.black26), size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: darkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: darkMode ? Colors.white54 : Colors.black38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
