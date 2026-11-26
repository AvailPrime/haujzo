import 'package:flutter/material.dart';

class AvailAppBarTheme {
  AvailAppBarTheme._();

  static const lightappbartheme = AppBarTheme(
    elevation: 0,
    centerTitle: true,
    scrolledUnderElevation: 0,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    iconTheme: IconThemeData(color: Color(0xFF0F172A), size: 22),
    actionsIconTheme: IconThemeData(color: Color(0xFF0F172A), size: 22),
    titleTextStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
  );

  static const darkappbartheme = AppBarTheme(
    elevation: 0,
    centerTitle: true,
    scrolledUnderElevation: 0,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    iconTheme: IconThemeData(color: Colors.white, size: 22),
    actionsIconTheme: IconThemeData(color: Colors.white, size: 22),
    titleTextStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
  );
}
