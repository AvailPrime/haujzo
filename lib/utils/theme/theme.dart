import '../constants/colors.dart';
import 'package:flutter/material.dart';

import 'custom_themes/appbar_theme.dart';
import 'custom_themes/bottom_sheet_theme.dart';
import 'custom_themes/checkbox_theme.dart';
import 'custom_themes/chip_theme.dart';
import 'custom_themes/elevated_button_theme.dart';
import 'custom_themes/outline_button_theme.dart';
import 'custom_themes/text_field_theme.dart';
import 'custom_themes/text_theme.dart';

class AvailPageTransitionsBuilder extends PageTransitionsBuilder {
  const AvailPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).size.width >= 768) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: child,
      );
    }
    return const FadeUpwardsPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

class AvailAppTheme {
  AvailAppTheme._();

  //Light Mode
  static ThemeData lighttheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: Brightness.light,
    primaryColor: AvailColors.primary,
    scaffoldBackgroundColor: Colors.white,
    textTheme: AvailTextTheme.lighttexttheme,
    elevatedButtonTheme: AvailElevatedButtonTheme.lightelevatedbuttontheme,
    appBarTheme: AvailAppBarTheme.lightappbartheme,
    bottomSheetTheme: AvailBottomSheetTheme.lightbottomsheettheme,
    checkboxTheme: AvailCheckboxTheme.lightcheckboxtheme,
    chipTheme: AvailChipTheme.lightchiptheme,
    inputDecorationTheme: AvailTextFormFieldTheme.lightinputdecorationtheme,
    outlinedButtonTheme: AvailOutlinedButtonTheme.lightoutlinedbuttontheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: AvailPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: AvailPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: AvailPageTransitionsBuilder(),
      },
    ),
  );

  // Dark mode App Theme
  static ThemeData darktheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: Brightness.dark,
    primaryColor: AvailColors.primary,
    scaffoldBackgroundColor: Colors.black,
    textTheme: AvailTextTheme.darktexttheme,
    elevatedButtonTheme: AvailElevatedButtonTheme.darkelevatedbuttontheme,
    appBarTheme: AvailAppBarTheme.darkappbartheme,
    bottomSheetTheme: AvailBottomSheetTheme.darkbottomsheettheme,
    checkboxTheme: AvailCheckboxTheme.darkcheckboxtheme,
    chipTheme: AvailChipTheme.darkchiptheme,
    inputDecorationTheme: AvailTextFormFieldTheme.darkinputdecorationtheme,
    outlinedButtonTheme: AvailOutlinedButtonTheme.darkoutlinedbuttontheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: AvailPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: AvailPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: AvailPageTransitionsBuilder(),
      },
    ),
  );
}
