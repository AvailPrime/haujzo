import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  String id;
  String userId;
  String cargoType;
  String containerSize;
  String containerStatus; // 'Empty' or 'Loaded'
  String loadDescription;
  String senderName;
  String senderPhone;
  String receiverName;
  String receiverPhone;
  String status;
  DateTime timestamp;
  List<Map<String, String>> documents;
  
  // Professional fields (required for UI consistency)
  String truckType;
  double price;
  String pickupAddress;
  String dropoffAddress;
  double weight;
  double distance;
  String bookingId; // This is often used for display
  GeoPoint? pickupLocation;
  GeoPoint? dropoffLocation;

  // Logistics Professional Options
  bool isFragile;
  bool isInsured;
  bool requiresLoadingAssistance;

  // Professional Shipping Details
  DateTime? scheduledDate;
  double? cargoValue;
  String? paymentMethod; // e.g., 'Cash on Delivery', 'Paystack (Online)'
  String? initialPaymentMethod;
  String paymentStatus; // 'unpaid', 'pending', 'paid'
  bool paidOnline;
  String? paymentReference;
  String? paymentChannel;
  String? paymentNetwork;
  String? paymentPhone;
  double? paidAmountGhs;
  double? paidAmountUsd;
  DateTime? paidAt;
  String? driverPayoutStatus; // 'pending_delivery', 'ready_for_payout', 'paid_out'
  String? refundStatus; // 'refund_requested', 'refund_otp_pending', 'refund_processing', 'refunded', 'refund_failed'
  String? refundReference;
  double? refundAmountUsd;
  double? refundAmountGhs;
  String? refundMethod;
  String? refundAccount;
  String? refundAccountName;
  String? refundFailureReason;
  DateTime? refundedAt;
  DateTime? lastDriverCancelledAt;
  int driverCancellationCount;

  // Driver & Vehicle Details (Assigned once confirmed)
  String? driverId;
  String? driverName;
  String? driverPhone;
  String? vehiclePlate;
  String? vehicleModel;
  double? driverRating;
  String? chatSessionId;

  // Advanced Pricing, Trip Classification & Driver Allowances
  String tripType; // 'single' or 'round_trip'
  String roundTripLegMode; // 'loaded_loaded', 'loaded_empty', 'empty_loaded', 'empty_empty'
  String journeyCategory; // 'short' (<=30km), 'medium' (30-150km), 'long' (>150km)
  bool isHazardous;
  double containerDeckSurcharge;
  double emptyReturnDiscount;
  double excessWeightFee;
  double specialSurcharges;
  double roadAllowance;
  double overnightAllowance;
  double fragileBonus;
  double loadingLaborFee;
  double driverEarnings;
  double platformFee;
  String currency;

  // Inventory List (Item Name & Quantity)
  List<Map<String, dynamic>> inventory;

  // Multi-Stop Route Support
  List<Map<String, dynamic>> stops; // List of { 'address': String, 'lat': double, 'lng': double }

  BookingModel({
    required this.id,
    required this.userId,
    this.cargoType = 'Container',
    this.containerSize = '',
    this.containerStatus = 'Empty',
    this.loadDescription = '',
    this.senderName = '',
    this.senderPhone = '',
    this.receiverName = '',
    this.receiverPhone = '',
    this.status = 'pending',
    required this.timestamp,
    this.documents = const [],
    this.truckType = '',
    this.price = 0.0,
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.weight = 0.0,
    this.distance = 0.0,
    this.bookingId = '',
    this.pickupLocation,
    this.dropoffLocation,
    this.isFragile = false,
    this.isInsured = false,
    this.requiresLoadingAssistance = false,
    this.isHazardous = false,
    this.tripType = 'single',
    this.roundTripLegMode = 'loaded_loaded',
    this.journeyCategory = 'Short Journey',
    this.containerDeckSurcharge = 0.0,
    this.emptyReturnDiscount = 0.0,
    this.excessWeightFee = 0.0,
    this.specialSurcharges = 0.0,
    this.roadAllowance = 0.0,
    this.overnightAllowance = 0.0,
    this.fragileBonus = 0.0,
    this.loadingLaborFee = 0.0,
    this.driverEarnings = 0.0,
    this.platformFee = 0.0,
    this.currency = 'GHS',
    this.scheduledDate,
    this.cargoValue,
    this.paymentMethod = 'Cash on Delivery',
    this.initialPaymentMethod,
    this.paymentStatus = 'unpaid',
    this.paidOnline = false,
    this.paymentReference,
    this.paymentChannel,
    this.paymentNetwork,
    this.paymentPhone,
    this.paidAmountGhs,
    this.paidAmountUsd,
    this.paidAt,
    this.driverPayoutStatus,
    this.refundStatus,
    this.refundReference,
    this.refundAmountUsd,
    this.refundAmountGhs,
    this.refundMethod,
    this.refundAccount,
    this.refundAccountName,
    this.refundFailureReason,
    this.refundedAt,
    this.lastDriverCancelledAt,
    this.driverCancellationCount = 0,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.vehiclePlate,
    this.vehicleModel,
    this.driverRating,
    this.chatSessionId,
    this.inventory = const [],
    this.stops = const [],
  });

  bool get isPaidOnline =>
      paidOnline ||
      paymentStatus.toLowerCase().trim() == 'paid' ||
      ((paymentMethod ?? '').toLowerCase().contains('paystack') &&
          (paymentReference ?? '').isNotEmpty);

  bool get isLoadedOnTruckOrInTransit {
    final clean = status.toLowerCase().trim().replaceAll(RegExp(r'[^a-z]'), '');
    return clean == 'intransit' ||
        clean == 'pickedup' ||
        clean == 'loaded' ||
        clean == 'loadedontruck';
  }

  bool get requiresOnlinePaymentPrompt {
    final clean = status.toLowerCase().trim().replaceAll(RegExp(r'[^a-z]'), '');
    return isLoadedOnTruckOrInTransit && !isPaidOnline && clean != 'cancelled' && clean != 'canceled';
  }

  String get normalizedRefundStatus => (refundStatus ?? '').toLowerCase().trim();
  bool get isRefunded => normalizedRefundStatus == 'refunded';
  bool get isRefundRequested => normalizedRefundStatus == 'refund_requested';
  bool get isRefundProcessing =>
      normalizedRefundStatus == 'refund_processing' || normalizedRefundStatus == 'refund_otp_pending';
  bool get isRefundFailed => normalizedRefundStatus == 'refund_failed';

  bool get isCancelled {
    final clean = status.toLowerCase().trim();
    return clean == 'cancelled' || clean == 'canceled';
  }

  /// Shipper may cancel directly only before cargo is picked up / loaded onto truck
  bool get canShipperCancelDirectly {
    final clean = status.toLowerCase().trim().replaceAll(RegExp(r'[^a-z]'), '');
    return clean == 'pending' ||
        clean == 'available' ||
        clean == 'open' ||
        clean == 'unassigned' ||
        clean == 'confirmed' ||
        clean == 'accepted' ||
        clean == 'assigned' ||
        clean == 'onthewaytopickup';
  }

  static BookingModel empty() => BookingModel(
    id: '',
    userId: '',
    timestamp: DateTime.now(),
  );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'cargoType': cargoType,
      'containerSize': containerSize,
      'containerStatus': containerStatus,
      'loadDescription': loadDescription,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'documents': documents,
      'truckType': truckType,
      'price': price,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'weight': weight,
      'distance': distance,
      'bookingId': bookingId,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'isFragile': isFragile,
      'isInsured': isInsured,
      'requiresLoadingAssistance': requiresLoadingAssistance,
      'isHazardous': isHazardous,
      'tripType': tripType,
      'roundTripLegMode': roundTripLegMode,
      'journeyCategory': journeyCategory,
      'containerDeckSurcharge': containerDeckSurcharge,
      'emptyReturnDiscount': emptyReturnDiscount,
      'excessWeightFee': excessWeightFee,
      'specialSurcharges': specialSurcharges,
      'roadAllowance': roadAllowance,
      'overnightAllowance': overnightAllowance,
      'fragileBonus': fragileBonus,
      'loadingLaborFee': loadingLaborFee,
      'driverEarnings': driverEarnings,
      'platformFee': platformFee,
      'currency': currency,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'cargoValue': cargoValue,
      'paymentMethod': paymentMethod,
      if (initialPaymentMethod != null) 'initialPaymentMethod': initialPaymentMethod,
      'paymentStatus': paymentStatus,
      'paidOnline': paidOnline,
      if (paymentReference != null) 'paymentReference': paymentReference,
      if (paymentChannel != null) 'paymentChannel': paymentChannel,
      if (paymentNetwork != null) 'paymentNetwork': paymentNetwork,
      if (paymentPhone != null) 'paymentPhone': paymentPhone,
      if (paidAmountGhs != null) 'paidAmountGhs': paidAmountGhs,
      if (paidAmountUsd != null) 'paidAmountUsd': paidAmountUsd,
      if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
      if (driverPayoutStatus != null) 'driverPayoutStatus': driverPayoutStatus,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'vehiclePlate': vehiclePlate,
      'vehicleModel': vehicleModel,
      'driverRating': driverRating,
      if (chatSessionId != null) 'chatSessionId': chatSessionId,
      'inventory': inventory,
      'stops': stops,
    };
  }

  factory BookingModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> document) {
    if (document.data() != null) {
      final data = document.data()!;
      return BookingModel(
        id: document.id,
        userId: data['userId'] ?? '',
        cargoType: data['cargoType'] ?? 'Container',
        containerSize: data['containerSize'] ?? '',
        containerStatus: data['containerStatus'] ?? 'Empty',
        loadDescription: data['loadDescription'] ?? '',
        senderName: data['senderName'] ?? '',
        senderPhone: data['senderPhone'] ?? '',
        receiverName: data['receiverName'] ?? '',
        receiverPhone: data['receiverPhone'] ?? '',
        status: data['status'] ?? 'pending',
        timestamp: data['timestamp'] != null 
          ? (data['timestamp'] is Timestamp ? (data['timestamp'] as Timestamp).toDate() : DateTime.parse(data['timestamp'])) 
          : DateTime.now(),
        documents: (data['documents'] as List<dynamic>?)?.map((e) => Map<String, String>.from(e)).toList() ?? [],
        truckType: data['truckType'] ?? '',
        price: (data['price'] ?? 0.0).toDouble(),
        pickupAddress: data['pickupAddress'] ?? '',
        dropoffAddress: data['dropoffAddress'] ?? '',
        weight: (data['weight'] ?? 0.0).toDouble(),
        distance: (data['distance'] ?? 0.0).toDouble(),
        bookingId: data['bookingId'] ?? document.id,
        pickupLocation: data['pickupLocation'],
        dropoffLocation: data['dropoffLocation'],
        isFragile: data['isFragile'] ?? false,
        isInsured: data['isInsured'] ?? false,
        requiresLoadingAssistance: data['requiresLoadingAssistance'] ?? false,
        isHazardous: data['isHazardous'] ?? false,
        tripType: data['tripType'] ?? 'single',
        roundTripLegMode: data['roundTripLegMode'] ?? 'loaded_loaded',
        journeyCategory: data['journeyCategory'] ?? 'Short Journey',
        containerDeckSurcharge: (data['containerDeckSurcharge'] ?? 0.0).toDouble(),
        emptyReturnDiscount: (data['emptyReturnDiscount'] ?? 0.0).toDouble(),
        excessWeightFee: (data['excessWeightFee'] ?? 0.0).toDouble(),
        specialSurcharges: (data['specialSurcharges'] ?? 0.0).toDouble(),
        roadAllowance: (data['roadAllowance'] ?? 0.0).toDouble(),
        overnightAllowance: (data['overnightAllowance'] ?? 0.0).toDouble(),
        fragileBonus: (data['fragileBonus'] ?? 0.0).toDouble(),
        loadingLaborFee: (data['loadingLaborFee'] ?? 0.0).toDouble(),
        driverEarnings: (data['driverEarnings'] ?? 0.0).toDouble(),
        platformFee: (data['platformFee'] ?? 0.0).toDouble(),
        currency: data['currency'] ?? 'GHS',
        scheduledDate: data['scheduledDate'] != null
            ? (data['scheduledDate'] is Timestamp
                ? (data['scheduledDate'] as Timestamp).toDate()
                : DateTime.tryParse(data['scheduledDate'].toString()))
            : null,
        cargoValue: (data['cargoValue'] ?? 0.0).toDouble(),
        paymentMethod: data['paymentMethod'] ?? 'Cash on Delivery',
        initialPaymentMethod: data['initialPaymentMethod']?.toString(),
        paymentStatus: (data['paymentStatus'] ?? (data['paidOnline'] == true ? 'paid' : 'unpaid')).toString(),
        paidOnline: data['paidOnline'] == true || (data['paymentStatus']?.toString().toLowerCase() == 'paid'),
        paymentReference: data['paymentReference']?.toString(),
        paymentChannel: data['paymentChannel']?.toString(),
        paymentNetwork: data['paymentNetwork']?.toString(),
        paymentPhone: data['paymentPhone']?.toString(),
        paidAmountGhs: data['paidAmountGhs'] != null ? (data['paidAmountGhs'] as num).toDouble() : null,
        paidAmountUsd: data['paidAmountUsd'] != null ? (data['paidAmountUsd'] as num).toDouble() : null,
        paidAt: data['paidAt'] != null
            ? (data['paidAt'] is Timestamp
                ? (data['paidAt'] as Timestamp).toDate()
                : DateTime.tryParse(data['paidAt'].toString()))
            : null,
        driverPayoutStatus: data['driverPayoutStatus']?.toString(),
        refundStatus: data['refundStatus']?.toString(),
        refundReference: data['refundReference']?.toString(),
        refundAmountUsd: data['refundAmountUsd'] != null ? (data['refundAmountUsd'] as num).toDouble() : null,
        refundAmountGhs: data['refundAmountGhs'] != null ? (data['refundAmountGhs'] as num).toDouble() : null,
        refundMethod: data['refundMethod']?.toString(),
        refundAccount: data['refundAccount']?.toString(),
        refundAccountName: data['refundAccountName']?.toString(),
        refundFailureReason: data['refundFailureReason']?.toString(),
        refundedAt: data['refundedAt'] != null
            ? (data['refundedAt'] is Timestamp
                ? (data['refundedAt'] as Timestamp).toDate()
                : DateTime.tryParse(data['refundedAt'].toString()))
            : null,
        lastDriverCancelledAt: data['lastDriverCancelledAt'] != null
            ? (data['lastDriverCancelledAt'] is Timestamp
                ? (data['lastDriverCancelledAt'] as Timestamp).toDate()
                : DateTime.tryParse(data['lastDriverCancelledAt'].toString()))
            : null,
        driverCancellationCount: (data['driverCancellationCount'] is num)
            ? (data['driverCancellationCount'] as num).toInt()
            : 0,
        driverId: data['driverId'],
        driverName: data['driverName'],
        driverPhone: data['driverPhone'],
        vehiclePlate: data['vehiclePlate'],
        vehicleModel: data['vehicleModel'],
        driverRating: (data['driverRating'] ?? 0.0).toDouble(),
        chatSessionId: data['chatSessionId']?.toString(),
        inventory: (data['inventory'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
        stops: (data['stops'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
      );
    } else {
      return BookingModel.empty();
    }
  }
}
