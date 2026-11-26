
import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class AvailOutlinedButtonTheme{
  AvailOutlinedButtonTheme._();

  static final lightoutlinedbuttontheme = OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        disabledForegroundColor: Colors.grey,
        disabledBackgroundColor: AvailColors.primary,
        side: const BorderSide(color: AvailColors.primary),
        padding: const EdgeInsets.symmetric(vertical: 18),
        textStyle: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )
  );

  static final darkoutlinedbuttontheme = OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        disabledForegroundColor: Colors.grey,
        disabledBackgroundColor: Colors.white,
        side: const BorderSide(color: Colors.white),
        padding: const EdgeInsets.symmetric(vertical: 18),
        textStyle: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )
  );
}
