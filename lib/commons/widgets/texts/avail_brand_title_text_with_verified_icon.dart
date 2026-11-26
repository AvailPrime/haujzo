import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../utils/constants/colors.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/constants/sizes.dart';
import 'avail_brand_title_text.dart';

class AvailBrandTitleWithVerifiedIcon extends StatelessWidget {
  const AvailBrandTitleWithVerifiedIcon({
    super.key,
    required this.title,
    this.maxLines = 1,
    this.textColor,
    this.iconColor = AvailColors.primary,
    this.textAlign = TextAlign.center,
    this.brandTextSize = TextSizes.small,
  });

  final String title;
  final int maxLines;
  final Color? textColor, iconColor;
  final TextAlign? textAlign;
  final TextSizes brandTextSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: textAlign == TextAlign.left ? MainAxisAlignment.start : textAlign == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AvailSizes.xs, vertical: AvailSizes.xxxs),
          decoration: BoxDecoration(
            color: AvailColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AvailSizes.xxs),
            border: Border.all(color: AvailColors.primary.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                  child: AvailBrandTitleText(
                    title: title,
                    color: textColor,
                    maxLines: maxLines,
                    textAlign: textAlign,
                    brandTextSize: brandTextSize,
                  )),
              const SizedBox(width: AvailSizes.xs),
              Icon(Iconsax.verify5,
                  color: iconColor, size: AvailSizes.iconxs),
            ],
          ),
        ),
      ],
    );
  }
}
