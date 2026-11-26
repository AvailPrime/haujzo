import '../../../utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';

import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';

class AvailCircularIcon extends StatelessWidget {
  const AvailCircularIcon({
    super.key,
    this.width,
    this.height,
    this.size = AvailSizes.lg,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.onPressed,
  });

  final double? width, height, size;
  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);

    return Container(
      alignment: Alignment.center,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: backgroundColor != null
            ? backgroundColor!
            : dark
                ? AvailColors.white.withValues(alpha: 0.12)
                : AvailColors.black.withValues(alpha: 0.08),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: color ?? (dark ? Colors.white : AvailColors.textPrimary),
          size: size,
        ),
      ),
    );
  }
}
