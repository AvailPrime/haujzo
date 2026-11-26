import 'package:flutter/material.dart';

class AvailColors {
  AvailColors._();

  // ==========================================
  // HAUJZO BRAND PALETTE (Extracted from haujzo.png)
  // ==========================================

  /// Primary Brand Accent: Freight Orange (HEX: #FF6200, RGB: 255, 98, 0)
  /// Used for CTAs, active highlights, action buttons, live dispatch indicators
  static const Color primary = Color(0xFFFF6200);

  /// Secondary Brand Core: Logistics Navy Blue (HEX: #122F51, RGB: 18, 47, 81)
  /// Used for corporate headers, primary cards, navigation backgrounds, authority
  static const Color secondary = Color(0xFF122F51);

  /// High-visibility Accent Orange (HEX: #FF7A1A)
  static const Color accent = Color(0xFFFF7A1A);

  /// Direct references
  static const Color brandOrange = Color(0xFFFF6200);
  static const Color brandNavy = Color(0xFF122F51);
  static const Color brandNavyDark = Color(0xFF0C2037);
  static const Color brandNavyLight = Color(0xFF1E436E);

  /// Dynamic Gradients
  static const Gradient lineargradient = LinearGradient(
    begin: Alignment(0.0, 0.0),
    end: Alignment(0.707, -0.707),
    colors: [
      Color(0xFFFF6200),
      Color(0xFFFF7A1A),
      Color(0xFFFFA04D),
    ],
  );

  static const Gradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF122F51),
      Color(0xFF1A3E6B),
      Color(0xFF234F85),
    ],
  );

  static const Gradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF122F51),
      Color(0xFF0C2037),
    ],
  );

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textsecondary = Color(0xFF64748B);
  static const Color textAccent = Colors.white;

  // Background Colors
  static const Color light = Color(0xFFF8FAFC);
  static const Color dark = Color(0xFF0A192F);
  static const Color primarybackground = Color(0xFFF4F7FB);

  // Background Container Colors
  static const Color lightcontainer = Color(0xFFF1F5F9);
  static const Color darkcontainer = Color(0xFF132238);
  static Color textWhite = Colors.white.withValues(alpha: 0.1);

  // Soft Tint Surfaces for Cards & Badges
  static const Color orangeSurface = Color(0xFFFFF3EB);
  static const Color navySurface = Color(0xFFEDF3F9);

  // Button Colors
  static const Color buttonprimary = Color(0xFFFF6200);
  static const Color buttonsecondary = Color(0xFF122F51);
  static const Color buttondisabled = Color(0xFFCBD5E1);

  // Border Colors
  static const Color borderprimary = Color(0xFFE2E8F0);
  static const Color bordersecondary = Color(0xFFF1F5F9);

  // Errors and Validation Colors
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0284C7);

  // Neutral Shades
  static const Color black = Color(0xFF0F172A);
  static const Color darkergrey = Color(0xFF334155);
  static const Color darkgrey = Color(0xFF64748B);
  static const Color grey = Color(0xFFE2E8F0);
  static const Color softgrey = Color(0xFFF1F5F9);
  static const Color lightgrey = Color(0xFFF8FAFC);
  static const Color white = Color(0xFFFFFFFF);

  // Rating Colors
  static const Color ratingStar = Color(0xFFFFB800);
}
