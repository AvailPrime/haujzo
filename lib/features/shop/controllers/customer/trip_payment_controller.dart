import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../../../data/repositories/payment/paystack_repository.dart';
import '../../../../utils/notifications/trip_payment_alert_service.dart';
import '../../../../utils/popups/full_screen_loader.dart';
import '../../../personalization/controllers/localization_controller.dart';
import '../../../personalization/controllers/user_controller.dart';
import '../../models/booking_model.dart';
import '../../screens/paystack/otp_verification_sheet.dart';
import '../../screens/paystack/paystack_webview_screen.dart';

class TripPaymentController extends GetxController with WidgetsBindingObserver {
  static TripPaymentController get instance => Get.isRegistered<TripPaymentController>()
      ? Get.find<TripPaymentController>()
      : Get.put(TripPaymentController(), permanent: true);

  final PaystackRepository paystackRepository = PaystackRepository.instance;
  final GetStorage _storage = GetStorage();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxString pendingReference = ''.obs;
  final RxString pendingBookingId = ''.obs;
  final RxBool isProcessingPayment = false.obs;

  bool _isLaunchingPayment = false;
  bool _isVerifying = false;
  Timer? _verificationTimer;

  static const _kRefKey = 'pendingTripPaymentReference';
  static const _kBookingIdKey = 'pendingTripPaymentBookingId';
  static const _kUsdAmountKey = 'pendingTripPaymentUsdAmount';
  static const _kGhsAmountKey = 'pendingTripPaymentGhsAmount';
  static const _kPhoneKey = 'pendingTripPaymentPhone';
  static const _kNetworkKey = 'pendingTripPaymentNetwork';

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    pendingReference.value = _storage.read<String>(_kRefKey) ?? '';
    pendingBookingId.value = _storage.read<String>(_kBookingIdKey) ?? '';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final savedRef = _storage.read<String>(_kRefKey);
      if (savedRef != null && savedRef.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('🔄 [TRIP PAYSTACK] App resumed, verifying pending reference: $savedRef');
        }
        verifyTripPayment(savedRef);
      }
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _verificationTimer?.cancel();
    super.onClose();
  }

  /// Convert base USD trip fare to GHS for Paystack processing
  double getNormalizedGHSAmount(double usdAmount) {
    final loc = LocalizationController.instance;
    final rate = loc.getEffectiveRate('GHS');
    final ghs = usdAmount * (rate > 0 ? rate : 15.5);
    return double.parse(ghs.toStringAsFixed(2));
  }

  /// Maps UI network name to Paystack Ghana provider code (`mtn`, `vod`, `atl`)
  String mapNetworkToPaystack(String network) {
    final cleaned = network.toLowerCase().trim();
    if (cleaned.contains('mtn')) return 'mtn';
    if (cleaned.contains('telecel') || cleaned.contains('vodafone') || cleaned == 'vod') return 'vod';
    if (cleaned.contains('airtel') || cleaned.contains('tigo') || cleaned == 'atl' || cleaned == 'at') return 'atl';
    return 'mtn';
  }

  String _resolveCustomerEmail(String userId) {
    final authEmail = AuthenticationRepository.instance.authUser?.email ??
        FirebaseAuth.instance.currentUser?.email ??
        '';
    if (authEmail.isNotEmpty) return authEmail;

    if (Get.isRegistered<UserController>()) {
      final userEmail = UserController.instance.user.value.email;
      if (userEmail.isNotEmpty) return userEmail;
    }
    return 'shipper_$userId@haujzo.com';
  }

  String _resolveCustomerPhone() {
    if (Get.isRegistered<UserController>()) {
      final phone = UserController.instance.user.value.phoneNumber;
      if (phone.isNotEmpty) return phone;
    }
    return '';
  }

  void cancelPaymentLoading({bool showMessage = false}) {
    _verificationTimer?.cancel();
    _isLaunchingPayment = false;
    _isVerifying = false;
    isProcessingPayment.value = false;
    AvailFullScreenLoader.stopLoading();

    if (showMessage) {
      AvailLoaders.warningSnackBar(
        title: 'Payment Verification Paused',
        message: 'If you approved the payment, tap "Pay Online" or "Verify Payment" to sync your booking.',
      );
    }
  }

  /// Process Customer Full Trip Fee via Paystack Mobile Money (Direct Charge with WebView Checkout fallback)
  Future<bool> payTripWithMobileMoney({
    required BookingModel booking,
    required String phone,
    required String network,
    bool useWebViewCheckout = false,
  }) async {
    if (booking.isPaidOnline) {
      AvailLoaders.successSnackBar(
        title: 'Already Paid',
        message: 'This booking has already been paid online.',
      );
      return true;
    }

    if (_isLaunchingPayment) return false;

    final authUser = AuthenticationRepository.instance.authUser ?? FirebaseAuth.instance.currentUser;
    final userId = authUser?.uid;
    if (userId == null || userId.isEmpty) {
      AvailLoaders.errorSnackBar(
        title: 'Authentication Required',
        message: 'Please log in to complete your booking payment.',
      );
      return false;
    }

    if (booking.price <= 0) {
      AvailLoaders.errorSnackBar(
        title: 'Invalid Trip Fare',
        message: 'Trip fare must be greater than zero.',
      );
      return false;
    }

    // Stop any loud alert sound immediately when user begins paying
    if (Get.isRegistered<TripPaymentAlertService>()) {
      TripPaymentAlertService.instance.stopAlertSound();
    }

    if (useWebViewCheckout) {
      await payTripWithPaystackCheckout(booking: booking, phone: phone, network: network);
      return true;
    }

    _isLaunchingPayment = true;
    isProcessingPayment.value = true;

    try {
      await paystackRepository.fetchPaystackConfig();

      final double usdAmount = booking.price;
      final double ghsAmount = getNormalizedGHSAmount(usdAmount);
      final String paystackNetwork = mapNetworkToPaystack(network);
      final String email = _resolveCustomerEmail(userId);

      AvailFullScreenLoader.openCheckoutLoading(
        usdAmount,
        amountLabel: 'Full Trip Fee:',
        subTitle: 'Initializing secure Paystack Mobile Money prompt for ${booking.bookingId.isNotEmpty ? booking.bookingId : booking.id}...',
        onManualVerify: manualVerifyPayment,
        onCancel: () => cancelPaymentLoading(showMessage: true),
      );

      final result = await paystackRepository.chargeMobileMoney(
        email: email,
        amount: ghsAmount,
        phone: phone,
        network: paystackNetwork,
        metadata: {
          'type': 'trip_payment',
          'bookingId': booking.id,
          'bookingCode': booking.bookingId.isNotEmpty ? booking.bookingId : booking.id,
          'userId': userId,
          'usdAmount': usdAmount,
          'ghsAmount': ghsAmount,
          'phone': phone,
          'network': network,
        },
      );

      final apiStatus = result['status'];
      final txData = result['data'] is Map ? Map<String, dynamic>.from(result['data']) : <String, dynamic>{};
      final txStatus = (txData['status'] ?? '').toString();
      final reference = (txData['reference'] ?? '').toString();
      final gatewayMsg = (txData['display_text'] ?? txData['message'] ?? txData['gateway_response'] ?? '').toString();

      if (apiStatus != true || reference.isEmpty) {
        throw txData['message'] ?? 'Paystack Mobile Money initialization failed';
      }

      await _savePendingPaymentContext(
        bookingId: booking.id,
        reference: reference,
        usdAmount: usdAmount,
        ghsAmount: ghsAmount,
        phone: phone,
        network: network,
      );

      // 1. Instant Success
      if (txStatus == 'success') {
        await verifyTripPayment(reference);
        return true;
      }

      // 2. OTP / PIN Action Required
      if (txStatus == 'send_otp' || txStatus == 'send_pin' || txStatus == 'otp' || txStatus == 'pin') {
        await _handlePaystackOtpRequired(
          usdAmount: usdAmount,
          reference: reference,
          message: gatewayMsg,
        );
        return true;
      }

      // 3. Pending USSD / Offline Approval on Phone
      if (txStatus == 'pending' || txStatus == 'pay_offline' || txStatus == 'ongoing' || txStatus == 'processing') {
        AvailFullScreenLoader.openCheckoutLoading(
          usdAmount,
          amountLabel: 'Full Trip Fee:',
          subTitle: gatewayMsg.isNotEmpty
              ? gatewayMsg
              : 'Waiting for your approval on your mobile device. Enter your Mobile Money PIN to complete payment.',
          onManualVerify: manualVerifyPayment,
          onCancel: () => cancelPaymentLoading(showMessage: true),
        );

        AvailLoaders.securityToast(
          message: gatewayMsg.isNotEmpty
              ? gatewayMsg
              : 'Approve the Mobile Money PIN prompt on your phone to confirm trip payment.',
        );

        _startVerificationPolling(reference, usdAmount);
        return true;
      }

      throw txData['message'] ?? 'Unexpected payment status: $txStatus';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [TRIP PAYSTACK MOMO ERROR]: $e');
      }
      AvailFullScreenLoader.stopLoading();
      _isLaunchingPayment = false;
      isProcessingPayment.value = false;

      AvailLoaders.warningSnackBar(
        title: 'Switching to Paystack Checkout',
        message: 'Opening secure Paystack Checkout page...',
      );

      await payTripWithPaystackCheckout(booking: booking, phone: phone, network: network);
      return false;
    }
  }

  /// Pay Full Trip Fee via Paystack Hosted Checkout (Card, Bank, Mobile Money)
  Future<void> payTripWithPaystackCheckout({
    required BookingModel booking,
    String? phone,
    String? network,
  }) async {
    if (booking.isPaidOnline) {
      AvailLoaders.successSnackBar(
        title: 'Already Paid',
        message: 'This booking has already been paid online.',
      );
      return;
    }

    if (_isLaunchingPayment) return;
    _isLaunchingPayment = true;
    isProcessingPayment.value = true;

    if (Get.isRegistered<TripPaymentAlertService>()) {
      TripPaymentAlertService.instance.stopAlertSound();
    }

    try {
      final authUser = AuthenticationRepository.instance.authUser ?? FirebaseAuth.instance.currentUser;
      final userId = authUser?.uid;
      if (userId == null || userId.isEmpty) {
        throw 'User not authenticated';
      }

      final double usdAmount = booking.price;
      final double ghsAmount = getNormalizedGHSAmount(usdAmount);
      final String email = _resolveCustomerEmail(userId);
      final String effectivePhone = (phone != null && phone.isNotEmpty) ? phone : _resolveCustomerPhone();

      AvailFullScreenLoader.openCheckoutLoading(
        usdAmount,
        amountLabel: 'Full Trip Fee:',
        subTitle: 'Opening secure Paystack Checkout...',
        onCancel: () => cancelPaymentLoading(showMessage: true),
      );

      final response = await paystackRepository.initializeTransaction(
        email: email,
        amount: ghsAmount,
        callbackUrl: 'https://availprime.com/paystack-redirect',
        metadata: {
          'type': 'trip_payment',
          'bookingId': booking.id,
          'bookingCode': booking.bookingId.isNotEmpty ? booking.bookingId : booking.id,
          'userId': userId,
          'usdAmount': usdAmount,
          'ghsAmount': ghsAmount,
          if (effectivePhone.isNotEmpty) 'phone': effectivePhone,
          if (network != null && network.isNotEmpty) 'network': network,
        },
      );

      final authorizationUrl = (response['authorization_url'] ?? '').toString();
      final reference = (response['reference'] ?? '').toString();

      if (authorizationUrl.isEmpty || reference.isEmpty) {
        throw 'Failed to get Paystack authorization URL';
      }

      await _savePendingPaymentContext(
        bookingId: booking.id,
        reference: reference,
        usdAmount: usdAmount,
        ghsAmount: ghsAmount,
        phone: effectivePhone,
        network: network ?? 'Paystack Checkout',
      );

      AvailFullScreenLoader.stopLoading();

      if (GetPlatform.isWeb) {
        final Uri url = Uri.parse(authorizationUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch Paystack payment page';
        }
      } else {
        Get.to(
          () => PaystackWebViewScreen(
            url: authorizationUrl,
            reference: reference,
          ),
          routeName: '/paystack-checkout',
        );
      }
    } catch (e) {
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.errorSnackBar(
        title: 'Payment Initialization Failed',
        message: e.toString(),
      );
    } finally {
      _isLaunchingPayment = false;
      isProcessingPayment.value = false;
    }
  }

  Future<void> _handlePaystackOtpRequired({
    required double usdAmount,
    required String reference,
    required String message,
  }) async {
    AvailFullScreenLoader.stopLoading();

    if (message.isNotEmpty) {
      AvailLoaders.securityToast(message: message);
    }

    final String? otp = await Get.bottomSheet<String>(
      const AvailOtpVerificationSheet(),
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
    );

    if (otp != null && otp.trim().isNotEmpty) {
      AvailFullScreenLoader.openCheckoutLoading(
        usdAmount,
        amountLabel: 'Full Trip Fee:',
        subTitle: 'Submitting OTP and waiting for Mobile Money authorization...',
        onManualVerify: manualVerifyPayment,
        onCancel: () => cancelPaymentLoading(showMessage: true),
      );

      final otpResult = await paystackRepository.verifyMoMoWithOtp(
        otp: otp.trim(),
        reference: reference,
      );

      final otpApiStatus = otpResult['status'];
      final otpTxData = otpResult['data'] is Map ? Map<String, dynamic>.from(otpResult['data']) : <String, dynamic>{};
      final afterOtpStatus = (otpTxData['status'] ?? '').toString();

      if (otpApiStatus == true) {
        if (afterOtpStatus == 'success') {
          await verifyTripPayment(reference);
        } else {
          AvailFullScreenLoader.openCheckoutLoading(
            usdAmount,
            amountLabel: 'Full Trip Fee:',
            subTitle: 'OTP accepted! Please approve the PIN prompt on your phone to complete payment.',
            onManualVerify: manualVerifyPayment,
            onCancel: () => cancelPaymentLoading(showMessage: true),
          );
          _startVerificationPolling(reference, usdAmount);
        }
      } else {
        throw otpTxData['message'] ?? 'OTP verification failed';
      }
    } else {
      _isLaunchingPayment = false;
      isProcessingPayment.value = false;
      AvailLoaders.customToast(message: 'OTP verification cancelled.');
    }
  }

  Future<void> _savePendingPaymentContext({
    required String bookingId,
    required String reference,
    required double usdAmount,
    required double ghsAmount,
    required String phone,
    required String network,
  }) async {
    pendingReference.value = reference;
    pendingBookingId.value = bookingId;
    await _storage.write(_kRefKey, reference);
    await _storage.write(_kBookingIdKey, bookingId);
    await _storage.write(_kUsdAmountKey, usdAmount);
    await _storage.write(_kGhsAmountKey, ghsAmount);
    await _storage.write(_kPhoneKey, phone);
    await _storage.write(_kNetworkKey, network);
  }

  void _clearPersistentPaymentData() {
    _verificationTimer?.cancel();
    pendingReference.value = '';
    pendingBookingId.value = '';
    _storage.remove(_kRefKey);
    _storage.remove(_kBookingIdKey);
    _storage.remove(_kUsdAmountKey);
    _storage.remove(_kGhsAmountKey);
    _storage.remove(_kPhoneKey);
    _storage.remove(_kNetworkKey);
    AvailFullScreenLoader.stopLoading();
  }

  void _startVerificationPolling(String reference, double usdAmount) {
    _verificationTimer?.cancel();
    int ticks = 0;
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      ticks++;
      if (kDebugMode) {
        debugPrint('⏱️ [TRIP PAYSTACK] Polling payment status ($ticks/20) for $reference...');
      }

      _isVerifying = false;
      await verifyTripPayment(reference);

      final currentStoredRef = _storage.read<String>(_kRefKey);
      if (currentStoredRef == null || currentStoredRef.isEmpty || ticks >= 20) {
        timer.cancel();
        if (_isLaunchingPayment && ticks >= 20) {
          _isVerifying = false;
          _isLaunchingPayment = false;
          isProcessingPayment.value = false;
          AvailFullScreenLoader.stopLoading();
          AvailLoaders.warningSnackBar(
            title: 'Waiting for Payment Confirmation',
            message: 'Once you approve the PIN prompt on your phone, tap "Verify Payment" in Booking Details.',
          );
        }
      }
    });
  }

  Future<void> handleWebViewReturn(String reference) async {
    final double usdAmount = (_storage.read(_kUsdAmountKey) as num?)?.toDouble() ?? 0.0;
    AvailFullScreenLoader.openCheckoutLoading(
      usdAmount,
      amountLabel: 'Full Trip Fee:',
      subTitle: 'Verifying your trip payment status with Paystack...',
      onManualVerify: manualVerifyPayment,
      onCancel: () => cancelPaymentLoading(showMessage: true),
    );
    await verifyTripPayment(reference);
  }

  Future<void> manualVerifyPayment() async {
    final storedRef = _storage.read<String>(_kRefKey) ?? pendingReference.value;
    if (storedRef.isEmpty) {
      AvailLoaders.warningSnackBar(
        title: 'No Pending Payment',
        message: 'No pending Paystack payment reference found to verify.',
      );
      return;
    }

    AvailLoaders.customToast(message: 'Checking payment status with Paystack...');
    _isVerifying = false;
    await verifyTripPayment(storedRef);
  }

  /// Verify Paystack transaction via Cloud Function & ensure Booking document is immediately marked Paid Online
  Future<void> verifyTripPayment(String reference) async {
    if (reference.trim().isEmpty) return;

    final alreadyProcessed = _storage.read('processed_trip_pay_$reference') == true;
    if (alreadyProcessed) {
      _clearPersistentPaymentData();
      _isVerifying = false;
      _isLaunchingPayment = false;
      isProcessingPayment.value = false;
      return;
    }

    if (_isVerifying) return;
    _isVerifying = true;

    try {
      final authUser = AuthenticationRepository.instance.authUser ?? FirebaseAuth.instance.currentUser;
      final userId = authUser?.uid;
      if (userId == null || userId.isEmpty) {
        _isVerifying = false;
        return;
      }

      final String bookingId = _storage.read<String>(_kBookingIdKey) ?? pendingBookingId.value;
      final double usdAmount = (_storage.read(_kUsdAmountKey) as num?)?.toDouble() ?? 0.0;
      final double ghsAmount = (_storage.read(_kGhsAmountKey) as num?)?.toDouble() ?? getNormalizedGHSAmount(usdAmount);
      final String phone = _storage.read<String>(_kPhoneKey) ?? _resolveCustomerPhone();
      final String network = _storage.read<String>(_kNetworkKey) ?? 'Paystack';

      final data = await paystackRepository.verifyTransaction(
        reference: reference,
        userId: userId,
        bookingId: bookingId,
        usdAmount: usdAmount,
        phone: phone,
        network: network,
        type: 'trip_payment',
      );

      if (data.isEmpty) {
        _isVerifying = false;
        return;
      }

      if (data['success'] != true) {
        final status = (data['status'] ?? '').toString().toLowerCase();
        final isStillPending = data['isPending'] == true ||
            status == 'pending' ||
            status == 'pay_offline' ||
            status == 'ongoing' ||
            status == 'send_otp' ||
            status == 'processing' ||
            (_verificationTimer?.isActive == true);

        if (isStillPending) {
          _isVerifying = false;
          return;
        }

        _clearPersistentPaymentData();
        _isVerifying = false;
        _isLaunchingPayment = false;
        isProcessingPayment.value = false;
        AvailLoaders.errorSnackBar(
          title: 'Payment Not Completed',
          message: (data['message'] ?? 'Transaction could not be verified as paid.').toString(),
        );
        return;
      }

      await _storage.write('processed_trip_pay_$reference', true);

      // Client-side idempotent mirror in case Cloud Function ran an older deployment
      if (bookingId.isNotEmpty) {
        final channel = (data['channel'] ?? 'paystack').toString();
        final methodLabel = channel.toLowerCase() == 'card' ? 'Paystack Card (Online)' : 'Paystack (Online)';
        await _db.collection('bookings').doc(bookingId).set({
          'paymentMethod': methodLabel,
          'paymentStatus': 'paid',
          'paidOnline': true,
          'paymentReference': reference,
          'paymentChannel': channel,
          'paymentNetwork': network,
          'paymentPhone': phone,
          'paidAmountGhs': (data['amount'] as num?)?.toDouble() ?? ghsAmount,
          if (usdAmount > 0) 'paidAmountUsd': usdAmount,
          'paidByUserId': userId,
          'paidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _clearPersistentPaymentData();
      _isVerifying = false;
      _isLaunchingPayment = false;
      isProcessingPayment.value = false;

      if (Get.isRegistered<TripPaymentAlertService>()) {
        TripPaymentAlertService.instance.markBookingPromptHandled(bookingId);
      }

      // Close open bottom sheet if still open
      if (Get.isBottomSheetOpen ?? false) {
        Get.back();
      }

      AvailLoaders.successSnackBar(
        title: 'Trip Paid Online! 🎉',
        message: 'Payment confirmed via Paystack (Ref: $reference). Driver & Admin notified immediately.',
        duration: 5,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [TRIP PAYSTACK VERIFY ERROR]: $e');
      }
      _isVerifying = false;
      if (_verificationTimer?.isActive != true) {
        AvailFullScreenLoader.stopLoading();
        _isLaunchingPayment = false;
        isProcessingPayment.value = false;
        AvailLoaders.warningSnackBar(
          title: 'Verification Notice',
          message: 'Could not confirm payment yet: $e',
        );
      }
    }
  }
}
