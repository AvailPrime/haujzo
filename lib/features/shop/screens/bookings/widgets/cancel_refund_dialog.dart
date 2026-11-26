import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../../commons/widgets/loader/loaders.dart';
import '../../../../../data/repositories/bookings/booking_repository.dart';
import '../../../../../data/repositories/support/support_config_repository.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/popups/full_screen_loader.dart';
import '../../../../personalization/controllers/localization_controller.dart';
import '../../../../personalization/controllers/payment_controller.dart';
import '../../../../personalization/screens/payment_methods/add_new_payment.dart';
import '../../../../../routes/routes.dart';
import '../../../controllers/customer/trip_payment_controller.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_details_model.dart';

class CancelRefundDialog {
  static Future<bool> show(BuildContext context, BookingModel booking) async {
    final supportRepo = SupportConfigRepository.instance;
    if (!booking.canShipperCancelDirectly && !booking.isCancelled) {
      final cfg = supportRepo.supportConfig.value;
      await Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Iconsax.shield_security, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cancellation Requires Admin Review',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manifest #${booking.bookingId} is already "${booking.status.toUpperCase()}". '
                'Once cargo has been loaded or picked up, instant self-cancellation is locked to protect both shipper and carrier.\n\n'
                'Please contact Dispatch Support with your Booking ID (#${booking.bookingId}) if you need a dispute or emergency cancellation.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Support Phone: ${cfg.supportPhone}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('Support Email: ${cfg.supportEmail}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('Emergency Line: ${cfg.emergencyNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Get.back();
                supportRepo.emailSupport(
                  subject: 'Dispute / Emergency Cancellation - #${booking.bookingId}',
                  body: 'Booking ID: #${booking.bookingId}\nCurrent Status: ${booking.status}\n\nDetails:\n',
                );
              },
              icon: const Icon(Iconsax.sms, size: 16),
              label: const Text('Email Dispute'),
            ),
            TextButton.icon(
              onPressed: () {
                Get.back();
                supportRepo.callSupport();
              },
              icon: const Icon(Iconsax.call, size: 16, color: Colors.green),
              label: const Text('Call Support', style: TextStyle(color: Colors.green)),
            ),
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(backgroundColor: AvailColors.primary),
              child: const Text('UNDERSTOOD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return false;
    }

    final paymentCtrl = Get.isRegistered<PaymentController>()
        ? PaymentController.instance
        : Get.put(PaymentController());
    if (booking.isPaidOnline) {
      await paymentCtrl.loadUserPayments();
    }

    final reasonController = TextEditingController();
    String selectedDestination = 'original_source'; // 'original_source' or saved payment ID
    PaymentDetailsModel? selectedWallet;
    bool isSubmitting = false;

    final locCtrl = LocalizationController.instance;
    final tripPayCtrl = TripPaymentController.instance;
    final formattedUsd = locCtrl.getFormattedPrice(booking.price);
    final ghsAmt = booking.paidAmountGhs ?? tripPayCtrl.getNormalizedGHSAmount(booking.price);
    final formattedGhs = 'GH¢ ${NumberFormat('#,##0.00', 'en_US').format(ghsAmt)}';

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final momoWallets = paymentCtrl.savedPayments
              .where((p) => p.method.type == 'mobile_money' && !p.isCash)
              .toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(
                  booking.isPaidOnline ? Iconsax.money_recive : Iconsax.warning_2,
                  color: booking.isPaidOnline ? Colors.orange.shade700 : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.isCancelled
                        ? 'Request Online Refund'
                        : (booking.isPaidOnline ? 'Cancel & Request Refund?' : 'Cancel Dispatch?'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (booking.isPaidOnline) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ONLINE PAYMENT DETECTED ($formattedUsd / $formattedGhs)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.isCancelled
                                  ? 'This cancelled job was paid online. Submit your refund request below so Admin can refund your payment via Paystack.'
                                  : 'Cancelling will immediately flag this booking for a full Admin refund review via Paystack (Ref: ${booking.paymentReference ?? 'Verified'}).',
                              style: const TextStyle(fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Preferred Refund Destination',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: isSubmitting
                            ? null
                            : () => setState(() {
                                  selectedDestination = 'original_source';
                                  selectedWallet = null;
                                }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedDestination == 'original_source'
                                  ? AvailColors.primary
                                  : Colors.grey.shade300,
                              width: selectedDestination == 'original_source' ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: 'original_source',
                                groupValue: selectedDestination,
                                onChanged: isSubmitting
                                    ? null
                                    : (_) => setState(() {
                                          selectedDestination = 'original_source';
                                          selectedWallet = null;
                                        }),
                              ),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Original Paystack Source (Recommended)',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Refund back to the same Card / MoMo wallet you paid with',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ...momoWallets.map((w) {
                        final hasName = (w.accountName ?? '').trim().isNotEmpty;
                        return InkWell(
                          onTap: isSubmitting
                              ? null
                              : () => setState(() {
                                    selectedDestination = w.id;
                                    selectedWallet = w;
                                  }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedDestination == w.id ? AvailColors.primary : Colors.grey.shade300,
                                width: selectedDestination == w.id ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: w.id,
                                  groupValue: selectedDestination,
                                  onChanged: isSubmitting
                                      ? null
                                      : (_) => setState(() {
                                            selectedDestination = w.id;
                                            selectedWallet = w;
                                          }),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        w.displayTitle,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        hasName
                                            ? 'Account Name: ${w.accountName}'
                                            : '⚠ Missing Account Name (Update wallet before transfer)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: hasName ? Colors.teal.shade700 : Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  await Get.toNamed(AvailRoutes.addNewPayment);
                                  await paymentCtrl.loadUserPayments();
                                  setState(() {});
                                },
                          icon: const Icon(Iconsax.add_circle, size: 15),
                          label: const Text('Add Verified MoMo Wallet', style: TextStyle(fontSize: 11.5)),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Are you sure you want to cancel this freight manifest? This action will remove the job from active dispatch.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: booking.isPaidOnline ? 'Reason for Cancellation / Refund' : 'Reason (Optional)',
                        hintText: 'e.g. Driver cancelled trip / Schedule changed',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('KEEP BOOKING', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (booking.isPaidOnline &&
                            selectedWallet != null &&
                            (selectedWallet!.accountName ?? '').trim().isEmpty) {
                          AvailLoaders.warningSnackBar(
                            title: 'Account Name Missing',
                            message:
                                'Please select "Original Paystack Source" or add your Account Name to that MoMo wallet first.',
                          );
                          return;
                        }
                        setState(() => isSubmitting = true);
                        try {
                          AvailFullScreenLoader.openLoadingDialog(
                            booking.isPaidOnline ? 'Submitting refund request...' : 'Cancelling manifest...',
                          );
                          await BookingRepository.instance.cancelBookingAndRequestRefund(
                            bookingId: booking.id,
                            reason: reasonController.text.trim(),
                            refundMethodId: selectedWallet?.id ?? '',
                            refundMethodType: selectedWallet?.method.type ?? '',
                            refundNetworkOrBankCode: selectedWallet?.network ?? '',
                            refundAccountNumber: selectedWallet?.mobileNumber ?? '',
                            refundAccountName: selectedWallet?.accountName ?? '',
                            refundMethodLabel: selectedWallet?.method.name ?? '',
                          );
                          AvailFullScreenLoader.stopLoading();
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                          AvailLoaders.successSnackBar(
                            title: booking.isPaidOnline ? 'Cancelled & Refund Requested' : 'Manifest Cancelled',
                            message: booking.isPaidOnline
                                ? 'Your refund request has been queued for Admin Paystack processing.'
                                : 'The freight job has been cancelled.',
                          );
                        } catch (e) {
                          AvailFullScreenLoader.stopLoading();
                          setState(() => isSubmitting = false);
                          AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  booking.isPaidOnline ? 'CANCEL & REQUEST REFUND' : 'YES, CANCEL JOB',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
    reasonController.dispose();
    return result == true;
  }
}
