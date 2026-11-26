import 'package:flutter/material.dart';

import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';

class AvailRoundedContainer extends StatelessWidget {
  const AvailRoundedContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.radius = AvailSizes.cardradiuslg,
    this.padding,
    this.margin,
    this.backgroundColor = AvailColors.white,
    this.showBorder = false,
    this.borderColor = AvailColors.borderprimary,
  });

  final Widget? child;
  final double? width;
  final double? height;
  final double radius;
  final bool showBorder;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: borderColor) : null,
      ),
      child: child,
    );
  }
}
