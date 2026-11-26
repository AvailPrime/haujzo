import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:truck_booking/data/services/routing/smart_routing_engine.dart';
import 'package:truck_booking/utils/constants/colors.dart';
import 'package:truck_booking/utils/helpers/helper_functions.dart';
import 'route_turns_sheet.dart';

/// Floating, high-tech glassmorphic route telemetry card with Compact & Expanded modes
/// Compact mode takes minimal vertical space (~46dp) leaving 85%+ of the map completely unobstructed.
class RouteTelemetryHUD extends StatefulWidget {
  const RouteTelemetryHUD({
    super.key,
    required this.routeData,
    required this.onClearRoute,
    required this.onRecenter,
    required this.onReverseRoute,
    this.suggestedRoutes = const [],
    this.selectedRouteIndex = 0,
    this.onSelectRoute,
    this.initiallyCompact = false,
  });

  final RouteDataModel routeData;
  final VoidCallback onClearRoute;
  final VoidCallback onRecenter;
  final VoidCallback onReverseRoute;
  final List<RouteDataModel> suggestedRoutes;
  final int selectedRouteIndex;
  final ValueChanged<int>? onSelectRoute;
  final bool initiallyCompact;

  @override
  State<RouteTelemetryHUD> createState() => _RouteTelemetryHUDState();
}

class _RouteTelemetryHUDState extends State<RouteTelemetryHUD> {
  late bool _isCompact;

  @override
  void initState() {
    super.initState();
    _isCompact = widget.initiallyCompact;
  }

