import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../data/repositories/authentication/authentication_repository.dart';
import '../../features/personalization/controllers/notification_controller.dart';
import '../../features/personalization/models/notification_model.dart';
import 'trip_payment_alert_service.dart';

class PushNotificationService extends GetxController {
  static PushNotificationService get instance => Get.find();

  /// Tracks the booking ID currently open in TripChatScreen so we don't fire
  /// redundant local alert banners for the conversation the user is already viewing.
  static String? activeChatBookingId;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RxBool isPermissionGranted = false.obs;
  StreamSubscription? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _userNotificationsSubscription;
  final Map<String, String> _lastKnownStatuses = {};
  final Set<String> _seenNotificationIds = {};
  bool _hasInitializedNotifListener = false;

  @override
  void onInit() {
    super.onInit();
    initialize();

    // Listen to Auth State changes to bind FCM token and real-time listeners
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        syncFCMToken();
        listenToUserBookingsForNotifications(user.uid);
        listenToIncomingChatNotifications(user.uid);
      } else {
        _bookingsSubscription?.cancel();
        _userNotificationsSubscription?.cancel();
        _lastKnownStatuses.clear();
        _seenNotificationIds.clear();
        _hasInitializedNotifListener = false;
      }
    });
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _userNotificationsSubscription?.cancel();
    super.onClose();
  }

  Future<void> initialize() async {
    try {
      await requestPermission();
      if (!kIsWeb) {
        await _initializeLocalNotifications();
      }
      await syncFCMToken();

      if (kIsWeb) return;

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(newToken);
      });

      // Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      // Handle Background & Terminated Clicks
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClickFromData(message.data);
      });

      // Check if app was opened via notification when terminated
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClickFromData(initialMessage.data);
      }
    } catch (e) {
      debugPrint('PushNotificationService initialize skipped: $e');
    }
  }

  Future<void> requestPermission() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        isPermissionGranted.value = true;
      } else {
        isPermissionGranted.value = false;
      }
    } catch (e) {
      isPermissionGranted.value = false;
      debugPrint('PushNotificationService requestPermission skipped: $e');
    }
  }

  Future<void> syncFCMToken() async {
    if (kIsWeb) return;
    try {
      final user = AuthenticationRepository.instance.authUser;
      if (user != null) {
        String? token = await _fcm.getToken();
        if (token != null) {
          await _saveTokenToFirestore(token);
        }
      }
    } catch (e) {
      debugPrint('PushNotificationService syncFCMToken skipped: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = AuthenticationRepository.instance.authUser;
    if (user != null) {
      await _db.collection('Users').doc(user.uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handleNotificationClick(response.payload!);
        }
      },
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      final targetId = (message.data['targetId'] ?? message.data['bookingId'] ?? '').toString();
      final type = (message.data['type'] ?? 'general').toString();

      // Suppress foreground banner if user is already viewing this exact chat
      if ((type.toLowerCase() == 'chat' || type.toLowerCase() == 'message') &&
          targetId.isNotEmpty &&
          activeChatBookingId == targetId) {
        return;
      }

      String? imageUrl = android?.imageUrl ?? message.data['image'];
      BigPictureStyleInformation? bigPictureStyle;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final String? filePath = await _downloadAndSaveFile(imageUrl, 'notification_img.jpg');
        if (filePath != null) {
          bigPictureStyle = BigPictureStyleInformation(
            FilePathAndroidBitmap(filePath),
            largeIcon: FilePathAndroidBitmap(filePath),
            contentTitle: notification.title,
            summaryText: notification.body,
          );
        }
      }

      AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: bigPictureStyle,
      );

      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: const DarwinNotificationDetails(),
      );

      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: '$type|$targetId',
      );
    }
  }

  Future<String?> _downloadAndSaveFile(String url, String fileName) async {
    try {
      final Directory directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/$fileName';
      final http.Response response = await http.get(Uri.parse(url));
      final File file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } catch (e) {
      return null;
    }
  }

  void _handleNotificationClick(String payload) {
    final parts = payload.split('|');
    if (parts.length >= 2) {
      final type = parts[0];
      final targetId = parts.sublist(1).join('|');
      _navigateToScreen(type, targetId);
    }
  }

  void _handleNotificationClickFromData(Map<String, dynamic> data) {
    final type = (data['type'] ?? 'general').toString();
    final targetId = (data['targetId'] ?? data['bookingId'] ?? '').toString();
    if (type.isNotEmpty || targetId.isNotEmpty) {
      _navigateToScreen(type, targetId);
    }
  }

  Future<void> _navigateToScreen(String type, String targetId) async {
    await NotificationController.routeNotification(
      type: type,
      targetId: targetId,
    );
  }

  Future<void> checkPermissionStatus() async {
    NotificationSettings settings = await _fcm.getNotificationSettings();
    isPermissionGranted.value = settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Listens to newly added unread chat notifications in Users/{uid}/Notifications
  /// so incoming driver messages show a tappable local notification banner that opens chat.
  void listenToIncomingChatNotifications(String userId) {
    _userNotificationsSubscription?.cancel();
    _seenNotificationIds.clear();
    _hasInitializedNotifListener = false;

    _userNotificationsSubscription = _db
        .collection('Users')
        .doc(userId)
        .collection('Notifications')
        .orderBy('timestamp', descending: true)
        .limit(25)
        .snapshots()
        .listen(
      (snapshot) {
        if (!_hasInitializedNotifListener) {
          for (final doc in snapshot.docs) {
            _seenNotificationIds.add(doc.id);
          }
          _hasInitializedNotifListener = true;
          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          if (_seenNotificationIds.contains(change.doc.id)) continue;
          _seenNotificationIds.add(change.doc.id);

          final notif = NotificationModel.fromSnapshot(change.doc);
          if (notif.isRead || !notif.isChatNotification) continue;

          // Skip if the user is already inside this chat screen
          if (notif.hasTarget && activeChatBookingId == notif.targetId) {
            continue;
          }

          _showCustomLocalNotification(
            notif.title.isNotEmpty ? notif.title : 'New Message from Driver 💬',
            notif.body.isNotEmpty ? notif.body : 'Tap to open trip chat.',
            payload: 'chat|${notif.targetId ?? ''}',
          );
        }
      },
      onError: (_) {},
    );
  }

  bool _isLoadedOrInTransitStatus(String status) {
    final clean = status.toLowerCase().trim().replaceAll(RegExp(r'[^a-z]'), '');
    return clean == 'intransit' ||
        clean == 'pickedup' ||
        clean == 'loaded' ||
        clean == 'loadedontruck';
  }

  void listenToUserBookingsForNotifications(String userId) {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final bookingId = change.doc.id;
        final newStatus = (data['status'] ?? '').toString();
        final isPaidOnline = data['paidOnline'] == true ||
            (data['paymentStatus'] ?? '').toString().toLowerCase() == 'paid';

        if (change.type == DocumentChangeType.modified) {
          final oldStatus = _lastKnownStatuses[bookingId];

          if (oldStatus != null && oldStatus != newStatus) {
            _triggerStatusChangeNotification(newStatus, bookingId, isPaidOnline: isPaidOnline);
          }
          _lastKnownStatuses[bookingId] = newStatus;
        } else if (change.type == DocumentChangeType.added) {
          _lastKnownStatuses[bookingId] = newStatus;
        }
      }
    });
  }

  void _triggerStatusChangeNotification(
    String status,
    String bookingId, {
    bool isPaidOnline = false,
  }) {
    String title = "Booking Status Update";
    String body = "Your freight booking status has changed to $status.";
    String payloadType = 'booking';
    bool isUrgentPayment = false;

    if (status == 'confirmed') {
      title = "Booking Confirmed! 🚚";
      body = "A driver has been assigned to your freight.";
    } else if (_isLoadedOrInTransitStatus(status)) {
      if (!isPaidOnline) {
        title = "Cargo Loaded on Truck! 💳";
        body = "Your cargo is loaded! Tap to pay the full trip fee securely online via Paystack.";
        payloadType = 'booking_payment_due';
        isUrgentPayment = true;
        TripPaymentAlertService.instance.triggerLoadedPaymentAlertById(bookingId);
      } else {
        title = "Freight In Transit 📦";
        body = "Your cargo is loaded and on its way. Online payment is already verified.";
      }
    } else if (status == 'delivered') {
      title = "Freight Delivered 🎉";
      body = "Your cargo has been successfully delivered.";
    }

    _showCustomLocalNotification(
      title,
      body,
      payload: '$payloadType|$bookingId',
      isUrgentPayment: isUrgentPayment,
    );
  }

  Future<void> _showCustomLocalNotification(
    String title,
    String body, {
    String? payload,
    bool isUrgentPayment = false,
  }) async {
    if (kIsWeb) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      isUrgentPayment ? 'trip_payment_alert_channel' : 'booking_updates_channel',
      isUrgentPayment ? 'Trip Payment Alerts' : 'Booking Updates',
      channelDescription: isUrgentPayment
          ? 'Loud payment alerts when cargo is loaded on truck'
          : 'Notifications for freight booking status changes',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      category: isUrgentPayment ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.status,
      audioAttributesUsage:
          isUrgentPayment ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true),
    );

    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
