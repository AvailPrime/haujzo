import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'commons/widgets/layouts/header/shipper_header.dart';
import 'commons/widgets/layouts/sidebar/shipper_sidebar.dart';
import 'commons/widgets/layouts/site_layout.dart';
import 'features/personalization/screens/address/address.dart';
import 'features/personalization/screens/notifications/notifications.dart';
import 'features/personalization/screens/payment_methods/payment_methods.dart';
import 'features/personalization/screens/settings/settings.dart';
import 'features/personalization/screens/truck_details/truck_details_screen.dart';
import 'features/shop/screens/bookings/my_bookings_screen.dart';
import 'features/shop/screens/customer_home/customer_home.dart';
import 'routes/routes.dart';
import 'utils/constants/colors.dart';
import 'utils/helpers/helper_functions.dart';

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationController(), permanent: true);
    if (controller.selectedIndex.value != initialIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.selectedIndex.value = initialIndex;
      });
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (controller.subScreen.value != null) {
          controller.closeSubScreen();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else if (controller.selectedIndex.value != 0) {
          if (controller.selectedIndex.value >= 2 &&
              controller.selectedIndex.value <= 5) {
            controller.selectedIndex.value = 6;
          } else {
            controller.selectedIndex.value = 0;
          }
        } else {
          SystemNavigator.pop();
        }
      },
      child: const SiteLayout(
        mobile: _NavigationMenuMobile(),
        tablet: _NavigationMenuWide(showPermanentSidebar: false),
        desktop: _NavigationMenuWide(showPermanentSidebar: true),
      ),
    );
  }
}

class _NavigationMenuMobile extends StatelessWidget {
  const _NavigationMenuMobile();

  @override
  Widget build(BuildContext context) {
    final controller = NavigationController.instance;
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return Obx(() {
      final isSubScreen = controller.subScreen.value != null;
      final defaultTitle = controller.titles[controller.selectedIndex.value.clamp(0, controller.titles.length - 1)];
      final title = controller.subScreenTitle.value ?? defaultTitle;

      return Scaffold(
        bottomNavigationBar: isSubScreen
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: darkMode ? const Color(0xFF0B1526) : AvailColors.white,
                  border: Border(
                    top: BorderSide(
                      color: darkMode
                          ? const Color(0xFF1E3A5F)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: darkMode ? 0.35 : 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      final isSelected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        color: isSelected
                            ? AvailColors.primary
                            : (darkMode ? Colors.grey.shade300 : const Color(0xFF64748B)),
                        size: 24,
                      );
                    }),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final isSelected = states.contains(WidgetState.selected);
                      return TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? AvailColors.primary
                            : (darkMode ? Colors.grey.shade400 : const Color(0xFF64748B)),
                        letterSpacing: 0.2,
                      );
                    }),
                  ),
                  child: NavigationBar(
                    height: 70,
                    elevation: 0,
                    selectedIndex: controller.mobileTabIndex,
                    onDestinationSelected: (index) => controller.selectMobileTab(index),
                    backgroundColor: Colors.transparent,
                    indicatorColor: AvailColors.primary.withValues(alpha: 0.14),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Iconsax.home_2),
                        selectedIcon: Icon(Iconsax.home_2, color: AvailColors.primary),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Iconsax.truck_fast),
                        selectedIcon: Icon(Iconsax.truck_fast, color: AvailColors.primary),
                        label: 'Manage Jobs',
                      ),
                      NavigationDestination(
                        icon: Icon(Iconsax.user_octagon),
                        selectedIcon: Icon(Iconsax.user_octagon, color: AvailColors.primary),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
        body: SafeArea(
          top: false,
          bottom: isSubScreen,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey<String>(isSubScreen ? 'mobile_sub_$title' : 'mobile_tab_${controller.selectedIndex.value}'),
              child: controller.activeScreen,
            ),
          ),
        ),
      );
    });
  }
}

class _NavigationMenuWide extends StatelessWidget {
  const _NavigationMenuWide({required this.showPermanentSidebar});

