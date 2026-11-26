import 'package:get/get.dart';
import 'routes.dart';

import '../features/authentication/screens/login/login.dart';
import '../features/authentication/screens/onboarding/onboarding.dart';
import '../features/authentication/screens/password_configuration/forget_password.dart';
import '../features/authentication/screens/password_configuration/reset_password.dart';
import '../features/authentication/screens/signup/signup.dart';
import '../features/authentication/screens/signup/verify_email.dart';
import '../features/personalization/screens/address/add_new_address.dart';
import '../features/personalization/screens/address/address.dart';
import '../features/personalization/screens/legal/about_us.dart';
import '../features/personalization/screens/legal/help_support.dart';
import '../features/personalization/screens/legal/privacy_policy.dart';
import '../features/personalization/screens/legal/terms_of_service.dart';
import '../features/personalization/screens/notifications/notifications.dart';
import '../features/personalization/screens/payment_methods/add_new_payment.dart';
import '../features/personalization/screens/payment_methods/payment_methods.dart';
import '../features/personalization/screens/privacy/privacy_settings.dart';
import '../features/personalization/screens/profile/profile.dart';
import '../features/personalization/screens/profile/widgets/change_name.dart';
import '../features/personalization/screens/profile/widgets/change_phonenumber.dart';
import '../features/personalization/screens/profile/widgets/change_username.dart';
import '../features/personalization/screens/settings/settings.dart';
import '../features/personalization/screens/truck_details/truck_details_screen.dart';
import '../features/personalization/screens/verification/didit_verification_screen.dart';
import '../features/shop/models/booking_model.dart';
import '../features/shop/screens/bookings/booking_details_screen.dart';
import '../features/shop/screens/bookings/my_bookings_screen.dart';
import '../features/shop/screens/customer_home/job_dispatch_screen.dart';
import '../features/shop/screens/driver_dashboard/driver_dashboard.dart';
import '../features/shop/screens/driver_dashboard/driver_navigation_menu.dart';
import '../navigation_menu.dart';
import '../commons/widgets/network/no_network_screen.dart';

class AppRoutes {
  static List<GetPage> get pages => [
    GetPage(name: AvailRoutes.navigationMenu, page: () => const NavigationMenu(initialIndex: 0)),
    GetPage(name: AvailRoutes.home, page: () => const NavigationMenu(initialIndex: 0)),
    GetPage(
      name: AvailRoutes.myBookings,
      page: () => Get.isRegistered<NavigationController>()
          ? const MyBookingsScreen()
          : const NavigationMenu(initialIndex: 1),
    ),
    GetPage(
      name: AvailRoutes.truckDetails,
      page: () => Get.isRegistered<NavigationController>()
          ? const TruckDetailsScreen()
          : const NavigationMenu(initialIndex: 2),
    ),
    GetPage(
      name: AvailRoutes.userPaymentMethods,
      page: () => Get.isRegistered<NavigationController>()
          ? const UserPaymentMethodsScreen()
          : const NavigationMenu(initialIndex: 3),
    ),
    GetPage(
      name: AvailRoutes.userAddress,
      page: () => Get.isRegistered<NavigationController>()
          ? const UserAddressScreen()
          : const NavigationMenu(initialIndex: 4),
    ),
    GetPage(
      name: AvailRoutes.notifications,
      page: () => Get.isRegistered<NavigationController>()
          ? const NotificationsScreen()
          : const NavigationMenu(initialIndex: 5),
    ),
    GetPage(
      name: AvailRoutes.settings,
      page: () => Get.isRegistered<NavigationController>()
          ? const SettingsScreen()
          : const NavigationMenu(initialIndex: 6),
    ),
    GetPage(name: AvailRoutes.jobDispatch, page: () => const JobDispatchScreen()),
    GetPage(name: AvailRoutes.userProfile, page: () => const ProfileScreen()),
    GetPage(name: AvailRoutes.signup, page: () => const SignupScreen()),
    GetPage(
      name: AvailRoutes.verifyEmail,
      page: () => VerifyEmailScreen(
        email: Get.arguments is String ? Get.arguments as String : null,
      ),
    ),
    GetPage(name: AvailRoutes.signIn, page: () => const LoginScreen()),
    GetPage(name: AvailRoutes.forgotPassword, page: () => const ForgotPasswordScreen()),
    GetPage(
      name: AvailRoutes.resetPassword,
      page: () => ResetPasswordScreen(
        email: Get.arguments is String ? Get.arguments as String : '',
      ),
    ),
    GetPage(name: AvailRoutes.onBoarding, page: () => const OnBoardingScreen()),
    GetPage(name: AvailRoutes.noNetwork, page: () => const NoNetworkScreen()),
    GetPage(name: AvailRoutes.driverDashboard, page: () => const DriverDashboardScreen()),
    GetPage(name: AvailRoutes.driverNavigationMenu, page: () => const DriverNavigationMenu()),
    GetPage(name: AvailRoutes.termsOfService, page: () => const TermsOfServiceScreen()),
    GetPage(name: AvailRoutes.privacyPolicy, page: () => const PrivacyPolicyScreen()),
    GetPage(name: AvailRoutes.aboutUs, page: () => const AboutUsScreen()),
    GetPage(name: AvailRoutes.helpSupport, page: () => const HelpSupportScreen()),
    GetPage(name: AvailRoutes.privacySettings, page: () => const PrivacySettingsScreen()),
    GetPage(name: AvailRoutes.addNewAddress, page: () => const AddNewAddressScreen()),
    GetPage(name: AvailRoutes.addNewPayment, page: () => const AddNewPaymentScreen()),
    GetPage(name: AvailRoutes.diditVerification, page: () => const DiditVerificationScreen()),
    GetPage(
      name: AvailRoutes.bookingDetails,
      page: () {
        final booking = Get.arguments as BookingModel?;
        if (booking != null) {
          return BookingDetailsScreen(booking: booking);
        }
        return const NavigationMenu(initialIndex: 1);
      },
    ),
    GetPage(name: AvailRoutes.changeName, page: () => const ChangeName()),
    GetPage(name: AvailRoutes.changeUsername, page: () => const ChangeUsername()),
    GetPage(name: AvailRoutes.changePhoneNumber, page: () => const ChangePhoneNumber()),
  ];
}
