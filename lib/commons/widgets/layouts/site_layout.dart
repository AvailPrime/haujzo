import 'package:flutter/material.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/helpers/helper_functions.dart';

/// Core responsive layout switcher modeled after the Admin Portal & Avail Storefront.
/// Breakpoints:
/// - Mobile: < 768px
/// - Tablet: 768px .. 1099px
/// - Desktop: >= 1100px
class SiteLayout extends StatelessWidget {
  const SiteLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AvailSizes.tabletScreenBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AvailSizes.tabletScreenBreakpoint &&
        width < AvailSizes.desktopScreenBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AvailSizes.desktopScreenBreakpoint;

  static bool isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= AvailSizes.tabletScreenBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AvailSizes.desktopScreenBreakpoint) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= AvailSizes.tabletScreenBreakpoint) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

/// Centers content cleanly on tablet/desktop inside a max-width card or container,
/// while staying edge-to-edge on mobile devices.
class MaxWidthContainer extends StatelessWidget {
  const MaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = 520,
    this.useCardDecoration = true,
    this.alwaysDecorate = false,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius = 20,
  });

  final Widget child;
  final double maxWidth;
  final bool useCardDecoration;
  final bool alwaysDecorate;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final isWide = SiteLayout.isWideScreen(context);

    if (!isWide && !alwaysDecorate) {
      return child;
    }

    return Container(
      width: double.infinity,
      color: backgroundColor ?? (dark ? AvailColors.dark : const Color(0xFFF4F7FB)),
      alignment: Alignment.topCenter,
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: margin ??
              EdgeInsets.symmetric(
                horizontal: isWide ? 24 : 16,
                vertical: isWide ? 24 : 16,
              ),
          padding: padding,
          decoration: useCardDecoration
              ? BoxDecoration(
                  color: dark ? const Color(0xFF132238) : AvailColors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: dark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.35 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                )
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(useCardDecoration ? borderRadius : 0),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Lightweight centered max-width wrapper without outer card shadow,
/// ideal for scrollable pages, lists, forms, and settings screens on wide viewports.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 1040,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

/// Adaptive 2-column grid helper using LayoutBuilder, modeled after Admin Portal grids.
class ResponsiveTwoColumn extends StatelessWidget {
  const ResponsiveTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 860,
    this.spacing = 20,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget left;
  final Widget right;
  final double breakpoint;
  final double spacing;
  final int leftFlex;
  final int rightFlex;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Expanded(flex: leftFlex, child: left),
              SizedBox(width: spacing),
              Expanded(flex: rightFlex, child: right),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            left,
            SizedBox(height: spacing),
            right,
          ],
        );
      },
    );
  }
}

/// Inherited scope to detect if a widget is already inside a WebTemplate shell
class WebTemplateScope extends InheritedWidget {
  const WebTemplateScope({super.key, required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// Web / Desktop shell template combining collapsible Sidebar & Top Header Bar.
class WebTemplate extends StatelessWidget {
  const WebTemplate({
    super.key,
    required this.body,
    this.sidebar,
    this.header,
    this.drawer,
  });

  final Widget body;
  final Widget? sidebar;
  final Widget? header;
  final Widget? drawer;

  static bool isInsideWebTemplate(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WebTemplateScope>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);

    return WebTemplateScope(
      child: Scaffold(
        backgroundColor: dark ? AvailColors.dark : const Color(0xFFF4F7FB),
        drawer: drawer,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Row(
            children: [
              if (sidebar != null) sidebar!,
              Expanded(
                child: Column(
                  children: [
                    if (header != null) header!,
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
