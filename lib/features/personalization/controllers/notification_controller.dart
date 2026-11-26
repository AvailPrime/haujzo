import '../../../commons/widgets/loader/loaders.dart';
import '../../../data/repositories/notifications/notification_repository.dart';
import '../models/notification_model.dart';
import 'package:get/get.dart';

class NotificationController extends GetxController {
  static NotificationController get instance => Get.find();

  final isLoading = false.obs;
  final notificationRepository = Get.put(NotificationRepository());
  RxList<NotificationModel> allNotifications = <NotificationModel>[].obs;

  @override
  void onInit() {
    allNotifications.bindStream(notificationRepository.getNotificationsStream());
    super.onInit();
  }

  Future<void> fetchNotifications() async {
    // This is now handled by the bindStream, but we can keep it for manual refreshes if needed.
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
    try {
      await notificationRepository.markAsRead(notificationId);
      final index = allNotifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final n = allNotifications[index];
        allNotifications[index] = NotificationModel(
          id: n.id,
          title: n.title,
          body: n.body,
          timestamp: n.timestamp,
          isRead: true,
          type: n.type,
        );
      }
    } catch (e) {
      // Silent error for marking as read
    }
  }
}
