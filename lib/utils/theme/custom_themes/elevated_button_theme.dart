import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class AvailElevatedButtonTheme {
  AvailElevatedButtonTheme._();

  static final lightelevatedbuttontheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: AvailColors.primary,
      disabledForegroundColor: Colors.grey,
      disabledBackgroundColor: AvailColors.primary.withValues(alpha: 0.5),
      side: const BorderSide(color: AvailColors.primary),
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static final darkelevatedbuttontheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: AvailColors.primary,
      disabledForegroundColor: Colors.grey,
      disabledBackgroundColor: AvailColors.primary.withValues(alpha: 0.5),
      side: const BorderSide(color: AvailColors.primary),
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
