import 'package:flutter/material.dart';

import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/device/device_utility.dart';
import '../../../../utils/helpers/helper_functions.dart';

class AvailSearchContainer extends StatelessWidget {
  const AvailSearchContainer({
    super.key,
    required this.text,
    this.icon = Icons.search,
    this.showBackground = true,
    this.showBorder = true,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: AvailSizes.xxxs),
  });

  final String text;
  final IconData? icon;
  final bool showBackground, showBorder;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Container(
          height: 40,
          width: AvailDeviceUtils.getScreenWidth(context) * 0.77,
          padding: const EdgeInsets.fromLTRB(AvailSizes.sm, 0, 0, 0),
          decoration: BoxDecoration(
              color: showBackground
                  ? dark
                      ? AvailColors.black
                      : AvailColors.light
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AvailSizes.cardradiussm),
              border: showBorder ? Border.all(color: AvailColors.grey) : null),
          child: Padding(
            padding: const EdgeInsets.all(AvailSizes.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: !showBackground ? AvailColors.white : AvailColors.dark,
                      ),
                ),
                Icon(
                  icon,
                  color: !showBackground ? AvailColors.white : AvailColors.dark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
