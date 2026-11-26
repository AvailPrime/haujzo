import '../../../features/personalization/models/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../utils/exceptions/firebase_exception.dart';
import '../../../utils/exceptions/format_exception.dart';
import '../../../utils/exceptions/platform_exception.dart';
import '../authentication/authentication_repository.dart';

class NotificationRepository extends GetxController {
  static NotificationRepository get instance => Get.find();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch user notifications (One-time fetch)
  Future<List<NotificationModel>> fetchUserNotifications() async {
    try {
      final userId = AuthenticationRepository.instance.authUser?.uid;
      if (userId == null) throw 'User not authenticated';

      final snapshot = await _db
          .collection('Users')
          .doc(userId)
          .collection('Notifications')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) => NotificationModel.fromSnapshot(doc)).toList();
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } on FormatException catch (_) {
      throw AvailFormatException('invalid-json').message;
    } on PlatformException catch (e) {
      throw AvailPlatformException(e.code).message;
    } catch (e) {
      throw 'Something went wrong while fetching notifications. Please try again.';
    }
  }

  /// Get Notifications Stream (Real-time updates)
  Stream<List<NotificationModel>> getNotificationsStream() {
    final userId = AuthenticationRepository.instance.authUser?.uid;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('Users')
        .doc(userId)
        .collection('Notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NotificationModel.fromSnapshot(doc)).toList());
  }

  /// Save notification to Firestore
  Future<void> saveNotification(String userId, NotificationModel notification) async {
    try {
      await _db
          .collection('Users')
          .doc(userId)
          .collection('Notifications')
          .add(notification.toJson());
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } catch (e) {
      throw 'Failed to save notification: $e';
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final userId = AuthenticationRepository.instance.authUser?.uid;
      if (userId == null) throw 'User not authenticated';

      await _db
          .collection('Users')
          .doc(userId)
          .collection('Notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } on FormatException catch (_) {
      throw AvailFormatException('invalid-json').message;
    } on PlatformException catch (e) {
      throw AvailPlatformException(e.code).message;
    } catch (e) {
      throw 'Something went wrong. Please try again.';
    }
  }
}