  final bool showPermanentSidebar;

  @override
  Widget build(BuildContext context) {
    final controller = NavigationController.instance;

    return Obx(() {
      final index = controller.selectedIndex.value;
      final defaultTitle = controller.titles[index.clamp(0, controller.titles.length - 1)];
      final title = controller.subScreenTitle.value ?? defaultTitle;
      final isSubScreen = controller.subScreen.value != null;

      return WebTemplate(
        drawer: showPermanentSidebar
            ? null
            : const Drawer(child: SafeArea(child: ShipperSidebar(inDrawer: true))),
        sidebar: showPermanentSidebar ? const ShipperSidebar() : null,
        header: ShipperHeader(
          title: title,
          showBackButton: isSubScreen,
          onBack: isSubScreen ? () => controller.closeSubScreen() : null,
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey<String>(isSubScreen ? 'sub_$title' : 'tab_$index'),
            child: controller.activeScreen,
          ),
        ),
      );
    });
  }
}

class NavigationController extends GetxController {
  static NavigationController get instance => Get.find();

  static const Map<int, String> tabRoutes = {
    0: AvailRoutes.navigationMenu,
    1: AvailRoutes.myBookings,
    2: AvailRoutes.truckDetails,
    3: AvailRoutes.userPaymentMethods,
    4: AvailRoutes.userAddress,
    5: AvailRoutes.notifications,
    6: AvailRoutes.settings,
  };

  /// Desktop indices:
  /// 0: Live Map & Track
  /// 1: Freight Manifests
  /// 2: Fleet Specifications
  /// 3: Payment & Wallets
  /// 4: Saved Addresses
  /// 5: Notifications
  /// 6: Account & Settings
  final RxInt selectedIndex = 0.obs;

  /// Detail sub-screen currently displayed in-place inside the content area
  final Rx<Widget?> subScreen = Rx<Widget?>(null);
  final Rx<String?> subScreenTitle = Rx<String?>(null);

  void openSubScreen(Widget screen, {String? title}) {
    subScreen.value = screen;
    subScreenTitle.value = title;
  }

  void closeSubScreen() {
    subScreen.value = null;
    subScreenTitle.value = null;
  }

  @override
  void onInit() {
    super.onInit();
    if (kIsWeb) {
      ever(selectedIndex, (int index) {
        final path = tabRoutes[index] ?? AvailRoutes.navigationMenu;
        SystemNavigator.routeInformationUpdated(uri: Uri.parse(path), replace: true);
      });
    }
    ever(selectedIndex, (_) => closeSubScreen());
  }

  final List<String> titles = const [
    'Live Map & Dispatch',
    'Freight Manifests',
    'Fleet Specifications',
    'Payment & Wallets',
    'Saved Addresses',
    'Notifications & Alerts',
    'Account & Settings',
  ];

  final List<Widget> screens = const [
    CustomerHomeScreen(),
    MyBookingsScreen(),
    TruckDetailsScreen(),
    UserPaymentMethodsScreen(),
    UserAddressScreen(),
    NotificationsScreen(),
    SettingsScreen(),
  ];

  Widget get activeScreen {
    if (subScreen.value != null) {
      return subScreen.value!;
    }
    final idx = selectedIndex.value;
    if (idx >= 0 && idx < screens.length) {
      return screens[idx];
    }
    return screens[0];
  }

  /// Map desktop index back to 3-tab mobile NavigationBar
  int get mobileTabIndex {
    final idx = selectedIndex.value;
    if (idx == 0) return 0;
    if (idx == 1) return 1;
    if (idx == 6) return 2;
    return 2; // Sub-account views map to Profile tab on mobile
  }

  void selectMobileTab(int mobileIndex) {
    closeSubScreen();
    switch (mobileIndex) {
      case 0:
        selectedIndex.value = 0;
        break;
      case 1:
        selectedIndex.value = 1;
        break;
      case 2:
        selectedIndex.value = 6;
        break;
      default:
        selectedIndex.value = 0;
    }
  }
}
