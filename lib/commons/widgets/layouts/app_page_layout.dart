import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../routes/routes.dart';
import 'header/shipper_header.dart';
import 'sidebar/shipper_sidebar.dart';
import 'site_layout.dart';

/// Professional layout wrapper that ensures the sidebar and top header
/// are ALWAYS permanently available across all pages on web/tablet/desktop,
/// while providing an optimal native experience on mobile devices.
class AppPageLayout extends StatelessWidget {
  const AppPageLayout({
    super.key,
    required this.title,
    required this.child,
    this.showBackButton,
    this.onBack,
    this.desktopBody,
  });

  final String title;
  final Widget child;
  final bool? showBackButton;
  final VoidCallback? onBack;
  final Widget? desktopBody;

  @override
  Widget build(BuildContext context) {
    final isWide = SiteLayout.isWideScreen(context);
    final insideShell = WebTemplate.isInsideWebTemplate(context);

    // If on mobile OR already inside the master WebTemplate shell:
    // DO NOT create another WebTemplate, another sidebar, or another header!
    // Apply bottom SafeArea on mobile when rendered as a standalone route (outside NavigationMenu's bottom nav bar).
    if (!isWide || insideShell) {
      final hasNavController = Get.isRegistered<NavigationController>();
      final hasBottomNavVisible = !isWide &&
          !insideShell &&
          hasNavController &&
          NavigationController.instance.subScreen.value == null &&
          !Navigator.of(context).canPop();
      final content = desktopBody ?? child;
      if (!isWide && !hasBottomNavVisible) {
        return SafeArea(
          top: false,
          child: content,
        );
      }
      return content;
    }

    final isDesktop = SiteLayout.isDesktop(context);
    final canPop = Navigator.of(context).canPop();

    return WebTemplate(
      sidebar: isDesktop ? const ShipperSidebar() : null,
      drawer: isDesktop
          ? null
          : const Drawer(child: SafeArea(child: ShipperSidebar(inDrawer: true))),
      header: ShipperHeader(
        title: title,
        showBackButton: showBackButton ?? canPop,
        onBack: onBack ??
            () {
              if (Get.isRegistered<NavigationController>() &&
                  NavigationController.instance.subScreen.value != null) {
                NavigationController.instance.closeSubScreen();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Get.offAllNamed(AvailRoutes.navigationMenu);
              }
            },
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, animChild) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 10),
              child: animChild,
            ),
          );
        },
        child: desktopBody ?? child,
      ),
    );
  }
}
