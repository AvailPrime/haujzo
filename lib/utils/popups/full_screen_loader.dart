import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../commons/widgets/loader/loaders.dart';
import '../../features/personalization/controllers/localization_controller.dart';
import '../constants/colors.dart';
import '../constants/sizes.dart';
import '../helpers/helper_functions.dart';

/// A Utility class for managing a full screen dialog loading
class AvailFullScreenLoader {
  static bool _isLoading = false;
  static Timer? _autoTimeoutTimer;

  static void _startAutoTimeout([VoidCallback? onCancel]) {
    _autoTimeoutTimer?.cancel();
    _autoTimeoutTimer = Timer(const Duration(seconds: 90), () {
      if (_isLoading) {
        stopLoading();
        onCancel?.call();
        AvailLoaders.warningSnackBar(
          title: 'Connection Timeout',
          message: 'Request took too long to complete. Please check your payment status or try again.',
        );
      }
    });
  }

  /// Open a full-screen loading dialog with a given text.
  static void openLoadingDialog(String text, [String? _]) {
    _open(text);
  }

  /// Compatibility method for existing code calling openDialog
  static void openDialog(String text) {
    _open(text);
  }

  static void _open(String text) {
    if (Get.overlayContext == null) return;
    if (_isLoading) {
      stopLoading();
    }
    _isLoading = true;

    showDialog(
      context: Get.overlayContext!,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Container(
          color: AvailColors.secondary.withValues(alpha: 0.8),
          height: double.infinity,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AvailColors.primary),
              const SizedBox(height: 20),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open a high-end Paystack payment loading dialog
  static void openCheckoutLoading(
    double amount, {
    String amountLabel = 'Trip Fare:',
    String? subTitle,
    Future<void> Function()? onManualVerify,
    VoidCallback? onCancel,
  }) {
    if (Get.overlayContext == null) return;

    if (_isLoading) {
      stopLoading();
    }
    _isLoading = true;
    _startAutoTimeout(onCancel);

    final isDark = Get.context != null && AvailHelperFunctions.isDarkMode(Get.context!);

    showDialog(
      context: Get.overlayContext!,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.45),
                ),
              ),
              Center(
                child: Container(
                  width: 315,
                  padding: const EdgeInsets.all(AvailSizes.lg),
                  decoration: BoxDecoration(
                    color: isDark ? AvailColors.dark : AvailColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AvailSizes.md),
                        decoration: BoxDecoration(
                          color: AvailColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.shield_tick5,
                          color: AvailColors.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: AvailSizes.md),
                      Text(
                        'Secure Paystack Processing',
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AvailSizes.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AvailColors.darkergrey.withValues(alpha: 0.5)
                              : AvailColors.grey.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              amountLabel,
                              style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: AvailColors.darkgrey),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              LocalizationController.instance.getFormattedPrice(amount),
                              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AvailSizes.md),
                      Text(
                        subTitle ?? 'Verifying your payment connection with Paystack. Please do not close the app.',
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AvailColors.darkgrey),
                      ),
                      const SizedBox(height: AvailSizes.md),
                      Column(
                        children: [
                          _buildSecurityStep(ctx, Iconsax.lock, 'End-to-End Encryption'),
                          const SizedBox(height: 8),
                          _buildSecurityStep(ctx, Iconsax.activity, 'Verifying Paystack Gateway...'),
                          const SizedBox(height: 8),
                          _buildSecurityStep(ctx, Iconsax.shield_search, 'Fraud Protection Active'),
                        ],
                      ),
                      const SizedBox(height: AvailSizes.spaceBtwItems),
                      const SizedBox(
                        height: 36,
                        width: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AvailColors.primary),
                        ),
                      ),
                      const SizedBox(height: AvailSizes.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_user, size: 14, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            'PCI-DSS COMPLIANT',
                            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  fontSize: 9,
                                ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.security, size: 14, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            '256-BIT SSL',
                            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  fontSize: 9,
                                ),
                          ),
                        ],
                      ),
                      if (onManualVerify != null) ...[
                        const SizedBox(height: AvailSizes.md),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await onManualVerify();
                            },
                            icon: const Icon(Iconsax.refresh, size: 16, color: Colors.white),
                            label: const Text(
                              'I Have Paid / Verify Payment',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AvailColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AvailSizes.xs),
                      TextButton.icon(
                        onPressed: () {
                          stopLoading();
                          onCancel?.call();
                        },
                        icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                        label: const Text(
                          'Cancel Processing',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSecurityStep(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.green.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AvailColors.darkgrey),
        ),
        const Spacer(),
        const Icon(Icons.check, size: 14, color: Colors.green),
      ],
    );
  }

  /// Stop the currently opened loading dialog.
  static void stopLoading() {
    _autoTimeoutTimer?.cancel();
    if (_isLoading) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      } else if (Get.overlayContext != null && Navigator.of(Get.overlayContext!, rootNavigator: true).canPop()) {
        Navigator.of(Get.overlayContext!, rootNavigator: true).pop();
      }
      _isLoading = false;
      return;
    }

    if (Get.overlayContext != null && Navigator.of(Get.overlayContext!).canPop()) {
      Navigator.of(Get.overlayContext!).pop();
    }
  }

  static bool isLoading() => _isLoading;
}
