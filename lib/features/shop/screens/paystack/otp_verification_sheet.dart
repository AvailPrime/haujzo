import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_functions.dart';

class AvailOtpVerificationSheet extends StatefulWidget {
  const AvailOtpVerificationSheet({super.key});

  @override
  State<AvailOtpVerificationSheet> createState() => _AvailOtpVerificationSheetState();
}

class _AvailOtpVerificationSheetState extends State<AvailOtpVerificationSheet> {
  final TextEditingController _otpController = TextEditingController();
  int _secondsRemaining = 120;
  Timer? _timer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        _timer?.cancel();
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    if (mounted) {
      _otpController.clear();
      Get.back();
      Get.snackbar(
        'Timed Out',
        'Verification period expired. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.85),
        colorText: Colors.white,
      );
    }
  }

  String _getFormattedTime() {
    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.clear();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AvailHelperFunctions.isDarkMode(context);

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          left: AvailSizes.lg,
          right: AvailSizes.lg,
          top: AvailSizes.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).viewPadding.bottom +
              AvailSizes.lg,
        ),
        decoration: BoxDecoration(
          color: isDark ? AvailColors.dark : AvailColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: AvailSizes.md),
            const Icon(Iconsax.shield_security, color: AvailColors.primary, size: 48),
            const SizedBox(height: AvailSizes.sm),
            Text(
              'Authorize Trip Payment',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AvailSizes.xs),
            Text(
              'Enter the 6-digit security code sent to your phone/email to complete your Paystack trip payment.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AvailColors.darkgrey),
            ),
            const SizedBox(height: AvailSizes.spaceBtwSections),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              obscureText: true,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.3)),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AvailColors.primary, width: 2),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
              ),
              onChanged: (val) {
                if (val.length == 6 && !_isSubmitting) {
                  setState(() => _isSubmitting = true);
                  _timer?.cancel();
                  Get.back(result: val);
                }
              },
            ),
            const SizedBox(height: AvailSizes.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.timer_1, size: 16, color: AvailColors.darkgrey),
                    const SizedBox(width: 4),
                    Text(
                      'Expires in: ',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AvailColors.darkgrey),
                    ),
                    Text(
                      _getFormattedTime(),
                      style: TextStyle(
                        color: _secondsRemaining < 30 ? Colors.red : AvailColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: AvailSizes.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'SECURE ZERO-TRACE SESSION',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
