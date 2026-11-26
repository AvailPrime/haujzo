import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../constants/colors.dart';
import '../constants/image_strings.dart';

/// Reusable Image helper functions and builder methods, modeled after Haujzo Logistics specifications
class AvailImageFunctions {
  AvailImageFunctions._();

  /// Builds a responsive, contained App Logo with a graceful fallback error builder
  static Widget buildAppLogo({
    double? width = 260,
    double? height,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
    double scale = 1.0,
    Widget? fallback,
    String? customPath,
  }) {
    Widget image = Image.asset(
      customPath ?? AvailImages.appLogo,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          fallback ??
          const Icon(
            Iconsax.truck_fast,
            size: 48,
            color: AvailColors.primary,
          ),
    );

    if (scale != 1.0) {
      image = Transform.scale(
        scale: scale,
        alignment: alignment,
        child: image,
      );
    }

    return image;
  }

  /// Builds the authentication header logo (login, signup) with clean left-alignment
  static Widget buildAuthHeaderLogo({
    double width = 260,
    double scale = 1.3,
  }) {
    return buildAppLogo(
      width: width,
      scale: scale,
      alignment: Alignment.centerLeft,
    );
  }

  /// Builds a centered, balanced splash logo with proper proportions matching driver app
  static Widget buildSplashLogo({
    double? width = 280,
    double scale = 1.0,
  }) {
    return buildAppLogo(
      customPath: AvailImages.launchLogo,
      width: width,
      scale: scale,
      alignment: Alignment.center,
    );
  }

  /// Builds a small, contained app bar / badge logo
  static Widget buildAppBarLogo({
    double width = 110,
    double height = 36,
  }) {
    return buildAppLogo(
      width: width,
      height: height,
      scale: 1.0,
      alignment: Alignment.centerLeft,
    );
  }
}
