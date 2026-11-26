import 'package:flutter/material.dart';

import '../../../utils/constants/sizes.dart';


class AvailCarouselLayout extends StatelessWidget {
  const AvailCarouselLayout({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 200,
    this.width = 100,
  });

  final int itemCount;
  final double height, width;
  final Widget Function(BuildContext, int) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width, // ✅ important for horizontal scroll
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: AvailSizes.gridviewspacing,
            ),
            child: itemBuilder(context, index),
          );
        },
      ),
    );
  }
}
