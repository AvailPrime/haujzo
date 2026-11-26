import './shimmer.dart';
import 'package:flutter/material.dart';

import '../../../utils/constants/sizes.dart';

class AvailHorizontalProductShimmer extends StatelessWidget {
  const AvailHorizontalProductShimmer({super.key});

  final int itemCount = 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AvailSizes.spacebtwitems),
      height: 120,
      child: ListView.separated(
        itemCount: itemCount,
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) => const SizedBox(width: AvailSizes.spacebtwitems),
        itemBuilder: (_, __) => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Image
            AvailShimmerEffect(width: 120, height: 120),
            SizedBox(width: AvailSizes.spacebtwitems),

            /// Text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: AvailSizes.spacebtwitems / 2),
                AvailShimmerEffect(width: 160, height: 15),
                SizedBox(height: AvailSizes.spacebtwitems / 2),
                AvailShimmerEffect(width: 110, height: 15),
                SizedBox(height: AvailSizes.spacebtwitems / 2),
                AvailShimmerEffect(width: 80, height: 15),
                Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
