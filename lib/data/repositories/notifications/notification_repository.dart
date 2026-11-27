import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../features/personalization/models/notification_model.dart';
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
      final userId =
          AuthenticationRepository.instance.authUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
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

  /// Get Notifications Stream (Real-time updates, automatically rebinds across auth changes)
  Stream<List<NotificationModel>> getNotificationsStream() {
    late StreamController<List<NotificationModel>> controller;
    StreamSubscription<User?>? authSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? notifSub;

    void bindForUser(User? user) {
      notifSub?.cancel();
      if (user == null) {
        if (!controller.isClosed) controller.add(<NotificationModel>[]);
        return;
      }

      notifSub = _db
          .collection('Users')
          .doc(user.uid)
          .collection('Notifications')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          if (!controller.isClosed) {
            controller.add(
              snapshot.docs.map((doc) => NotificationModel.fromSnapshot(doc)).toList(),
            );
          }
        },
        onError: (_) {
          // Keep existing notifications if transient read error occurs
        },
      );
    }

    controller = StreamController<List<NotificationModel>>(
      onListen: () {
        bindForUser(FirebaseAuth.instance.currentUser);
        authSub = FirebaseAuth.instance.authStateChanges().listen(bindForUser);
      },
      onCancel: () async {
        await authSub?.cancel();
        await notifSub?.cancel();
      },
    );

    return controller.stream;
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
      final userId =
          AuthenticationRepository.instance.authUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
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

  /// Mark all unread notifications as read
  Future<void> markAllAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    try {
      final userId =
          AuthenticationRepository.instance.authUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw 'User not authenticated';

      final batch = _db.batch();
      final col = _db.collection('Users').doc(userId).collection('Notifications');
      for (final id in notificationIds) {
        batch.update(col.doc(id), {'isRead': true});
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } catch (e) {
      throw 'Could not update notifications. Please try again.';
    }
  }
}
