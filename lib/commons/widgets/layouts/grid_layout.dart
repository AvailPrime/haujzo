import 'package:flutter/material.dart';

import '../../../utils/constants/sizes.dart';

class AvailGridLayout extends StatelessWidget {
  const AvailGridLayout({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.mainAxisExtend,
    this.crossAxisCount,
  });

  final int itemCount;
  final int? crossAxisCount;
  final double? mainAxisExtend;
  final Widget? Function(BuildContext, int) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive cross axis count if not provided
        int count = crossAxisCount ?? 2;
        if (crossAxisCount == null) {
          if (constraints.maxWidth >= 1100) {
            count = 5;
          } else if (constraints.maxWidth >= 800) {
            count = 4;
          } else if (constraints.maxWidth >= 600) {
            count = 3;
          }
        }

        return GridView.builder(
          itemCount: itemCount,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: AvailSizes.xs,
            crossAxisSpacing: AvailSizes.xs,
            mainAxisExtent: mainAxisExtend ?? (constraints.maxWidth >= 1100 ? 300 : constraints.maxWidth > 600 ? 280 : 270),
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
