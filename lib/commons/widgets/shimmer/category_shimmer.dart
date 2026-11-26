import './shimmer.dart';
import 'package:flutter/material.dart';

import '../../../utils/constants/sizes.dart';

class AvailCategoryShimmer extends StatelessWidget {
  const AvailCategoryShimmer({
    super.key,
    this.itemCount = 6,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: itemCount,
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) => const SizedBox(width: AvailSizes.spacebtwitems),
        itemBuilder: (_, __) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Image
              AvailShimmerEffect(width: 55, height: 55, radius: 55),
              SizedBox(height: AvailSizes.spacebtwitems/2),

              /// Text
              AvailShimmerEffect(width: 55, height: 8),
            ]
          );
        },
      )
    );
  }
}
