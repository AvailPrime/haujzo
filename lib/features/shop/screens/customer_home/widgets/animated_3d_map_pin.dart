import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truck_booking/features/shop/controllers/customer/customer_home_controller.dart';

class Animated3DMapPin extends StatefulWidget {
  final CustomerHomeController controller;

  const Animated3DMapPin({super.key, required this.controller});

  @override
  State<Animated3DMapPin> createState() => _Animated3DMapPinState();
}

class _Animated3DMapPinState extends State<Animated3DMapPin> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0.0, end: -9.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!widget.controller.isSelectingOnMap.value) return const SizedBox();

      final bool isPickup = widget.controller.selectingLocationType.value == 'pickup';
      final Color mainColor = isPickup ? const Color(0xFF2563EB) : const Color(0xFFEF4444);

      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 38),
          child: AnimatedBuilder(
            animation: _bounceAnim,
            builder: (context, child) {
              final bounce = _bounceAnim.value;
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Ground Shadow
                  Transform.translate(
                    offset: const Offset(0, 3),
                    child: Container(
                      width: 20 + (bounce * 0.3),
                      height: 7 + (bounce * 0.15),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                  ),

                  // Floating 3D Teardrop Pin
                  Transform.translate(
                    offset: Offset(0, bounce),
                    child: CustomPaint(
                      size: const Size(42, 54),
                      painter: Teardrop3DPinPainter(baseColor: mainColor, isPickup: isPickup),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    });
  }
}

class Teardrop3DPinPainter extends CustomPainter {
  final Color baseColor;
  final bool isPickup;

  Teardrop3DPinPainter({required this.baseColor, required this.isPickup});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double headR = 18.0;

    final Path teardropPath = Path();
    teardropPath.moveTo(cx, h);
    
    teardropPath.cubicTo(
      cx - headR * 1.35, h - headR * 1.5,
      cx - headR, headR * 0.4,
      cx - headR, headR,
    );
    
    teardropPath.arcTo(
      Rect.fromCircle(center: Offset(cx, headR), radius: headR),
      math.pi,
      math.pi,
      false,
    );

    teardropPath.cubicTo(
      cx + headR, headR * 0.4,
      cx + headR * 1.35, h - headR * 1.5,
      cx, h,
    );
    teardropPath.close();

    final Paint fillPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - 5, headR - 6),
        headR * 1.8,
        [
          Color.lerp(baseColor, Colors.white, 0.45)!,
          baseColor,
          Color.lerp(baseColor, Colors.black, 0.45)!,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawPath(teardropPath, fillPaint);

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawPath(teardropPath, strokePaint);

    final Paint sheenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(cx - headR + 3, headR - 8),
        Offset(cx, headR - headR + 4),
        [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
      );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, headR), radius: headR - 2.8),
      math.pi * 1.1,
      math.pi * 0.45,
      false,
      sheenPaint,
    );

    final Offset headCenter = Offset(cx, headR);
    final Paint emblemBgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(headCenter, 8.5, emblemBgPaint);

    final Paint dotPaint = Paint()..color = baseColor;
    canvas.drawCircle(headCenter, 4.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant Teardrop3DPinPainter oldDelegate) =>
      oldDelegate.baseColor != baseColor || oldDelegate.isPickup != isPickup;
}
