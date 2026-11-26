import 'package:flutter/material.dart';

import '../../../../utils/constants/colors.dart';
import '../curved_edges/curved_edges_widget.dart';
import 'circular_container.dart';

class AvailPrimaryHeaderContainer extends StatelessWidget {
  const AvailPrimaryHeaderContainer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AvailCurvedEdgesWidget(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1D35),
              Color(0xFF122F51),
              Color(0xFF1A3E6B),
            ],
          ),
        ),
        child: Stack(
          children: [
            /// -- Ambient Brand Glow Orbs
            Positioned(
              top: -120,
              right: -130,
              child: AvailCircularContainer(
                width: 320,
                height: 320,
                radius: 320,
                backgroundColor: AvailColors.primary.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              top: 70,
              right: -180,
              child: AvailCircularContainer(
                width: 300,
                height: 300,
                radius: 300,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -100,
              child: AvailCircularContainer(
                width: 220,
                height: 220,
                radius: 220,
                backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.08),
              ),
            ),

            /// -- Foreground content
            child,
          ],
        ),
      ),
    );
  }
}
