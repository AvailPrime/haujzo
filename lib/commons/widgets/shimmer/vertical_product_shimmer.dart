import './shimmer.dart';
import 'package:flutter/material.dart';

import '../../../utils/constants/sizes.dart';
import '../layouts/grid_layout.dart';


class AvailVerticalProductShimmer extends StatelessWidget {
  const AvailVerticalProductShimmer({
    super.key,
    this.itemCount = 4,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AvailGridLayout(
      itemCount: itemCount,
      itemBuilder: (_, __) => SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Image
            const AvailShimmerEffect(width: 180, height: 170),
            SizedBox(height: AvailSizes.spacebtwitems),

            /// Text
            const AvailShimmerEffect(width: 160, height: 15),
            const SizedBox(height: AvailSizes.spacebtwitems / 2),
            const AvailShimmerEffect(width: 110, height: 15),
            const SizedBox(height: AvailSizes.spacebtwitems / 2),
            const AvailShimmerEffect(width: 80, height: 12),
            const SizedBox(height: AvailSizes.spacebtwitems / 2),
            const AvailShimmerEffect(width: 100, height: 12),
          ],
        ),
      ),
    );
  }
}

