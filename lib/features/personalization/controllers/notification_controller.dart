import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../commons/widgets/loader/loaders.dart';
import '../../../data/repositories/bookings/booking_repository.dart';
import '../../../data/repositories/notifications/notification_repository.dart';
import '../../../navigation_menu.dart';
import '../../../routes/routes.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/helpers/helper_functions.dart';
import '../../shop/models/booking_model.dart';
import '../../shop/screens/bookings/booking_details_screen.dart';
import '../../shop/screens/chat/trip_chat_screen.dart';
import '../models/notification_model.dart';

class NotificationController extends GetxController {
  static NotificationController get instance => Get.find();

  final isLoading = false.obs;
  final RxnString openingNotificationId = RxnString();
  final notificationRepository = Get.put(NotificationRepository());
  RxList<NotificationModel> allNotifications = <NotificationModel>[].obs;

  @override
  void onInit() {
    allNotifications.bindStream(notificationRepository.getNotificationsStream());
    super.onInit();
  }

  Future<void> fetchNotifications() async {
    try {
      isLoading.value = true;
      final notifications = await notificationRepository.fetchUserNotifications();
      allNotifications.assignAll(notifications);
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Oh Snap!', message: e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      final index = allNotifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !allNotifications[index].isRead) {
        allNotifications[index] = allNotifications[index].copyWith(isRead: true);
      }
      await notificationRepository.markAsRead(notificationId);
    } catch (_) {
      // Silent error for marking as read
    }
  }

  Future<void> markAllAsRead() async {
    final unreadIds = allNotifications
        .where((n) => !n.isRead && n.id.isNotEmpty)
        .map((n) => n.id)
        .toList();
    if (unreadIds.isEmpty) return;

    try {
      for (int i = 0; i < allNotifications.length; i++) {
        if (!allNotifications[i].isRead) {
          allNotifications[i] = allNotifications[i].copyWith(isRead: true);
        }
      }
      await notificationRepository.markAllAsRead(unreadIds);
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Update Failed', message: e.toString());
    }
  }

  /// Unified tap handler for in-app notification items.
  /// - Message notifications open TripChatScreen ONLY while the booking is active & assigned.
  /// - If a booking is completed/cancelled/unassigned, message notifications open BookingDetailsScreen
  ///   with a clear notice that live chat is closed.
  /// - Booking/payment/delivery/refund notifications open BookingDetailsScreen.
  /// - Security/KYC notifications open verification/details.
  /// - General/system/promo notifications open a full-detail bottom sheet so every tap responds.
  Future<void> handleNotificationTap(
    NotificationModel notification, {
    BuildContext? context,
  }) async {
    if (openingNotificationId.value != null) return;

    // Mark as read without blocking navigation (and without losing targetId)
    if (!notification.isRead && notification.id.isNotEmpty) {
      unawaited(markAsRead(notification.id));
    }

    openingNotificationId.value = notification.id;
    final bool isEmbeddedInNav =
        context != null && !Navigator.canPop(context) && Get.isRegistered<NavigationController>();
    try {
      await routeNotification(
        type: notification.type,
        targetId: notification.targetId ?? '',
        notification: notification,
        isEmbeddedInNav: isEmbeddedInNav,
      );
    } finally {
      openingNotificationId.value = null;
    }
  }

  /// Shared navigation router used by both NotificationsScreen and PushNotificationService.
  static Future<void> routeNotification({
    required String type,
    required String targetId,
    NotificationModel? notification,
    bool isEmbeddedInNav = false,
  }) async {
    final cleanType = type.toLowerCase().trim();
    final cleanTarget = targetId.trim();

    final isChat = notification?.isChatNotification ??
        (cleanType == 'chat' || cleanType == 'message' || cleanType == 'messages');
    final isPaymentDue = cleanType == 'booking_payment_due';
    final isSecurity = notification?.isSecurityNotification ??
        const {'security', 'kyc', 'kyb', 'verification'}.contains(cleanType);
    final isBanner = cleanType == 'banner';

    if (isBanner && cleanTarget.isNotEmpty) {
      Get.toNamed(cleanTarget);
      return;
    }

    // 1. Message / Chat notification -> open chat ONLY when booking is active & tied to a driver
    if (isChat) {
      if (cleanTarget.isEmpty) {
        if (notification != null) {
          _showNotificationDetailSheet(notification);
        }
        return;
      }

      final booking = await _fetchBookingSafely(cleanTarget);
      if (booking == null) {
        if (notification != null) {
          _showNotificationDetailSheet(
            notification,
            footerNote: 'The booking associated with this message could not be found.',
          );
        } else {
          AvailLoaders.warningSnackBar(
            title: 'Booking Unavailable',
            message: 'The booking linked to this message is no longer available.',
          );
        }
        return;
      }

      if (booking.canChatWithDriver) {
        Get.to(() => TripChatScreen(booking: booking));
      } else {
        _openBookingDetails(booking, isEmbeddedInNav: isEmbeddedInNav);
        final String closedMessage;
        if (booking.isCancelled) {
          closedMessage =
              'This booking was cancelled, so live driver messaging is closed. You can view archived history inside Booking Details.';
        } else if (booking.isCompleted) {
          closedMessage =
              'This shipment has been completed, so live driver messaging is closed. You can view archived history inside Booking Details.';
        } else {
          closedMessage =
              'No driver is currently assigned to this booking, so live chat is paused.';
        }
        AvailLoaders.infoSnackBar(
          title: 'Trip Chat Closed',
          message: closedMessage,
        );
      }
      return;
    }

    // 2. Security / Verification notifications
    if (isSecurity) {
      final lowerTitle = (notification?.title ?? '').toLowerCase();
      if (cleanType == 'kyc' ||
          cleanType == 'kyb' ||
          cleanType == 'verification' ||
          lowerTitle.contains('kyc') ||
          lowerTitle.contains('kyb') ||
          lowerTitle.contains('verif')) {
        Get.toNamed(AvailRoutes.diditVerification);
        return;
      }
      if (notification != null) {
        _showNotificationDetailSheet(notification);
      }
      return;
    }

    // 3. Booking / Order / Delivery / Payment / Refund / Geofence / Any notification with a booking targetId
    final isBookingType = notification?.isBookingNotification ??
        const {
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
        }.contains(cleanType);

    if (cleanTarget.isNotEmpty && (isBookingType || cleanType == 'general' || cleanType == 'system')) {
      final booking = await _fetchBookingSafely(cleanTarget);
      if (booking != null) {
        _openBookingDetails(
          booking,
          isEmbeddedInNav: isEmbeddedInNav,
          openPaymentSheetOnLoad: isPaymentDue && !booking.isPaidOnline,
        );
        return;
      }
    }

    // 4. Fallback: always present the full notification details sheet so clicks never feel dead
    if (notification != null) {
      _showNotificationDetailSheet(
        notification,
        footerNote: cleanTarget.isNotEmpty
            ? 'The linked booking record could not be located.'
            : null,
      );
    }
  }

  static Future<BookingModel?> _fetchBookingSafely(String bookingId) async {
    try {
      final bookingRepository = Get.isRegistered<BookingRepository>()
          ? Get.find<BookingRepository>()
          : Get.put(BookingRepository());
      return await bookingRepository.fetchBookingById(bookingId);
    } catch (e) {
      debugPrint('Error fetching booking $bookingId from notification: $e');
      return null;
    }
  }

  static void _openBookingDetails(
    BookingModel booking, {
    bool isEmbeddedInNav = false,
    bool openPaymentSheetOnLoad = false,
  }) {
    final screen = BookingDetailsScreen(
      booking: booking,
      openPaymentSheetOnLoad: openPaymentSheetOnLoad,
    );

    if (isEmbeddedInNav && Get.isRegistered<NavigationController>()) {
      NavigationController.instance.openSubScreen(
        screen,
        title: 'Manifest Details',
      );
    } else {
      Get.to(
        () => screen,
        routeName: AvailRoutes.bookingDetails,
      );
    }
  }

  static void _showNotificationDetailSheet(
    NotificationModel notification, {
    String? footerNote,
  }) {
    final ctx = Get.context;
    if (ctx == null) return;
    final dark = AvailHelperFunctions.isDarkMode(ctx);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: dark ? const Color(0xFF132238) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AvailColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notification.type.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AvailColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Iconsax.clock, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy • HH:mm').format(notification.timestamp),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notification.title.isNotEmpty ? notification.title : 'Notification',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (notification.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notification.body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: dark ? Colors.grey.shade300 : const Color(0xFF334155),
                  ),
                ),
              ],
              if (footerNote != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    footerNote,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.amber.shade200 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AvailColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
