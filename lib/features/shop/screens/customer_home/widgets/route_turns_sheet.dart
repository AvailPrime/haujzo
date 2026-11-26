import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:truck_booking/data/services/routing/smart_routing_engine.dart';
import 'package:truck_booking/utils/constants/colors.dart';
import 'package:truck_booking/utils/helpers/helper_functions.dart';

/// Modal bottom sheet displaying interactive turn-by-turn navigation steps
class RouteTurnsSheet extends StatelessWidget {
  const RouteTurnsSheet({
    super.key,
    required this.routeData,
  });

  final RouteDataModel routeData;

  @override
  Widget build(BuildContext context) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF131823) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AvailColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.routing, color: AvailColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Turn-by-Turn Guidance',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        '${routeData.distanceText} • ${routeData.durationText} • ${routeData.steps.length} Steps',
                        style: TextStyle(
                          fontSize: 12,
                          color: darkMode ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Iconsax.close_circle, size: 22),
                  color: Colors.grey,
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // Steps List
          Expanded(
            child: routeData.steps.isEmpty
                ? Center(
                    child: Text(
                      'No specific turn steps available for this corridor.',
                      style: TextStyle(
                        color: darkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: routeData.steps.length,
                    separatorBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(left: 38),
                      child: Container(
                        height: 18,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 2,
                          color: Colors.grey.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final step = routeData.steps[index];
                      final isFirst = index == 0;
                      final isLast = index == routeData.steps.length - 1;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Maneuver Icon
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isFirst
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : (isLast
                                      ? Colors.redAccent.withValues(alpha: 0.15)
                                      : (darkMode ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9))),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isFirst
                                    ? const Color(0xFF10B981)
                                    : (isLast ? Colors.redAccent : Colors.transparent),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              _getManeuverIcon(step.maneuver, isFirst, isLast),
                              size: 18,
                              color: isFirst
                                  ? const Color(0xFF10B981)
                                  : (isLast
                                      ? Colors.redAccent
                                      : (darkMode ? Colors.white70 : Colors.black87)),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Instruction Text & Distance
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.instruction,
                                  style: TextStyle(
                                    fontWeight: isFirst || isLast ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 13.5,
                                    color: darkMode ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (step.distanceText.isNotEmpty) ...[
                                      Icon(Iconsax.radar_2, size: 12, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        step.distanceText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AvailColors.primary,
                                        ),
                                      ),
                                    ],
                                    if (step.durationText.isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      Icon(Iconsax.clock, size: 12, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        step.durationText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Bottom Action
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AvailColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Return to Navigation Map',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getManeuverIcon(String maneuver, bool isFirst, bool isLast) {
    if (isFirst) return Iconsax.truck_fast;
    if (isLast) return Iconsax.location5;

    final m = maneuver.toLowerCase();
    if (m.contains('left')) return Iconsax.arrow_circle_left;
    if (m.contains('right')) return Iconsax.arrow_circle_right;
    if (m.contains('roundabout')) return Iconsax.refresh_circle;
    if (m.contains('merge') || m.contains('fork')) return Iconsax.convert;
    if (m.contains('u-turn')) return Iconsax.rotate_left;
    return Iconsax.arrow_circle_up;
  }
}
