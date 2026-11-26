import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../features/personalization/controllers/localization_controller.dart';
import '../../../../features/personalization/controllers/notification_controller.dart';
import '../../../../features/personalization/controllers/user_controller.dart';
import '../../../../features/personalization/screens/profile/profile.dart';
import '../../../../features/personalization/screens/verification/didit_verification_screen.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../sidebar/sidebar_controller.dart';

class ShipperHeader extends StatelessWidget {
  const ShipperHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBack,
  });

  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;

  void _showSearchableCurrencyPicker(BuildContext context, LocalizationController locController) {
    final searchController = TextEditingController();
    final RxList<Map<String, String>> filteredList =
        RxList<Map<String, String>>(locController.supportedCurrenciesList);
    final dark = AvailHelperFunctions.isDarkMode(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Select Display Currency',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 400,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: (query) {
                    final q = query.toLowerCase().trim();
                    if (q.isEmpty) {
                      filteredList.assignAll(locController.supportedCurrenciesList);
                    } else {
                      filteredList.assignAll(
                        locController.supportedCurrenciesList.where((c) {
                          final name = c['name']!.toLowerCase();
                          final label = c['label']!.toLowerCase();
                          return name.contains(q) || label.contains(q);
                        }).toList(),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search currency (e.g. GHS, USD, Naira, Euro)...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Iconsax.search_normal, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Obx(
                    () => filteredList.isEmpty
                        ? const Center(child: Text('No matching currencies found'))
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final currencyMap = filteredList[index];
                              final isSelected =
                                  locController.selectedCurrency.value == currencyMap['name'];

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AvailColors.primary
                                        : (dark ? Colors.white10 : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    currencyMap['symbol']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AvailColors.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  currencyMap['label']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? AvailColors.primary
                                        : (dark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: AvailColors.primary, size: 18)
                                    : null,
                                onTap: () {
                                  locController.updateCurrency(
                                    currencyMap['name']!,
                                    currencyMap['symbol']!,
                                  );
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final width = MediaQuery.of(context).size.width;
    final userController = Get.isRegistered<UserController>()
        ? UserController.instance
        : Get.put(UserController());
    final notifController = Get.isRegistered<NotificationController>()
        ? NotificationController.instance
        : Get.put(NotificationController());
    final locController = LocalizationController.instance;
    final navController = NavigationController.instance;
    final isGuest = FirebaseAuth.instance.currentUser == null;

    return Container(
      height: AvailSizes.webHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: AvailSizes.md),
      decoration: BoxDecoration(
        color: dark ? AvailColors.dark : AvailColors.white,
        border: Border(
          bottom: BorderSide(
            color: dark ? const Color(0xFF1E3A5F) : AvailColors.borderprimary,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          /// Drawer Toggle on Tablet / Sidebar Collapse on Desktop
          if (width < AvailSizes.desktopScreenBreakpoint)
            IconButton(
              icon: const Icon(Iconsax.menu_1),
              tooltip: 'Open Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            )
          else
            IconButton(
              icon: const Icon(Iconsax.menu_1, size: 20, color: Colors.grey),
              tooltip: 'Toggle Navigation Sidebar',
              onPressed: () => SidebarController.instance.toggleSidebar(),
            ),

          if (showBackButton) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Iconsax.arrow_left, size: 20),
              tooltip: 'Back',
              onPressed: onBack ??
                  () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Get.offAllNamed(AvailRoutes.navigationMenu);
                    }
                  },
            ),
          ],

          const SizedBox(width: 8),

          /// Active Section Title
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : AvailColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(width: 8),

          /// Currency Selector Pill
          Obx(() => InkWell(
                onTap: () => _showSearchableCurrencyPicker(context, locController),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF132238) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: dark ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        locController.selectedCurrencySymbol.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AvailColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        locController.selectedCurrency.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              )),

          const SizedBox(width: 6),

          /// Notification Bell with Unread Badge
          Obx(() {
            final unreadCount =
                notifController.allNotifications.where((n) => !n.isRead).length;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  icon: Icon(
                    Iconsax.notification,
                    size: 20,
                    color: dark ? Colors.white70 : AvailColors.darkgrey,
                  ),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                    navController.selectedIndex.value = 5;
                    if (Get.currentRoute != AvailRoutes.notifications &&
                        Get.currentRoute != AvailRoutes.navigationMenu &&
                        Get.currentRoute != '/') {
                      Get.offAllNamed(AvailRoutes.notifications);
                    }
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AvailColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),

          /// Theme Switcher
          IconButton(
            tooltip: dark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              dark ? Iconsax.sun_1 : Iconsax.moon,
              size: 20,
              color: dark ? Colors.amber : AvailColors.darkgrey,
            ),
            onPressed: () {
              Get.changeThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
            },
          ),

          const SizedBox(width: 8),

          /// User Profile Avatar & Menu
          Obx(() {
            final user = userController.user.value;
            return PopupMenuButton<String>(
              offset: const Offset(0, 50),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AvailColors.primary.withValues(alpha: 0.15),
                    backgroundImage: user.profilePicture.isNotEmpty
                        ? NetworkImage(user.profilePicture)
                        : const AssetImage(AvailImages.user) as ImageProvider,
                  ),
                  if (width >= AvailSizes.desktopScreenBreakpoint) ...[
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGuest
                              ? 'Guest Shipper'
                              : (user.fullName.trim().isNotEmpty ? user.fullName : 'Haujzo Shipper'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: dark ? Colors.white : AvailColors.textPrimary,
                          ),
                        ),
                        Text(
                          isGuest
                              ? 'Sign in to book'
                              : (user.email.isNotEmpty ? user.email : 'Shipper Account'),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                  ],
                ],
              ),
              itemBuilder: (context) => [
                if (!isGuest) ...[
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Iconsax.user, size: 18),
                        SizedBox(width: 8),
                        Text('My Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'verification',
                    child: Row(
                      children: [
                        Icon(Iconsax.verify, size: 18),
                        SizedBox(width: 8),
                        Text('KYC / KYB Verification'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Iconsax.setting_2, size: 18),
                        SizedBox(width: 8),
                        Text('Account Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Iconsax.logout, size: 18, color: AvailColors.error),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: AvailColors.error)),
                      ],
                    ),
                  ),
                ] else
                  const PopupMenuItem(
                    value: 'login',
                    child: Row(
                      children: [
                        Icon(Iconsax.login, size: 18, color: AvailColors.primary),
                        SizedBox(width: 8),
                        Text('Sign In', style: TextStyle(color: AvailColors.primary)),
                      ],
                    ),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    if (Get.isRegistered<NavigationController>()) {
                      NavigationController.instance.openSubScreen(
                        const ProfileScreen(),
                        title: 'My Profile',
                      );
                    } else {
                      Get.toNamed(AvailRoutes.userProfile);
                    }
                    break;
                  case 'verification':
                    if (Get.isRegistered<NavigationController>()) {
                      NavigationController.instance.openSubScreen(
                        const DiditVerificationScreen(),
                        title: 'Identity Verification',
                      );
                    } else {
                      Get.toNamed(AvailRoutes.diditVerification);
                    }
                    break;
                  case 'settings':
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                    navController.selectedIndex.value = 6;
                    if (Get.currentRoute != AvailRoutes.settings &&
                        Get.currentRoute != AvailRoutes.navigationMenu &&
                        Get.currentRoute != '/') {
                      Get.offAllNamed(AvailRoutes.settings);
                    }
                    break;
                  case 'logout':
                    userController.logOutAccountWarningPop();
                    break;
                  case 'login':
                    Get.toNamed(AvailRoutes.signIn);
                    break;
                }
              },
            );
          }),
        ],
      ),
    );
  }
}
