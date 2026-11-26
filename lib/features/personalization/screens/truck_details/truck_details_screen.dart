import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../../shop/controllers/customer/customer_home_controller.dart';
import '../../../shop/models/pricing_config_model.dart';
import '../../../shop/screens/customer_home/job_dispatch_screen.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../../routes/routes.dart';

class TruckDetailsScreen extends StatefulWidget {
  const TruckDetailsScreen({super.key});

  @override
  State<TruckDetailsScreen> createState() => _TruckDetailsScreenState();
}

class _TruckDetailsScreenState extends State<TruckDetailsScreen> {
  // 0 = Allowed / Active Trucks, 1 = Hidden / Inactive Trucks
  int _selectedFilterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final controller = Get.isRegistered<CustomerHomeController>()
        ? CustomerHomeController.instance
        : Get.put(CustomerHomeController());

    final bgColor = dark ? AvailColors.dark : const Color(0xFFF8FAFC);
    final cardColor = dark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = dark ? Colors.grey.shade400 : Colors.grey.shade700;

    final List<Map<String, dynamic>> allFleetSpecs = [
      {
        'name': 'Flatbed / Platform Truck',
        'category': 'ISO Container & Heavy Platform',
        'capacity': 'Max 30 Tons',
        'deck': '12.2m x 2.5m Flat Deck',
        'icon': Iconsax.truck,
        'badgeColor': AvailColors.primary,
        'compatibleCargo': '20ft, 40ft & Twin 20ft ISO Containers, Palletized Freight, Heavy Equipment',
        'description':
            'Equipped with heavy-duty twist locks and reinforced steel deck beds. Ideal for maritime container transfers and general break-bulk distribution.',
      },
      {
        'name': 'Heavy Duty / 30-Ton',
        'category': 'Articulated Multi-Axle Carrier',
        'capacity': 'Max 45 Tons',
        'deck': 'Heavy Lowbed / High-Payload Rig',
        'icon': Iconsax.truck_remove,
        'badgeColor': Colors.deepOrange,
        'compatibleCargo': 'Outsized Industrial Machinery, 40ft High Cube Containers, Heavy Rigging',
        'description':
            'Multi-axle prime movers engineered for oversized cargo, mining equipment, construction materials, and maximum road-legal payloads.',
      },
      {
        'name': 'Tipper / Dumper',
        'category': 'Hydraulic Bulk Cargo',
        'capacity': 'Max 20 Tons',
        'deck': '14 - 18 m³ High-Sided Steel Body',
        'icon': Iconsax.truck_tick,
        'badgeColor': Colors.amber.shade800,
        'compatibleCargo': 'Sand, Gravel, Aggregates, Bulk Agricultural Produce & Clinker',
        'description':
            'Hydraulic tipping mechanism for rapid offloading of loose materials, civil construction earthworks, and bulk industrial minerals.',
      },
      {
        'name': 'Refrigerated Truck',
        'category': 'Cold Chain Temperature-Controlled',
        'capacity': 'Max 15 Tons',
        'deck': 'Insulated Polyurethane Box (-20°C to +15°C)',
        'icon': Icons.ac_unit,
        'badgeColor': Colors.cyan.shade700,
        'compatibleCargo': 'Pharmaceuticals, Frozen Poultry, Fresh Produce, Dairy & Confectionery',
        'description':
            'Equipped with active Thermo King cooling units and continuous temperature monitoring to ensure food and medical safety during transit.',
      },
      {
        'name': 'Pickup / Mini Truck',
        'category': 'Urban Last-Mile Logistics',
        'capacity': 'Max 2 Tons',
        'deck': 'Open Utility Bed or Box Enclosure',
        'icon': Iconsax.truck_fast,
        'badgeColor': Colors.blue,
        'compatibleCargo': 'Retail Parcels, Office Equipment, Small Pallets & Fast Urban Delivery',
        'description':
            'Agile light commercial vehicle suited for congested inner-city corridors, rapid emergency deliveries, and light warehouse transfers.',
      },
    ];

