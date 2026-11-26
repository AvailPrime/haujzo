import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/colors.dart';
import '../../controllers/customer/customer_home_controller.dart';
import '../../controllers/customer/place_search_controller.dart';

class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({super.key});

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  final homeController = CustomerHomeController.instance;
  final searchController = Get.put(PlaceSearchController());

  final pickupTextController = TextEditingController();
  final destinationTextController = TextEditingController();
  
  bool isSearchingPickup = true;
  bool isSearchingDestination = false;

  @override
  void initState() {
    super.initState();
    pickupTextController.text = homeController.pickupName.value == 'Current Location' ? '' : homeController.pickupName.value;
    destinationTextController.text = homeController.destinationName.value == 'Where to?' ? '' : homeController.destinationName.value;
    searchController.findPlaceAutocomplete(pickupTextController.text);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = dark ? const Color(0xFF0A192F) : const Color(0xFFF8F9FA);
    final circleBg = dark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AvailColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('DISPATCH ROUTE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
        leading: IconButton(icon: const Icon(Iconsax.arrow_left), onPressed: () => Get.back()),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Industrial Route Input
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AvailColors.secondary,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: ResponsiveCenter(
                maxWidth: 760,
                child: Column(
                  children: [
                  _buildIndustrialInput(
                    controller: pickupTextController,
                    label: 'ORIGIN / PICKUP',
                    icon: Iconsax.box,
                    iconColor: Colors.blueAccent,
                    isFocused: isSearchingPickup,
                    onTap: () => setState(() { isSearchingPickup = true; isSearchingDestination = false; }),
                    onChanged: (val) => searchController.findPlaceAutocomplete(val),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              final temp = pickupTextController.text;
                              pickupTextController.text = destinationTextController.text;
                              destinationTextController.text = temp;
                              homeController.reverseRoute();
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.arrow_swap_horizontal, color: AvailColors.primary, size: 14),
                                SizedBox(width: 4),
                                Text('SWAP', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildIndustrialInput(
                    controller: destinationTextController,
                    label: 'DESTINATION / DROP-OFF',
                    icon: Iconsax.location,
                    iconColor: Colors.redAccent,
                    isFocused: isSearchingDestination,
                    onTap: () => setState(() { isSearchingPickup = false; isSearchingDestination = true; }),
                    onChanged: (val) => searchController.findPlaceAutocomplete(val),
                  ),
                ],
                ),
              ),
            ),

            // Search Results
            Expanded(
              child: ResponsiveCenter(
                maxWidth: 760,
                child: Obx(() {
                if (searchController.isLoading.value) {
                  return const Center(child: CircularProgressIndicator(color: AvailColors.primary));
                }

                return ListView(
                  children: [
                    if (isSearchingPickup && homeController.currentPosition.value != null) ...[
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: circleBg,
                          child: const Icon(Iconsax.gps, size: 20, color: Colors.blueAccent),
                        ),
                        title: const Text('Use Current GPS Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Origin will be set to where you are right now', style: TextStyle(fontSize: 10)),
                        onTap: () {
                          homeController.setPickup(homeController.currentPosition.value!, 'Current Location');
                          if (homeController.destinationLocation.value == null) {
                            setState(() { isSearchingPickup = false; isSearchingDestination = true; });
                            destinationTextController.text = '';
                            searchController.findPlaceAutocomplete('');
                          } else {
                            Get.back();
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 70),
                    ],
                    ListTile(
                      leading: CircleAvatar(backgroundColor: circleBg, child: const Icon(Iconsax.location5, size: 20, color: AvailColors.primary)),
                      title: const Text('Set location on map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Pick a spot manually', style: TextStyle(fontSize: 10)),
                      onTap: () {
                        Get.back(); // Close RouteSelectionScreen
                        homeController.enterMapSelectionMode(isSearchingPickup ? 'pickup' : 'destination', fromDispatch: false);
                      },
                    ),
                    const Divider(height: 1, indent: 70),
                    if (searchController.placePredictions.isEmpty) 
                      _buildEmptySearch()
                    else
                      ...searchController.placePredictions.map((prediction) => Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(backgroundColor: circleBg, child: Icon(Iconsax.radar, size: 20, color: dark ? Colors.white70 : AvailColors.secondary)),
                            title: Text(prediction['description'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(prediction['structured_formatting']?['secondary_text'] ?? 'Logistics Node', style: const TextStyle(fontSize: 10)),
                            onTap: () => _handleSelection(prediction),
                          ),
                          const Divider(height: 1, indent: 70),
                        ],
                      )).toList(),
                  ],
                );
              }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSelection(dynamic prediction) async {
    searchController.isLoading.value = true;
    final details = await searchController.getPlaceDetails(prediction['place_id']);
    
    if (details != null) {
      final name = prediction['description'];
      final pos = LatLng(details['lat']!, details['lng']!);

      if (isSearchingPickup) {
        homeController.setPickup(pos, name);
        if (homeController.destinationLocation.value == null) {
          setState(() { isSearchingPickup = false; isSearchingDestination = true; });
          destinationTextController.text = '';
          searchController.findPlaceAutocomplete('');
        } else {
          Get.back();
        }
      } else {
        homeController.setDestination(pos, name);
        Get.back();
      }
    }
    searchController.isLoading.value = false;
  }

  Widget _buildIndustrialInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isFocused,
    required VoidCallback onTap,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isFocused ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isFocused ? AvailColors.primary : Colors.white12),
          ),
          child: TextField(
            controller: controller,
            onTap: onTap,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: iconColor, size: 18),
              border: InputBorder.none,
              hintText: 'Enter location...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.radar, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text('SCANNING LOGISTICS NODES...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }
}
