import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../../commons/widgets/loader/loaders.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/image_strings.dart';
import '../../../../../utils/helpers/helper_functions.dart';
import '../../../../../utils/notifications/trip_payment_alert_service.dart';
import '../../../../personalization/controllers/localization_controller.dart';
import '../../../../personalization/controllers/payment_controller.dart';
import '../../../../personalization/controllers/user_controller.dart';
import '../../../controllers/customer/trip_payment_controller.dart';
import '../../../models/booking_model.dart';

Future<void> showTripPaymentBottomSheet({
  required BookingModel booking,
  bool isUrgentLoadedAlert = false,
}) {
  return Get.bottomSheet(
    TripPaymentBottomSheet(
      booking: booking,
      isUrgentLoadedAlert: isUrgentLoadedAlert,
    ),
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
  );
}

class TripPaymentBottomSheet extends StatefulWidget {
  final BookingModel booking;
  final bool isUrgentLoadedAlert;

  const TripPaymentBottomSheet({
    super.key,
    required this.booking,
    this.isUrgentLoadedAlert = false,
  });

  @override
  State<TripPaymentBottomSheet> createState() => _TripPaymentBottomSheetState();
}

class _TripPaymentBottomSheetState extends State<TripPaymentBottomSheet> {
  final TextEditingController _phoneController = TextEditingController();
  String _selectedNetwork = 'mtn';

  @override
  void initState() {
    super.initState();
    _prefillPhoneAndNetwork();
  }

  void _prefillPhoneAndNetwork() {
    try {
      if (Get.isRegistered<PaymentController>()) {
        final paymentCtrl = PaymentController.instance;
        final saved = paymentCtrl.savedPayments.firstWhereOrNull(
          (p) => p.method.type == 'mobile_money' && (p.mobileNumber ?? '').isNotEmpty,
        );
        if (saved != null) {
          _phoneController.text = _toLocalGhanaFormat(saved.mobileNumber ?? '');
          if ((saved.network ?? '').isNotEmpty) {
            _selectedNetwork = saved.network!.toLowerCase();
          }
          return;
        }
      }

      if (Get.isRegistered<UserController>()) {
        final userPhone = UserController.instance.user.value.phoneNumber;
        if (userPhone.isNotEmpty) {
          _phoneController.text = _toLocalGhanaFormat(userPhone);
          return;
        }
      }

      if (widget.booking.senderPhone.isNotEmpty) {
        _phoneController.text = _toLocalGhanaFormat(widget.booking.senderPhone);
      }
    } catch (_) {}
  }

  String _toLocalGhanaFormat(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('233') && digits.length >= 12) {
      return '0${digits.substring(3)}';
    }
    if (digits.length == 9 && !digits.startsWith('0')) {
      return '0$digits';
    }
    return raw.trim();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    final tripPayCtrl = TripPaymentController.instance;
    final locCtrl = LocalizationController.instance;
    final ghsAmount = tripPayCtrl.getNormalizedGHSAmount(widget.booking.price);
    final formattedUsdEquivalent = locCtrl.getFormattedPrice(widget.booking.price);
    final formattedGhs = 'GH¢ ${NumberFormat('#,##0.00', 'en_US').format(ghsAmount)}';
    final displayId = widget.booking.bookingId.isNotEmpty ? widget.booking.bookingId : widget.booking.id;

