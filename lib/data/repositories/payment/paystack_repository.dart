import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../features/shop/models/paystack_model.dart';

class PaystackRepository extends GetxController {
  static PaystackRepository get instance =>
      Get.isRegistered<PaystackRepository>() ? Get.find<PaystackRepository>() : Get.put(PaystackRepository(), permanent: true);

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Rx<PaystackModel> paystackConfig = PaystackModel.empty().obs;

  @override
  void onInit() {
    super.onInit();
    fetchPaystackConfig();
  }

  /// Fetch Paystack public key configuration from `app_settings/payment_gateway` in Firestore
  Future<PaystackModel> fetchPaystackConfig() async {
    try {
      final doc = await _db.collection('app_settings').doc('payment_gateway').get();
      if (doc.exists && doc.data() != null) {
        final model = PaystackModel.fromMap(doc.data()!);
        if (model.activeKey.isNotEmpty) {
          paystackConfig.value = model;
          if (kDebugMode) {
            debugPrint('🟢 [PAYSTACK CONFIG] Loaded from app_settings/payment_gateway (isLive=${model.isLive})');
          }
          return model;
        }
      }

      // Fallback: check top-level payment_gateway collection if present
      final colSnap = await _db.collection('payment_gateway').limit(1).get();
      if (colSnap.docs.isNotEmpty) {
        final model = PaystackModel.fromMap(colSnap.docs.first.data());
        paystackConfig.value = model;
        return model;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [PAYSTACK CONFIG] Could not read public key from Firestore: $e');
      }
    }
    return paystackConfig.value;
  }

  /// Initialize a Paystack transaction via secure Cloud Function
  Future<Map<String, dynamic>> initializeTransaction({
    required String email,
    required double amount,
    String? callbackUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔵 INITIALIZING PAYSTACK TRIP PAYMENT: email=$email, amount=$amount GHS');
      }
      final HttpsCallable callable = _functions.httpsCallable('initializePayment');
      final response = await callable.call({
        'email': email,
        'amount': amount,
        'callback_url': callbackUrl ?? 'https://availprime.com/paystack-redirect',
        if (metadata != null) 'metadata': metadata,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['publicKey'] != null && data['publicKey'].toString().isNotEmpty) {
        paystackConfig.value = PaystackModel(
          testPublicKey: paystackConfig.value.testPublicKey,
          livePublicKey: data['publicKey'].toString(),
          isLive: true,
        );
      }
      return data;
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        throw e.message ?? 'Paystack Initialization Error';
      }
      throw 'Paystack Initialization Error: $e';
    }
  }

  /// Verify a Paystack transaction via secure Cloud Function
  Future<Map<String, dynamic>> verifyTransaction({
    required String reference,
    required String userId,
    String? bookingId,
    double? usdAmount,
    String? phone,
    String? network,
    String type = 'trip_payment',
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('verifyPaystackPayment');
      final response = await callable.call({
        'reference': reference,
        'userId': userId,
        if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
        if (usdAmount != null) 'usdAmount': usdAmount,
        if (phone != null) 'phone': phone,
        if (network != null) 'network': network,
        'type': type,
      });

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        throw e.message ?? 'Paystack Verification Error';
      }
      throw 'Paystack Verification Error: $e';
    }
  }

  /// Charge Mobile Money directly via Paystack `/charge` Cloud Function
  Future<Map<String, dynamic>> chargeMobileMoney({
    required String email,
    required double amount,
    required String phone,
    required String network,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('chargeMobileMoney');
      final response = await callable.call({
        'email': email,
        'amount': amount,
        'phone': phone,
        'network': network,
        if (metadata != null) 'metadata': metadata,
      });

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        throw e.message ?? e.details?.toString() ?? 'Mobile Money charge failed';
      }
      throw 'Mobile Money Charge Error: $e';
    }
  }

  /// Charge with saved authorization code
  Future<Map<String, dynamic>> chargeWithAuthorization({
    required String email,
    required double amount,
    required String authorizationCode,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('chargeWithAuthorization');
      final response = await callable.call({
        'email': email,
        'amount': amount,
        'authorization_code': authorizationCode,
        if (metadata != null) 'metadata': metadata,
      });

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        throw e.message ?? 'Paystack Authorization Charge Error';
      }
      throw 'Paystack Authorization Charge Error: $e';
    }
  }

  /// Submit OTP for Card Payment
  Future<Map<String, dynamic>> verifyTransactionWithOtp({
    required String otp,
    required String reference,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('submitPaystackOtp');
      final response = await callable.call({
        'otp': otp,
        'reference': reference,
      });

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        throw e.message ?? 'OTP Verification Error';
      }
      throw 'OTP Verification Error: $e';
    }
  }

  /// Submit OTP for Mobile Money Payment
  Future<Map<String, dynamic>> verifyMoMoWithOtp({
    required String otp,
    required String reference,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('submitMoMoOtp');
      final response = await callable.call({
        'otp': otp,
        'reference': reference,
      });

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        throw e.message ?? 'MoMo OTP Verification Error';
      }
      throw 'MoMo OTP Verification Error: $e';
    }
  }
}
