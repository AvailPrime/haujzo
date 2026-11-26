import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_method_model.dart';

class PaymentDetailsModel {
  String id;
  final PaymentMethodModel method;

  /// MOBILE MONEY
  final String? mobileNumber;
  final String? network; // mtn, telecel, airteltigo
  final String? accountName;

  /// COMMON SAFE FIELD
  final String? last4;

  /// CARD ONLY
  final String? brand;
  final int? expMonth;
  final int? expYear;

  /// PAYSTACK TOKEN
  final String? authorizationCode;

  final DateTime? createdAt;

  PaymentDetailsModel({
    required this.id,
    required this.method,
    this.mobileNumber,
    this.network,
    this.accountName,
    this.last4,
    this.brand,
    this.expMonth,
    this.expYear,
    this.authorizationCode,
    this.createdAt,
  });

  /// EMPTY
  static PaymentDetailsModel empty() => PaymentDetailsModel(
    id: '',
    method: PaymentMethodModel.empty(),
  );

  /// CASH ON DELIVERY
  static PaymentDetailsModel cash() => PaymentDetailsModel(
    id: 'cash_on_delivery',
    method: PaymentMethodModel(
      id: 'cash',
      name: 'Cash on Delivery (POD)',
      image: '',
      code: 'cash',
      type: 'cash',
    ),
    createdAt: DateTime(2020),
  );

  bool get isCash => id == 'cash_on_delivery' || method.type == 'cash' || method.code == 'cash';

  /// 🔥 NORMALIZE PHONE NUMBER (PAYSTACK FORMAT)
  static String? normalizePhone(String? phone, [String defaultCountryPrefix = '233']) {
    if (phone == null || phone.isEmpty) return null;

    phone = phone.replaceAll(RegExp(r'[\s\-]'), '');

    if (phone.startsWith('+')) {
      return phone.substring(1);
    }

    if (phone.startsWith('0')) {
      final prefix = defaultCountryPrefix.replaceAll('+', '');
      return '$prefix${phone.substring(1)}';
    }

    return phone;
  }

  /// 🔒 FIRESTORE JSON
  Map<String, dynamic> toJson() {
    if (method.type == 'card') {
      return {
        'id': id,
        'method': method.toJson(),
        'last4': last4,
        'brand': brand,
        'expMonth': expMonth,
        'expYear': expYear,
        'authorizationCode': authorizationCode,
        'createdAt': createdAt ?? DateTime.now(),
      };
    } else if (method.type == 'mobile_money') {
      final normalized = normalizePhone(mobileNumber);

      final last4Digits =
      normalized != null && normalized.length >= 4
          ? normalized.substring(normalized.length - 4)
          : null;

      return {
        'id': id,
        'method': method.toJson(),

        /// 🔥 STORE CLEAN NUMBER (FOR PAYSTACK)
        'mobileNumber': normalized,

        /// 🔐 MASKED VERSION FOR UI
        'maskedNumber': _maskMobileNumber(normalized),

        /// 🔥 REQUIRED FOR PAYSTACK
        'network': network,
        if (accountName != null && accountName!.trim().isNotEmpty)
          'accountName': accountName!.trim(),

        'last4': last4Digits,
        'createdAt': createdAt ?? DateTime.now(),
      };
    } else {
      return {
        'id': id,
        'method': method.toJson(),
        'createdAt': createdAt ?? DateTime.now(),
      };
    }
  }

  /// 🔐 MASK NUMBER
  static String? _maskMobileNumber(String? number) {
    if (number == null || number.length < 4) return number;

    final last2 = number.substring(number.length - 2);
    return '*' * (number.length - 2) + last2;
  }

  /// SAFE INT PARSER
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// FROM MAP
  factory PaymentDetailsModel.fromMap(Map<String, dynamic> data) {
    final mobile = data['mobileNumber'];
    final network = data['network'];

    final authorizationCode =
        data['authorizationCode'] ?? data['authorization_code'];

    final expMonth = _parseInt(data['expMonth'] ?? data['exp_month']);
    final expYear = _parseInt(data['expYear'] ?? data['exp_year']);

    PaymentMethodModel method;

    if (data['method'] != null) {
      method = PaymentMethodModel.fromMap(data['method']);
    } else if (authorizationCode != null) {
      method = PaymentMethodModel(
        id: '',
        name: 'Card Payment',
        image: '',
        code: 'card',
        type: 'card',
      );
    } else if (mobile != null) {
      method = PaymentMethodModel(
        id: '',
        name: 'Mobile Money',
        image: '',
        code: 'momo',
        type: 'mobile_money',
      );
    } else {
      method = PaymentMethodModel.empty();
    }

    return PaymentDetailsModel(
      id: data['id'] ?? '',
      method: method,

      mobileNumber: mobile,
      network: network,
      accountName: (data['accountName'] ?? data['accountHolderName'])?.toString(),

      last4: data['last4'] ??
          (mobile != null && mobile.length >= 4
              ? mobile.substring(mobile.length - 4)
              : null),

      brand: data['brand'],
      expMonth: expMonth,
      expYear: expYear,
      authorizationCode: authorizationCode,

      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// FROM FIRESTORE
  factory PaymentDetailsModel.fromDocumentSnapshot(
      DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    return PaymentDetailsModel.fromMap(data..['id'] = snapshot.id);
  }

  /// DISPLAY TITLE
  String get displayTitle {
    if (isCash) {
      return 'Cash on Delivery (POD)';
    }

    if (authorizationCode != null) {
      return '${brand?.toUpperCase() ?? 'CARD'} •••• ${last4 ?? ''}';
    }

    if (method.type == 'card') {
      return '${brand?.toUpperCase() ?? 'CARD'} •••• ${last4 ?? ''}';
    }

    if (method.type == 'mobile_money') {
      return '${network?.toUpperCase() ?? 'MOMO'} •••• ${last4 ?? ''}';
    }

    return method.name;
  }

  /// DISPLAY SUBTITLE
  String get displaySubtitle {
    if (isCash) {
      return 'Pay physical cash to verified driver upon delivery';
    }

    if (authorizationCode != null) {
      return 'Expires ${expMonth ?? ''}/${expYear ?? ''}';
    }

    if (method.type == 'card') {
      return 'Expiry: ${expMonth ?? ''}/${expYear ?? ''}';
    }

    return '';
  }

  bool get isOneClick => authorizationCode != null;

  @override
  String toString() {
    if (authorizationCode != null) {
      return 'OneClick ${brand ?? 'Card'} **** $last4';
    }

    if (method.type == 'card') {
      return '${brand ?? 'Card'} **** $last4';
    }

    if (method.type == 'mobile_money') {
      return '${network ?? 'MoMo'} **** $last4';
    }

    return method.name;
  }
}
