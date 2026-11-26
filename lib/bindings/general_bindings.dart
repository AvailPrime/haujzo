import 'package:get/get.dart';
import '../commons/widgets/network/network_manager.dart';
import '../data/repositories/authentication/authentication_repository.dart';
import '../data/repositories/bookings/booking_repository.dart';
import '../data/repositories/user/app_user_repository.dart';
import '../data/repositories/payment/paystack_repository.dart';
import '../data/repositories/support/support_config_repository.dart';
import '../features/personalization/controllers/address_controller.dart';
import '../features/personalization/controllers/localization_controller.dart';
import '../features/personalization/controllers/payment_controller.dart';
import '../features/personalization/controllers/settings_controller.dart';
import '../features/personalization/controllers/user_controller.dart';
import '../features/shop/controllers/customer/customer_home_controller.dart';
import '../features/shop/controllers/customer/trip_payment_controller.dart';
import '../utils/notifications/push_notification_service.dart';
import '../utils/notifications/trip_payment_alert_service.dart';

class GeneralBindings extends Bindings {
  @override
  void dependencies() {
    // Always put these - Required for UI & Network
    Get.put(NetworkManager(), permanent: true);
    Get.put(LocalizationController(), permanent: true);
    
    // Auth & Core Repositories
    Get.put(AuthenticationRepository(), permanent: true);
    Get.put(BookingRepository(), permanent: true);
    Get.put(AppUserRepository(), permanent: true);
    Get.put(PaystackRepository(), permanent: true);
    Get.put(SupportConfigRepository(), permanent: true);

    // Freight, Payment Alerts & Push Controllers
    Get.put(TripPaymentAlertService(), permanent: true);
    Get.put(TripPaymentController(), permanent: true);
    Get.put(CustomerHomeController(), permanent: true);
    Get.put(PushNotificationService(), permanent: true);

    // Core User & Personalization Controllers
    Get.put(UserController(), permanent: true);
    Get.put(SettingsController(), permanent: true);
    Get.put(AddressController(), permanent: true);

    // Payment Controller
    Get.lazyPut<PaymentController>(() => PaymentController());
  }
}
