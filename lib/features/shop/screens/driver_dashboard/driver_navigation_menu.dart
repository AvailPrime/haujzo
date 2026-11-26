import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../commons/widgets/images/app_logo.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../../personalization/screens/settings/settings.dart';
import '../driver_dashboard/driver_dashboard.dart';

class DriverNavigationMenu extends StatelessWidget {
  const DriverNavigationMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DriverNavigationController());
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return SiteLayout(
      mobile: Scaffold(
        bottomNavigationBar: Obx(
          () => NavigationBar(
            height: 64,
            elevation: 0,
            selectedIndex: controller.selectedIndex.value,
            onDestinationSelected: (index) => controller.selectedIndex.value = index,
            backgroundColor: darkMode ? AvailColors.black : AvailColors.white,
            indicatorColor: AvailColors.primary.withValues(alpha: 0.15),
            destinations: const [
              NavigationDestination(
                icon: Icon(Iconsax.radar),
                label: 'Dashboard',
                selectedIcon: Icon(Iconsax.radar, color: AvailColors.primary),
              ),
              NavigationDestination(
                icon: Icon(Iconsax.task),
                label: 'Tasks',
                selectedIcon: Icon(Iconsax.task, color: AvailColors.primary),
              ),
              NavigationDestination(
                icon: Icon(Iconsax.wallet),
                label: 'Earnings',
                selectedIcon: Icon(Iconsax.wallet, color: AvailColors.primary),
              ),
              NavigationDestination(
                icon: Icon(Iconsax.user),
                label: 'Account',
                selectedIcon: Icon(Iconsax.user, color: AvailColors.primary),
              ),
            ],
          ),
        ),
        body: Obx(() => controller.screens[controller.selectedIndex.value]),
      ),
      tablet: _DriverWideShell(controller: controller, extended: false),
      desktop: _DriverWideShell(controller: controller, extended: true),
    );
  }
}

class _DriverWideShell extends StatelessWidget {
  const _DriverWideShell({required this.controller, required this.extended});

  final DriverNavigationController controller;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Obx(
              () => NavigationRail(
                extended: extended,
                selectedIndex: controller.selectedIndex.value,
                onDestinationSelected: (index) => controller.selectedIndex.value = index,
                backgroundColor: darkMode ? AvailColors.dark : AvailColors.white,
                indicatorColor: AvailColors.primary.withValues(alpha: 0.14),
                selectedIconTheme: const IconThemeData(color: AvailColors.primary),
                selectedLabelTextStyle: const TextStyle(
                  color: AvailColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: extended
                      ? AvailAppLogo.appBar(width: 130, height: 34)
                      : const Icon(Iconsax.truck_fast, color: AvailColors.primary, size: 28),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Iconsax.radar),
                    label: Text('Dashboard'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Iconsax.task),
                    label: Text('Tasks'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Iconsax.wallet),
                    label: Text('Earnings'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Iconsax.user),
                    label: Text('Account'),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Obx(() => controller.screens[controller.selectedIndex.value]),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverNavigationController extends GetxController {
  static DriverNavigationController get instance => Get.find();
  final RxInt selectedIndex = 0.obs;

  final screens = const [
    DriverDashboardScreen(),
    Scaffold(body: Center(child: Text('Active Tasks Screen (Coming Soon)'))),
    Scaffold(body: Center(child: Text('Earnings Screen (Coming Soon)'))),
    SettingsScreen(),
  ];
}
