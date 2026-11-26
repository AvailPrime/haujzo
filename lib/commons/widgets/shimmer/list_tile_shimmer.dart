import './shimmer.dart';
import 'package:flutter/material.dart';

import '../../../utils/constants/sizes.dart';

class AvailListTileShimmer extends StatelessWidget {
  const AvailListTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const AvailShimmerEffect(width: 50, height: 50, radius: 50),
            const SizedBox(width: AvailSizes.spacebtwitems),
          ],
        ),
        Column(
          children: const [
            AvailShimmerEffect(width: 100, height: 15),
            SizedBox(width: AvailSizes.spacebtwitems/ 2),
            AvailShimmerEffect(width: 80, height: 12),
          ],
        ),
      ],
    );
  }
}