    final savedMomoList = Get.isRegistered<PaymentController>()
        ? PaymentController.instance.savedPayments
            .where((p) => p.method.type == 'mobile_money' && (p.mobileNumber ?? '').isNotEmpty)
            .toList()
        : [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
      ),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Alert Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isUrgentLoadedAlert
                      ? [const Color(0xFFD97706), const Color(0xFFB45309)]
                      : [const Color(0xFF0F172A), const Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isUrgentLoadedAlert ? Iconsax.truck_fast : Iconsax.shield_tick5,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isUrgentLoadedAlert
                              ? 'CARGO LOADED ON TRUCK!'
                              : 'PAY FULL TRIP FEE ONLINE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.isUrgentLoadedAlert
                              ? 'Your freight is loaded and ready for transit. Please pay the full trip fee securely online via Paystack.'
                              : 'Complete your freight payment securely via Paystack for instant driver & admin confirmation.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Trip Summary & Amount Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: darkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: darkMode ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('MANIFEST #', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text(displayId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CARGO & ROUTE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Flexible(
                        child: Text(
                          '${widget.booking.cargoType} • ${widget.booking.distance.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL TRIP AMOUNT',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.grey),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formattedUsdEquivalent,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: AvailColors.primary,
                            ),
                          ),
                          if (locCtrl.selectedCurrency.value != 'GHS')
                            Text(
                              'Paystack Charge: $formattedGhs',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (savedMomoList.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'SAVED MOBILE MONEY WALLETS',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.7),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: savedMomoList.map((saved) {
                  final localNum = _toLocalGhanaFormat(saved.mobileNumber ?? '');
                  final net = (saved.network ?? 'mtn').toLowerCase();
                  final isSelected = _phoneController.text.trim() == localNum && _selectedNetwork == net;
                  return ChoiceChip(
                    selected: isSelected,
                    label: Text('${net.toUpperCase()} • $localNum'),
                    selectedColor: AvailColors.primary.withValues(alpha: 0.16),
                    onSelected: (_) {
                      setState(() {
                        _phoneController.text = localNum;
                        _selectedNetwork = net;
                      });
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Mobile Money Network Selector
            const Text(
              'PAY WITH MOBILE MONEY (INSTANT PROMPT)',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.7),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildNetworkOption('mtn', 'MTN MoMo', AvailImages.mtn, darkMode),
                const SizedBox(width: 8),
                _buildNetworkOption('telecel', 'Telecel', AvailImages.telecel, darkMode),
                const SizedBox(width: 8),
                _buildNetworkOption('airteltigo', 'AT Money', AvailImages.airteltigo, darkMode),
              ],
            ),

            const SizedBox(height: 12),

            // MoMo Number Input
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Money Number',
                hintText: '024 XXX XXXX',
                prefixIcon: const Icon(Iconsax.mobile),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 16),

            // Primary Pay with MoMo Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final phone = _phoneController.text.trim();
                  if (phone.length < 9) {
                    AvailLoaders.warningSnackBar(
                      title: 'Invalid Phone Number',
                      message: 'Please enter a valid Mobile Money number.',
                    );
                    return;
                  }
                  Get.back();
                  await tripPayCtrl.payTripWithMobileMoney(
                    booking: widget.booking,
                    phone: phone,
                    network: _selectedNetwork,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AvailColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Iconsax.flash_1, size: 20),
                label: Text(
                  'PAY $formattedGhs VIA MOMO',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.5),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Secondary Paystack Hosted Checkout (Card / Bank / MoMo)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Get.back();
                  await tripPayCtrl.payTripWithPaystackCheckout(
                    booking: widget.booking,
                    phone: _phoneController.text.trim(),
                    network: _selectedNetwork,
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AvailColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Iconsax.card, size: 18, color: AvailColors.primary),
                label: const Text(
                  'Pay with Card / Bank / Paystack Checkout',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AvailColors.primary),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Dismiss / Pay Later
            Center(
              child: TextButton(
                onPressed: () {
                  TripPaymentAlertService.instance.stopAlertSound();
                  Get.back();
                },
                child: const Text(
                  'Dismiss for now (You can pay from Booking Details anytime)',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkOption(String code, String label, String assetPath, bool darkMode) {
    final isSelected = _selectedNetwork == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedNetwork = code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AvailColors.primary.withValues(alpha: 0.12)
                : (darkMode ? const Color(0xFF1E293B) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AvailColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(assetPath, width: 28, height: 28, fit: BoxFit.cover),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AvailColors.primary : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
