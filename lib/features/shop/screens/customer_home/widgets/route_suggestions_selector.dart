import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:truck_booking/features/shop/controllers/customer/customer_home_controller.dart';
import 'package:truck_booking/utils/helpers/helper_functions.dart';

/// Interactive Google Maps style Route Suggestions & Live Traffic Condition Selector
/// Displays live traffic conditions, traffic delay badges, and alternative route choice chips.
class RouteSuggestionsSelector extends StatelessWidget {
  const RouteSuggestionsSelector({
    super.key,
    this.controller,
    this.isCompact = false,
  });

  final CustomerHomeController? controller;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? (Get.isRegistered<CustomerHomeController>()
        ? CustomerHomeController.instance
        : Get.find<CustomerHomeController>());
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return Obx(() {
      final routes = c.suggestedRoutes;
      if (routes.isEmpty) return const SizedBox.shrink();

      final selectedIdx = c.selectedRouteIndex.value.clamp(0, routes.length - 1);
      final activeRoute = routes[selectedIdx];
      final trafficColor = activeRoute.trafficStatusColor;
      final trafficText = c.trafficCondition.value.isNotEmpty
          ? c.trafficCondition.value
          : activeRoute.trafficStatus;

      return Container(
        margin: EdgeInsets.symmetric(
          horizontal: isCompact ? 0 : 16,
          vertical: isCompact ? 8 : 10,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: darkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: darkMode ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: darkMode ? 0.25 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row: Traffic Flow Status & Alternatives Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: trafficColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: trafficColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trafficText,
                      style: TextStyle(
                        color: trafficColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: darkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.route_square,
                        size: 11,
                        color: darkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${routes.length} Route${routes.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: darkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Route Alternatives Horizontal Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(routes.length, (i) {
                  final route = routes[i];
                  final isSelected = (i == selectedIdx);
                  final subText = isSelected
                      ? (i == 0 ? 'Fastest' : 'Active')
                      : (route.relativeDistanceText.isNotEmpty
                          ? route.relativeDistanceText
                          : '+${(route.trafficDelaySeconds / 60).round()}m');

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      onSelected: (_) => c.selectSuggestedRoute(i),
                      avatar: CircleAvatar(
                        radius: 4.5,
                        backgroundColor: isSelected ? Colors.white : route.trafficStatusColor,
                      ),
                      label: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${route.durationInTrafficText} • $subText',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? Colors.white
                                  : (darkMode ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${route.summary} (${route.distanceText})',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : (darkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                      selectedColor: const Color(0xFF0F172A),
                      backgroundColor: darkMode ? const Color(0xFF0F172A).withValues(alpha: 0.5) : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? route.trafficStatusColor
                            : (darkMode ? Colors.grey.shade800 : Colors.grey.shade300),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      );
    });
  }
}
