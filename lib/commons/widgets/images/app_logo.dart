import 'package:flutter/material.dart';
import '../../../utils/constants/image_strings.dart';
import '../../../utils/helpers/image_functions.dart';

/// Reusable App Logo widget delegating to [AvailImageFunctions]
class AvailAppLogo extends StatelessWidget {
  const AvailAppLogo({
    super.key,
    this.width = 260,
    this.height,
    this.fit = BoxFit.contain,
    this.scale = 1.0,
    this.alignment = Alignment.center,
    this.customPath,
  });

  /// Factory for auth screens (login, signup) with clean left alignment
  factory AvailAppLogo.authHeader({
    Key? key,
    double width = 160,
    double? height = 52,
    double scale = 1.15,
  }) =>
      AvailAppLogo(
        key: key,
        width: width,
        height: height,
        scale: scale,
        alignment: Alignment.centerLeft,
      );

  /// Factory for splash screen with centered balance, using dedicated cropped launch logo
  factory AvailAppLogo.splash({Key? key, double? width = 280, double scale = 1.0, String? customPath}) =>
      AvailAppLogo(
        key: key,
        width: width,
        scale: scale,
        alignment: Alignment.center,
        customPath: customPath ?? AvailImages.launchLogo,
      );

  /// Factory for a compact app bar logo
  factory AvailAppLogo.appBar({Key? key, double width = 135, double height = 36}) => AvailAppLogo(
        key: key,
        width: width,
        height: height,
        scale: 1.0,
        alignment: Alignment.centerLeft,
      );

  final double? width;
  final double? height;
  final BoxFit fit;
  final double scale;
  final Alignment alignment;
  final String? customPath;

  @override
  Widget build(BuildContext context) {
    return AvailImageFunctions.buildAppLogo(
      width: width,
      height: height,
      fit: fit,
      scale: scale,
      alignment: alignment,
      customPath: customPath,
    );
  }
}
