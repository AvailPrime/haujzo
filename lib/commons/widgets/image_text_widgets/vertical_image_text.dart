import 'package:flutter/material.dart';

import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/helpers/helper_functions.dart';
import '../images/avail_circular_image.dart';


class AvailVerticalImageText extends StatelessWidget {
  const AvailVerticalImageText({
    super.key,
    required this.image,
    required this.title,
    this.textColor = AvailColors.black,
    this.backgroundColor,
    this.borderColor = AvailColors.grey,
    this.overlayColor,
    this.onTap,
    this.isNetworkImage = true,
  });

  final String image, title;
  final Color textColor;
  final Color? backgroundColor, borderColor, overlayColor;
  final bool isNetworkImage;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: AvailSizes.spacebtwitems),
        child: Column(
          children: [
            AvailCircularImage(
              width: 56,
              height: 56,
              image: image,
              fit: BoxFit.fill,
              padding: AvailSizes.sm,
              isNetworkImage: isNetworkImage,
              backgroundColor: backgroundColor,
              overlayColor: overlayColor ?? (dark ? AvailColors.light : AvailColors.dark),
              showBorder: true,
              borderColor: borderColor ?? AvailColors.grey,
            ),
            const SizedBox(height: AvailSizes.spacebtwitems / 2),
            SizedBox(
              width: 56,
              child: Center(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall!
                      .apply(color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
