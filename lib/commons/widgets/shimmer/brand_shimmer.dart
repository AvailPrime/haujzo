import './shimmer.dart';
import 'package:flutter/material.dart';

import '../layouts/grid_layout.dart';

class AvailBrandsShimmer extends StatelessWidget {
  const AvailBrandsShimmer({super.key, this.itemCount = 2});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AvailGridLayout(
      mainAxisExtend: 80,
      itemCount: itemCount,
      itemBuilder: (_, __) => const AvailShimmerEffect(width: 300, height: 80),
    );
    // TGridLayout
  }
}
