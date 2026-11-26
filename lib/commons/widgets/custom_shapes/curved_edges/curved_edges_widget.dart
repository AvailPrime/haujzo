import 'package:flutter/material.dart';

import 'curved_edges.dart';

class AvailCurvedEdgesWidget extends StatelessWidget {
  const AvailCurvedEdgesWidget({
    super.key, this.child,
  });

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: AvailCustomCurvedEdges(),
      child: child,
    );
  }
}
