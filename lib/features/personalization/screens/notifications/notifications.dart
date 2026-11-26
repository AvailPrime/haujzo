import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../data/repositories/bookings/booking_repository.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../controllers/notification_controller.dart';
import '../../../shop/screens/bookings/booking_details_screen.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../../routes/routes.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NotificationController());
    final dark = AvailHelperFunctions.isDarkMode(context);

    final bgColor = dark ? AvailColors.dark : const Color(0xFFF8FAFC);
    final cardColor = dark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = dark ? Colors.grey.shade400 : Colors.grey.shade700;

    final isWide = SiteLayout.isWideScreen(context);
    final isEmbedded = isWide && !Navigator.canPop(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isEmbedded
          ? null
          : AvailAppbar(
              title: const Text(
                'Notifications & Alerts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
              ),
              showBackArrow: true,
              showBackgroundColor: true,
              backArrowColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Iconsax.refresh, color: Colors.white, size: 20),
                  onPressed: () => controller.fetchNotifications(),
                ),
              ],
            ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AvailColors.primary),
          );
        }

        final notifications = controller.allNotifications;
        final unreadCount = notifications.where((n) => !n.isRead).length;

        if (notifications.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AvailColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.notification_bing, size: 48, color: AvailColors.primary),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No Notifications Yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You will receive live updates when a driver is assigned to your cargo, en route to pickup, arrives at the terminal, or submits Proof of Delivery.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: bodyColor, height: 1.45),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AvailColors.primary,
          onRefresh: () => controller.fetchNotifications(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 24 : 16,
              vertical: 16,
            ),
            child: ResponsiveCenter(
              maxWidth: 920,
              child: Column(
                children: [
              // Summary Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.radar_2, size: 16, color: AvailColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'DISPATCH TELEMETRY LOGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AvailColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount Unread',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      )
                    else
                      Text(
                        'All caught up',
                        style: TextStyle(fontSize: 11, color: bodyColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Notification List
              ...notifications.map((notification) {
                final isUnread = !notification.isRead;
                final iconCol = _getNotificationColor(notification.type);
                final iconData = _getNotificationIcon(notification.type);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUnread ? AvailColors.primary.withValues(alpha: 0.6) : borderColor,
                      width: isUnread ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUnread ? AvailColors.primary.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    onTap: () async {
                      await controller.markAsRead(notification.id);
                      if ((notification.type == 'order' || notification.type == 'booking') && notification.targetId != null) {
                        try {
                          final bookingRepository = Get.put(BookingRepository());
                          final booking = await bookingRepository.fetchBookingById(notification.targetId!);
                          if (booking != null) {
                            if (Get.isRegistered<NavigationController>()) {
                              NavigationController.instance.openSubScreen(
                                BookingDetailsScreen(booking: booking),
                                title: 'Manifest Details',
                              );
                            } else {
                              Get.toNamed(AvailRoutes.bookingDetails, arguments: booking);
                            }
                          }
                        } catch (e) {
                          debugPrint('Error opening booking from notification: $e');
                        }
                      }
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconCol.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconData, color: iconCol, size: 22),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AvailColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: TextStyle(fontSize: 12, color: bodyColor, height: 1.35),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Iconsax.clock, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimestamp(notification.timestamp),
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
          ),
          ),
        );
      }),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'order':
      case 'booking':
        return Iconsax.truck_fast;
      case 'delivery':
      case 'pod':
        return Iconsax.box_tick;
      case 'promotion':
        return Iconsax.discount_shape;
      case 'security':
      case 'kyc':
        return Iconsax.shield_tick;
      default:
        return Iconsax.notification;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'order':
      case 'booking':
        return AvailColors.primary;
      case 'delivery':
      case 'pod':
        return Colors.green;
      case 'promotion':
        return Colors.amber.shade800;
      case 'security':
      case 'kyc':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('dd MMM yyyy • HH:mm').format(timestamp);
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hr${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
