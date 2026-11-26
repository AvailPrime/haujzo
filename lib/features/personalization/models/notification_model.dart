import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String type; // e.g., 'order', 'promotion', 'security'
  final String? targetId; // ID of the related entity (e.g., orderId)

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.type = 'general',
    this.targetId,
  });

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

  factory NotificationModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> document) {
    if (document.data() != null) {
      final data = document.data()!;
      return NotificationModel(
        id: document.id,
        title: data['title'] ?? '',
        body: data['body'] ?? '',
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        isRead: data['isRead'] ?? false,
        type: data['type'] ?? 'general',
        targetId: data['targetId'],
      );
    } else {
      return NotificationModel.empty();
    }
  }
}
