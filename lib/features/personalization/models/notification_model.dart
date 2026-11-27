import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String type; // e.g., 'chat', 'booking', 'order', 'payment', 'promotion', 'security'
  final String? targetId; // ID of the related entity (e.g., bookingId)

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.type = 'general',
    this.targetId,
  });

  String get normalizedType => type.toLowerCase().trim();

  bool get hasTarget => (targetId ?? '').trim().isNotEmpty;

  bool get isChatNotification {
    if (normalizedType == 'chat' ||
        normalizedType == 'message' ||
        normalizedType == 'messages') {
      return true;
    }
    if (normalizedType == 'general' && hasTarget) {
      final lowerTitle = title.toLowerCase().trim();
      return lowerTitle.startsWith('message from ') ||
          lowerTitle.startsWith('voice note from ') ||
          lowerTitle.contains('new message');
    }
    return false;
  }

  bool get isPaymentDueNotification => normalizedType == 'booking_payment_due';

  bool get isBookingNotification => const {
        'order',
        'booking',
        'job',
        'delivery',
        'pod',
        'geofence',
        'payment',
        'booking_payment_due',
        'booking_paid',
        'shipper_refund',
        'refund',
        'driver_cancelled_booking',
      }.contains(normalizedType);

  bool get isSecurityNotification => const {
        'security',
        'kyc',
        'kyb',
        'verification',
      }.contains(normalizedType);

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? targetId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
    );
  }

  static NotificationModel empty() => NotificationModel(
        id: '',
        title: '',
        body: '',
        timestamp: DateTime.now(),
      );

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type,
      'targetId': targetId,
    };
  }

  static DateTime _parseTimestamp(dynamic raw, dynamic fallback) {
    final value = raw ?? fallback;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  factory NotificationModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> document) {
    if (document.data() != null) {
      final data = document.data()!;
      final rawBody = (data['body'] ?? data['message'] ?? '').toString();
      final rawTargetId = (data['targetId'] ?? data['bookingId'])?.toString().trim();

      return NotificationModel(
        id: document.id,
        title: (data['title'] ?? '').toString(),
        body: rawBody,
        timestamp: _parseTimestamp(data['timestamp'], data['createdAt']),
        isRead: data['isRead'] == true,
        type: (data['type'] ?? 'general').toString(),
        targetId: (rawTargetId != null && rawTargetId.isNotEmpty) ? rawTargetId : null,
      );
    } else {
      return NotificationModel.empty();
    }
  }
}
