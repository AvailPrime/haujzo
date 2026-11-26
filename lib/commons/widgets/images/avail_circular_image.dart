import '../shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/helpers/helper_functions.dart';

class AvailCircularImage extends StatelessWidget {
  const AvailCircularImage({
    super.key,
    this.fit = BoxFit.cover,
    required this.image,
    this.isNetworkImage = false,
    this.overlayColor,
    this.backgroundColor,
    this.width = 56,
    this.height = 56,
    this.padding = AvailSizes.sm,
    this.applyImageRadius = false,
    this.borderRadius = 100,
    this.showBorder = true,
    this.borderColor = AvailColors.grey,
  });

  final BoxFit? fit;
  final String image;
  final bool isNetworkImage;
  final Color? overlayColor;
  final Color? backgroundColor;
  final bool applyImageRadius;
  final bool showBorder;
  final double width, height, padding;
  final double borderRadius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    return Container(
      height: height,
      width: width,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color:
            backgroundColor ?? (dark ? AvailColors.black : AvailColors.white),
        borderRadius: BorderRadius.circular(100),
          border: showBorder ? Border.all(color: borderColor) : null),
      child: ClipRRect(
        borderRadius: applyImageRadius
            ? BorderRadius.circular(borderRadius)
            : BorderRadius.zero,
        child: Center(
          child: (isNetworkImage || image.startsWith('http'))
              ? CachedNetworkImage(
            fit: fit,
            color: overlayColor,
            imageUrl: image,
            progressIndicatorBuilder: (context, url, downloadProgress) =>
            const AvailShimmerEffect(width: 55, height: 55, radius: 55),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          )
              : Image.asset(
            image,
            fit: fit,
            color: overlayColor,
          ),
        ),
      ),
    );
  }
}
