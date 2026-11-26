import './shimmer.dart';
import 'package:flutter/material.dart';

import '../../../utils/constants/sizes.dart';

class AvailBoxesShimmer extends StatelessWidget {
  const AvailBoxesShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: AvailShimmerEffect(width: 150, height: 110)),
            SizedBox(width: AvailSizes.spacebtwitems),
            Expanded(child: AvailShimmerEffect(width: 150, height: 110)),
            SizedBox(width: AvailSizes.spacebtwitems),
            Expanded(child: AvailShimmerEffect(width: 150, height: 110)),
          ],
        ),
        // Row
        SizedBox(height: AvailSizes.spacebtwitems),
        // Column
      ],
    );
  }
}
