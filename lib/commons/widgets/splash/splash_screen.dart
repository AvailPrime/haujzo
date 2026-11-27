import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';
import '../images/app_logo.dart';

/// Reusable helper for managing native splash screen lifecycle
class AvailSplashHelper {
  /// Preserves the native OS splash screen until initialization finishes
  static void preserveSplash({required WidgetsBinding widgetsBinding}) {
    if (!kIsWeb) {
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    }
  }

  /// Removes the native OS splash screen once the initial Flutter screen is ready
  static void removeSplash() {
    if (!kIsWeb) {
      FlutterNativeSplash.remove();
    }
  }
}

/// Reusable In-App Splash Screen Widget
class AvailSplashScreen extends StatelessWidget {
  const AvailSplashScreen({
    super.key,
    this.backgroundColor,
    this.showIndicator = true,
    this.indicatorColor,
    this.logoSize = 180.0,
    this.footerText,
  });

  final Color? backgroundColor;
  final bool showIndicator;
  final Color? indicatorColor;
  final double logoSize;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white;
    final primaryColor = indicatorColor ?? AvailColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvailAppLogo.splash(
                    width: logoSize,
                  ),
                  if (showIndicator) ...[
                    const SizedBox(height: AvailSizes.spaceBtwSections),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.0,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (footerText != null)
              Positioned(
                bottom: AvailSizes.defaultSpace,
                left: 0,
                right: 0,
                child: Text(
                  footerText!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