  @override
  void didUpdateWidget(covariant RouteTelemetryHUD oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.suggestedRoutes.length != oldWidget.suggestedRoutes.length ||
        widget.routeData.summary != oldWidget.routeData.summary) {
      if (widget.suggestedRoutes.length > 1) {
        _isCompact = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    // Calculate arrival clock time
    final arrivalTime = DateTime.now().add(Duration(minutes: widget.routeData.durationMinutes));
    final arrivalString =
        '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}';

    final bgCardColor = darkMode
        ? const Color(0xFF0F172A).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.96);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bgCardColor,
        borderRadius: BorderRadius.circular(_isCompact ? 24 : 18),
        border: Border.all(
          color: darkMode
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: darkMode ? 0.35 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_isCompact ? 24 : 18),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _isCompact ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: _buildCompactBar(context, darkMode, arrivalString),
          secondChild: _buildExpandedCard(context, darkMode, arrivalString),
        ),
      ),
    );
  }

  /// Ultra-compact 46dp high-density bar keeping the map expansive
  Widget _buildCompactBar(BuildContext context, bool darkMode, String arrivalString) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Live Traffic Status Indicator Dot
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.routeData.trafficStatusColor,
              boxShadow: [
                BoxShadow(
                  color: widget.routeData.trafficStatusColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Duration & ETA
          GestureDetector(
            onTap: () => setState(() => _isCompact = false),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.routeData.durationText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($arrivalString)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.routeData.trafficStatusColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(width: 8),

          // Distance
          Text(
            widget.routeData.distanceText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AvailColors.primary,
            ),
          ),

          if (widget.suggestedRoutes.length > 1) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => setState(() => _isCompact = false),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (widget.selectedRouteIndex == 0 ? const Color(0xFF10B981) : AvailColors.primary)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.selectedRouteIndex == 0 ? 'Shortest' : 'Alt ${widget.selectedRouteIndex + 1}/${widget.suggestedRoutes.length}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: widget.selectedRouteIndex == 0 ? const Color(0xFF10B981) : AvailColors.primary,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 12, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],

          const Spacer(),

          // Turns Button
          InkWell(
            onTap: () {
              Get.bottomSheet(
                RouteTurnsSheet(routeData: widget.routeData),
                isScrollControlled: true,
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AvailColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.routing, size: 13, color: AvailColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.routeData.steps.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AvailColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Expand Toggle Button
          GestureDetector(
            onTap: () => setState(() => _isCompact = false),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
            ),
          ),

          const SizedBox(width: 4),

          // Close Route Button
          GestureDetector(
            onTap: widget.onClearRoute,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.close_circle, size: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// Full rich telemetry dashboard
  Widget _buildExpandedCard(BuildContext context, bool darkMode, String arrivalString) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Status Bar: Source Badge & Route Corridor
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: darkMode
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            border: Border(
              bottom: BorderSide(
                color: darkMode ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Source Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.routeData.sourceBadgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.routeData.sourceBadgeColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.routeData.sourceBadgeColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.routeData.sourceBadgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: widget.routeData.sourceBadgeColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Route Corridor Summary
              Expanded(
                child: Text(
                  widget.routeData.summary.isNotEmpty ? widget.routeData.summary : 'Freight Transit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: darkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Collapse to Mini Bar Toggle
              GestureDetector(
                onTap: () => setState(() => _isCompact = true),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.keyboard_arrow_up, size: 16, color: Colors.grey),
                ),
              ),

              const SizedBox(width: 6),

              // Close Route Action
              GestureDetector(
                onTap: widget.onClearRoute,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.close_circle, size: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),

        // Middle Telemetry: Duration, Arrival, Live Traffic Status & Distance
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Left: Big ETA & Live Traffic Condition Tag
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.routeData.durationText,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '($arrivalString ETA)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.routeData.trafficStatusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.routeData.trafficStatusColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.routeData.trafficStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.routeData.trafficStatusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right: Distance & Logistics Info
              Expanded(
                flex: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.routeData.distanceText,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AvailColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.routeData.waypoints.isEmpty
                              ? 'Direct Highway'
                              : '${widget.routeData.waypoints.length} Multi-Stop',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: darkMode ? Colors.grey[400] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AvailColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.truck_fast, color: AvailColors.primary, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Suggested Route Alternatives Carousel Selector (Shortest route default)
        _buildSuggestedRoutesSelector(context, darkMode),

        // Bottom Actions Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: darkMode
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFFF8FAFC),
            border: Border(
              top: BorderSide(
                color: darkMode ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Turn-by-Turn Guidance Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    Get.bottomSheet(
                      RouteTurnsSheet(routeData: widget.routeData),
                      isScrollControlled: true,
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AvailColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.routing, size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Turns (${widget.routeData.steps.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Recenter / Fit Route Bounds Button
              IconButton(
                onPressed: widget.onRecenter,
                icon: const Icon(Iconsax.scan, size: 17),
                tooltip: 'Fit Route in View',
                style: IconButton.styleFrom(
                  backgroundColor: darkMode ? Colors.white12 : Colors.grey.shade200,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(7),
                ),
              ),

              const SizedBox(width: 6),

              // Reverse Route Button
              IconButton(
                onPressed: widget.onReverseRoute,
                icon: const Icon(Iconsax.arrow_swap_horizontal, size: 17),
                tooltip: 'Reverse Route Directions',
                style: IconButton.styleFrom(
                  backgroundColor: darkMode ? Colors.white12 : Colors.grey.shade200,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// High-Tech Suggested Route Alternatives Selector
  /// Focuses and highlights the Shortest Route with distinctive green badge
  Widget _buildSuggestedRoutesSelector(BuildContext context, bool darkMode) {
    if (widget.suggestedRoutes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: darkMode
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF1F5F9).withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: darkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: darkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.route_square,
                size: 13,
                color: darkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 5),
              Text(
                'SUGGESTED ROUTES (${widget.suggestedRoutes.length})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: darkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                'Tap route or line on map',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: darkMode ? Colors.grey[500] : Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(widget.suggestedRoutes.length, (i) {
                final r = widget.suggestedRoutes[i];
                final isSelected = (i == widget.selectedRouteIndex);
                final bool isShortest = r.isShortest || i == 0;

                final String tagText = isShortest
                    ? 'Shortest'
                    : (r.relativeDistanceText.isNotEmpty
                        ? r.relativeDistanceText
                        : '+${(r.distanceKm - widget.suggestedRoutes[0].distanceKm).toStringAsFixed(1)} km');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (widget.onSelectRoute != null) {
                        widget.onSelectRoute!(i);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (darkMode ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
                            : (darkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? (isShortest ? const Color(0xFF10B981) : AvailColors.primary)
                              : (darkMode ? Colors.white12 : Colors.grey.shade300),
                          width: isSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (isShortest ? const Color(0xFF10B981) : AvailColors.primary)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Traffic / Shortest indicator dot
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isShortest ? const Color(0xFF10B981) : r.trafficStatusColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r.summary.isNotEmpty ? r.summary : 'Route Option ${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : (darkMode ? Colors.white : Colors.black87),
                                    ),
                                    maxLines: 1,
                                  ),
                                  if (isShortest) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'SHORTEST',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF10B981),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${r.distanceText} ($tagText) • ${r.durationText}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected
                                      ? (isShortest ? const Color(0xFF34D399) : const Color(0xFF93C5FD))
                                      : (darkMode ? Colors.grey[400] : Colors.grey[600]),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
