import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../features/personalization/controllers/notification_controller.dart';
import '../../../../features/personalization/controllers/user_controller.dart';
import '../../../../features/shop/controllers/customer/customer_home_controller.dart';
import '../../../../features/shop/screens/customer_home/job_dispatch_screen.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../images/app_logo.dart';
import 'sidebar_controller.dart';

class ShipperSidebar extends StatelessWidget {
  const ShipperSidebar({super.key, this.inDrawer = false});

  final bool inDrawer;

  bool _isTabActive(int idx, int selectedIndex) {
    final current = Get.currentRoute;
    if (current == AvailRoutes.jobDispatch ||
        current == AvailRoutes.userProfile ||
        current == AvailRoutes.diditVerification ||
        current == AvailRoutes.bookingDetails ||
        current == AvailRoutes.addNewAddress ||
        current == AvailRoutes.addNewPayment ||
        current == AvailRoutes.privacySettings ||
        current == AvailRoutes.termsOfService ||
        current == AvailRoutes.privacyPolicy ||
        current == AvailRoutes.aboutUs ||
        current == AvailRoutes.helpSupport) {
      return false;
    }
    final targetRoute = NavigationController.tabRoutes[idx];
    if (current == targetRoute) return true;
    if (current == AvailRoutes.navigationMenu || current == '/') {
      return selectedIndex == idx;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final sidebarController = SidebarController.instance;
    final navController = NavigationController.instance;
    final notifController = Get.isRegistered<NotificationController>()
        ? NotificationController.instance
        : Get.put(NotificationController());
    final userController = Get.isRegistered<UserController>()
        ? UserController.instance
        : Get.put(UserController());

    return Obx(() {
      final isCollapsed = inDrawer ? false : sidebarController.isCollapsed.value;
      final sidebarWidth = isCollapsed ? 74.0 : 252.0;
      final selectedIndex = navController.selectedIndex.value;
      final unreadCount = notifController.allNotifications.where((n) => !n.isRead).length;
      final isGuest = FirebaseAuth.instance.currentUser == null;
      final user = userController.user.value;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        width: sidebarWidth,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: dark ? AvailColors.dark : AvailColors.white,
          border: Border(
            right: BorderSide(
              color: dark ? const Color(0xFF1E3A5F) : AvailColors.borderprimary,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            /// Brand Logo & Collapse Toggle
            Container(
              height: AvailSizes.webHeaderHeight,
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 10 : AvailSizes.md),
              alignment: Alignment.center,
              child: isCollapsed
                  ? Tooltip(
                      message: 'Expand Sidebar',
                      child: InkWell(
                        onTap: () => sidebarController.toggleSidebar(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AvailColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Iconsax.sidebar_right, color: AvailColors.primary, size: 20),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (inDrawer && (Scaffold.maybeOf(context)?.isDrawerOpen ?? false)) {
                                Navigator.of(context).pop();
                              }
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                              navController.selectedIndex.value = 0;
                              if (Get.currentRoute != AvailRoutes.navigationMenu && Get.currentRoute != '/') {
                                Get.offAllNamed(AvailRoutes.navigationMenu);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: dark
                                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                                  : EdgeInsets.zero,
                              decoration: dark
                                  ? BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: AvailAppLogo.appBar(width: 145, height: 36),
                            ),
                          ),
                        ),
                        if (!inDrawer)
                          Tooltip(
                            message: 'Collapse Sidebar',
                            child: IconButton(
                              icon: const Icon(Iconsax.sidebar_left, size: 18, color: Colors.grey),
                              onPressed: () => sidebarController.toggleSidebar(),
                            ),
                          ),
                      ],
                    ),
            ),

            const Divider(height: 1),

            /// Quick Primary Action: New Dispatch
            Padding(
              padding: EdgeInsets.fromLTRB(isCollapsed ? 10 : 12, 12, isCollapsed ? 10 : 12, 8),
              child: Tooltip(
                message: isCollapsed ? 'Dispatch Cargo Job' : '',
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      if (inDrawer && (Scaffold.maybeOf(context)?.isDrawerOpen ?? false)) {
                        Navigator.of(context).pop();
                      }
                      if (Get.currentRoute == AvailRoutes.jobDispatch) return;
                      if (Get.isRegistered<CustomerHomeController>()) {
                        final homeCtrl = CustomerHomeController.instance;
                        if (!homeCtrl.checkShipperVerificationAndApproval()) return;
                        homeCtrl.resetForm();
                      }
                      if (Get.isRegistered<NavigationController>()) {
                        NavigationController.instance.openSubScreen(
                          const JobDispatchScreen(),
                          title: 'Cargo Job Dispatch',
                        );
                      } else {
                        Get.toNamed(AvailRoutes.jobDispatch);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AvailColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isCollapsed
                        ? const Icon(Iconsax.add, size: 22, color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.add_circle, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Dispatch Cargo',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            /// Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AvailSizes.xs, horizontal: 8),
                children: [
                  _SidebarMenuItem(
                    title: 'Live Map & Track',
                    icon: Iconsax.map_1,
                    index: 0,
                    isActive: _isTabActive(0, selectedIndex),
                    isCollapsed: isCollapsed,
                    inDrawer: inDrawer,
                  ),
                  _SidebarMenuItem(
                    title: 'Freight Manifests',
                    icon: Iconsax.truck_fast,
                    index: 1,
                    isActive: _isTabActive(1, selectedIndex),
                    isCollapsed: isCollapsed,
                    inDrawer: inDrawer,
                  ),
                  _SidebarMenuItem(
                    title: 'Fleet Specifications',
                    icon: Iconsax.truck,
                    index: 2,
                    isActive: _isTabActive(2, selectedIndex),
                    isCollapsed: isCollapsed,
                    inDrawer: inDrawer,
                  ),
                  _SidebarMenuItem(
                    title: 'Payment & Wallets',
                    icon: Iconsax.wallet_3,
                    index: 3,
                    isActive: _isTabActive(3, selectedIndex),
                    isCollapsed: isCollapsed,
                    inDrawer: inDrawer,
                  ),
                  _SidebarMenuItem(
                    title: 'Saved Addresses',
                    icon: Iconsax.location,
                    index: 4,
                    isActive: _isTabActive(4, selectedIndex),
                    isCollapsed: isCollapsed,
                    inDrawer: inDrawer,
                  ),
                  _SidebarMenuItem(
                    title: 'Notifications',
                    icon: Iconsax.notification,
                    index: 5,
                    isActive: _isTabActive(5, selectedIndex),
                    isCollapsed: isCollapsed,
                    inDrawer: inDrawer,
                    badgeCount: unreadCount,
                  ),
                  _SidebarMenuItem(
                    title: 'Account & Settings',
                    icon: Iconsax.setting_2,
                    index: 6,
                    isActive: _isTabActive(6, selectedIndex),
                    isCollapsed: isCollapsed,
                    inDrawer: inDrawer,
                  ),
                ],
              ),
            ),

            /// Verification Status Pill (Expanded Only)
            if (!isCollapsed && !isGuest && user.id.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: user.canWork
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: user.canWork
                          ? Colors.green.withValues(alpha: 0.25)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        user.canWork ? Iconsax.verify : Iconsax.shield_security,
                        size: 16,
                        color: user.canWork ? Colors.green : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          user.canWork ? 'Verified Shipper' : 'Verification Pending',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: user.canWork ? Colors.green.shade700 : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Divider(height: 1),

            /// Login / Logout Footer
            Padding(
              padding: const EdgeInsets.all(8),
              child: _buildAuthFooterButton(context, isCollapsed, isGuest, userController),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAuthFooterButton(
    BuildContext context,
    bool isCollapsed,
    bool isGuest,
    UserController userController,
  ) {
    final color = isGuest ? AvailColors.primary : AvailColors.error;
    final label = isGuest ? 'Sign In' : 'Logout';
    final icon = isGuest ? Iconsax.login : Iconsax.logout;

    Widget content = Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: isCollapsed ? 0 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: isCollapsed
          ? Center(child: Icon(icon, color: color, size: 20))
          : Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
    );

    if (isCollapsed) {
      content = Tooltip(message: label, child: content);
    }

    return InkWell(
      onTap: () {
        if (inDrawer && (Scaffold.maybeOf(context)?.isDrawerOpen ?? false)) {
          Navigator.of(context).pop();
        }
        if (isGuest) {
          Get.toNamed(AvailRoutes.signIn);
        } else {
          userController.logOutAccountWarningPop();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: content,
    );
  }
}

class _SidebarMenuItem extends StatelessWidget {
  const _SidebarMenuItem({
    required this.title,
    required this.icon,
    required this.index,
    required this.isActive,
    required this.isCollapsed,
    required this.inDrawer,
    this.badgeCount = 0,
  });

  final String title;
  final IconData icon;
  final int index;
  final bool isActive;
  final bool isCollapsed;
  final bool inDrawer;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final navController = NavigationController.instance;

    Widget iconWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: isCollapsed ? 22 : 20,
          color: isActive
              ? AvailColors.primary
              : (dark ? Colors.grey[400] : Colors.grey[700]),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -6,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: const BoxDecoration(
                color: AvailColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );

    Widget itemContent = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: EdgeInsets.symmetric(
        vertical: 11,
        horizontal: isCollapsed ? 0 : 12,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AvailColors.primary.withValues(alpha: dark ? 0.25 : 0.11)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: AvailColors.primary.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: isCollapsed
          ? Center(child: iconWidget)
          : Row(
              children: [
                iconWidget,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive
                          ? AvailColors.primary
                          : (dark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AvailColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
    );

    if (isCollapsed) {
      itemContent = Tooltip(
        message: title,
        preferBelow: false,
        child: itemContent,
      );
    }

    return InkWell(
      onTap: () {
        if (inDrawer && (Scaffold.maybeOf(context)?.isDrawerOpen ?? false)) {
          Navigator.of(context).pop();
        }
        navController.closeSubScreen();
        navController.selectedIndex.value = index;
        final targetRoute = NavigationController.tabRoutes[index] ?? AvailRoutes.navigationMenu;
        if (Get.currentRoute != targetRoute &&
            Get.currentRoute != AvailRoutes.navigationMenu &&
            Get.currentRoute != '/') {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else {
            Get.offAllNamed(targetRoute);
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: itemContent,
    );
  }
}
