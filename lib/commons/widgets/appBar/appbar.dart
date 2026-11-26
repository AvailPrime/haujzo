import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../utils/device/device_utility.dart';
import '../layouts/site_layout.dart';

class AvailAppbar extends StatelessWidget implements PreferredSizeWidget {
  const AvailAppbar({
    super.key,
    this.title,
    this.actions,
    this.leadingIcon,
    this.leadingOnPressed,
    this.showBackArrow = false,
    this.showBackgroundColor = false,
    this.backgroundColor,
    this.backArrowColor,
    this.centerTitle = false,
    this.bottom,
    this.elevation = 0,
  });

  final Widget? title;
  final bool showBackArrow;
  final bool showBackgroundColor;
  final Color? backgroundColor;
  final IconData? leadingIcon;
  final List<Widget>? actions;
  final VoidCallback? leadingOnPressed;
  final Color? backArrowColor;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSolidDarkBg = showBackgroundColor || backgroundColor != null;
    final bg = backgroundColor ??
        (showBackgroundColor ? const Color(0xFF0B1D35) : Colors.transparent);

    final useLightForeground = hasSolidDarkBg || isDark;
    final iconColor = backArrowColor ??
        (useLightForeground ? Colors.white : const Color(0xFF0F172A));
    final canPop = Navigator.of(context).canPop();
    final hasNavController = Get.isRegistered<NavigationController>();
    final hasSubScreen = hasNavController &&
        NavigationController.instance.subScreen.value != null;
    final isSubTab = hasNavController &&
        !SiteLayout.isWideScreen(context) &&
        NavigationController.instance.selectedIndex.value >= 2 &&
        NavigationController.instance.selectedIndex.value <= 5;
    final shouldShowBack = showBackArrow &&
        (leadingOnPressed != null || canPop || hasSubScreen || isSubTab);

    void handleBack() {
      if (leadingOnPressed != null) {
        leadingOnPressed!();
      } else if (hasSubScreen) {
        NavigationController.instance.closeSubScreen();
      } else if (canPop) {
        Navigator.of(context).pop();
      } else if (isSubTab) {
        NavigationController.instance.selectedIndex.value = 6;
      }
    }

    return AppBar(
      backgroundColor: bg,
      elevation: elevation,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: false,
      bottom: bottom,
      leadingWidth: shouldShowBack || leadingIcon != null ? 64 : 0,
      leading: shouldShowBack
          ? Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: handleBack,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: useLightForeground
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFF0F172A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: useLightForeground
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFF0F172A).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        Iconsax.arrow_left_2,
                        color: iconColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : leadingIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Center(
                    child: IconButton(
                      onPressed: leadingOnPressed,
                      icon: Icon(leadingIcon, color: iconColor, size: 22),
                    ),
                  ),
                )
              : null,
      title: title != null
          ? DefaultTextStyle(
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: iconColor,
                letterSpacing: 0.3,
              ),
              child: title!,
            )
          : null,
      actions: actions
          ?.map(
            (action) => Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: action,
            ),
          )
          .toList(),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        AvailDeviceUtils.getAppBarHeight() + (bottom?.preferredSize.height ?? 0.0),
      );
}