    final isWide = SiteLayout.isWideScreen(context);
    final isEmbedded = isWide && !Navigator.canPop(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isEmbedded
          ? null
          : const AvailAppbar(
              title: Text(
                'Fleet & Truck Specifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
              ),
              showBackArrow: true,
              showBackgroundColor: true,
              backArrowColor: Colors.white,
            ),
      body: Obx(() {
        final pricing = controller.pricingConfig.value;
        final rates = pricing.truckRates;

        // Check each fleet specification against platform pricing configuration
        final allowedFleetSpecs = allFleetSpecs.where((truck) {
          final name = truck['name'] as String;
          if (rates.containsKey(name)) {
            return rates[name]!.isActive;
          }
          if (name == 'Flatbed / Platform Truck' && rates.containsKey('Flatbed / Container')) {
            return rates['Flatbed / Container']!.isActive;
          }
          return false;
        }).toList();

        final hiddenFleetSpecs = allFleetSpecs.where((truck) {
          final name = truck['name'] as String;
          if (rates.containsKey(name)) {
            return !rates[name]!.isActive;
          }
          if (name == 'Flatbed / Platform Truck' && rates.containsKey('Flatbed / Container')) {
            return !rates['Flatbed / Container']!.isActive;
          }
          return true;
        }).toList();

        // If currently viewing allowed trucks, display allowedFleetSpecs (hidden trucks are hidden).
        // If viewing hidden trucks, display hiddenFleetSpecs.
        final displayedTrucks = _selectedFilterIndex == 0 ? allowedFleetSpecs : hiddenFleetSpecs;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 16,
            vertical: 18,
          ),
          child: ResponsiveCenter(
            maxWidth: 1160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // 1. Hero Overview Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AvailColors.navyGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AvailColors.secondary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AvailColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.truck_fast, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Haujzo Commercial Fleet',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Verified Commercial Road Haulage Units',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Every truck matched through Haujzo holds a valid roadworthiness certificate, commercial motor insurance, and a verified driver registered on Haujzo Pro. Below you can inspect active trucks allowed for booking as well as inactive categories currently hidden from dispatch.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Allowed vs Hidden Filter Segmented Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  // Allowed Tab
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _selectedFilterIndex = 0;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFilterIndex == 0
                              ? AvailColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedFilterIndex == 0
                              ? [
                                  BoxShadow(
                                    color: AvailColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.tick_circle,
                              size: 16,
                              color: _selectedFilterIndex == 0 ? Colors.white : bodyColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Allowed (${allowedFleetSpecs.length})',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _selectedFilterIndex == 0 ? Colors.white : bodyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Hidden Tab
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _selectedFilterIndex = 1;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFilterIndex == 1
                              ? (dark ? const Color(0xFF334155) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedFilterIndex == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.eye_slash,
                              size: 16,
                              color: _selectedFilterIndex == 1
                                  ? (dark ? Colors.white : Colors.black87)
                                  : bodyColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Hidden (${hiddenFleetSpecs.length})',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _selectedFilterIndex == 1
                                  ? (dark ? Colors.white : Colors.black87)
                                  : bodyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Section Subheading with status badge
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedFilterIndex == 0 ? Iconsax.category : Iconsax.eye_slash,
                        size: 16,
                        color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedFilterIndex == 0 ? 'ALLOWED TRUCK CATEGORIES' : 'HIDDEN TRUCK CATEGORIES',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _selectedFilterIndex == 0
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _selectedFilterIndex == 0
                          ? '${allowedFleetSpecs.length} Active & Bookable'
                          : '${hiddenFleetSpecs.length} Inactive & Hidden',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _selectedFilterIndex == 0 ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Truck Specification Cards
            if (displayedTrucks.isEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedFilterIndex == 0 ? Iconsax.info_circle : Iconsax.tick_circle,
                        size: 36,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedFilterIndex == 0
                          ? 'No Active Trucks Configured'
                          : 'No Hidden Trucks',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedFilterIndex == 0
                          ? 'All truck categories are currently hidden or undergoing route corridor maintenance. Please check back shortly.'
                          : 'All 5 platform truck categories are currently allowed and active for customer booking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: bodyColor, height: 1.4),
                    ),
                  ],
                ),
              ),
            ] else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 820 ? 2 : 1;
                  if (cols == 1) {
                    return Column(
                      children: displayedTrucks.map((truck) => _buildTruckCard(controller, truck, rates, dark, cardColor, borderColor, titleColor, bodyColor)).toList(),
                    );
                  }
                  final rows = <Widget>[];
                  for (var i = 0; i < displayedTrucks.length; i += 2) {
                    rows.add(
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTruckCard(controller, displayedTrucks[i], rates, dark, cardColor, borderColor, titleColor, bodyColor)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: i + 1 < displayedTrucks.length
                                ? _buildTruckCard(controller, displayedTrucks[i + 1], rates, dark, cardColor, borderColor, titleColor, bodyColor)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(children: rows);
                },
              ),
            ],

            // 5. Informational banner when viewing Allowed tab about hidden categories
            if (_selectedFilterIndex == 0 && hiddenFleetSpecs.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilterIndex = 1;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.eye_slash, size: 16, color: Colors.orange),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${hiddenFleetSpecs.length} Truck Categories Currently Hidden',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            Text(
                              'Dormant in platform dispatch configuration. Tap to view specifications.',
                              style: TextStyle(fontSize: 10.5, color: bodyColor),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTruckCard(
    CustomerHomeController controller,
    Map<String, dynamic> truck,
    Map<String, TruckRateConfig> rates,
    bool dark,
    Color cardColor,
    Color borderColor,
    Color titleColor,
    Color bodyColor,
  ) {
                final isAllowed = _selectedFilterIndex == 0;
                final Color badgeCol = isAllowed
                    ? (truck['badgeColor'] as Color)
                    : (dark ? Colors.grey.shade600 : Colors.grey.shade500);

                final String truckName = truck['name'] as String;
                final TruckRateConfig? rateConfig = rates[truckName] ??
                    (truckName == 'Flatbed / Platform Truck' ? rates['Flatbed / Container'] : null);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isAllowed ? borderColor : (dark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status & Category Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: badgeCol.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(truck['icon'] as IconData, color: badgeCol, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          truckName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14.5,
                                            color: isAllowed ? titleColor : (dark ? Colors.grey.shade400 : Colors.grey.shade600),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    truck['category'] as String,
                                    style: TextStyle(fontSize: 11.5, color: bodyColor),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeCol.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: badgeCol.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                truck['capacity'] as String,
                                style: TextStyle(color: badgeCol, fontSize: 10.5, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),

                        // Allowed vs Hidden status pill banner
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isAllowed
                                ? Colors.green.withValues(alpha: 0.08)
                                : Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAllowed
                                  ? Colors.green.withValues(alpha: 0.25)
                                  : Colors.orange.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAllowed ? Iconsax.tick_circle : Iconsax.eye_slash,
                                size: 13,
                                color: isAllowed ? Colors.green.shade700 : Colors.orange.shade800,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isAllowed ? 'ALLOWED FOR BOOKING' : 'HIDDEN FROM BOOKING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isAllowed ? Colors.green.shade700 : Colors.orange.shade800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Description
                        Text(
                          truck['description'] as String,
                          style: TextStyle(fontSize: 12, color: bodyColor, height: 1.4),
                        ),

                        // Rate summary if available
                        if (rateConfig != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: dark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Iconsax.dollar_circle, size: 14, color: isAllowed ? AvailColors.primary : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Base: GH₵ ${rateConfig.baseFare.toStringAsFixed(0)} (first ${rateConfig.includedDistanceKm.toStringAsFixed(0)} km)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: titleColor),
                                ),
                                const Spacer(),
                                Text(
                                  'GH₵ ${rateConfig.perKmRate.toStringAsFixed(2)} / km',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAllowed ? AvailColors.primary : bodyColor),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        Divider(height: 1, color: borderColor),
                        const SizedBox(height: 10),

                        // Dimension / Specs Row
                        Row(
                          children: [
                            const Icon(Iconsax.ruler, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Deck Specs: ',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            Expanded(
                              child: Text(
                                truck['deck'] as String,
                                style: TextStyle(fontSize: 11, color: bodyColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Iconsax.box_1, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Compatible Cargo: ',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            Expanded(
                              child: Text(
                                truck['compatibleCargo'] as String,
                                style: TextStyle(fontSize: 11, color: bodyColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Action button
                        if (isAllowed) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                controller.updateTruckType(truckName);
                                if (Get.isRegistered<NavigationController>()) {
                                  NavigationController.instance.openSubScreen(
                                    const JobDispatchScreen(),
                                    title: 'Cargo Job Dispatch',
                                  );
                                } else {
                                  Get.toNamed(AvailRoutes.jobDispatch);
                                }
                              },
                              icon: Icon(Iconsax.send_2, size: 16, color: badgeCol),
                              label: Text(
                                'Dispatch with ${truckName.split(' / ')[0]}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeCol),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: badgeCol.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.lock, size: 15, color: bodyColor),
                                const SizedBox(width: 6),
                                Text(
                                  'Currently Hidden by Dispatch Management',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: bodyColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
  }
}
