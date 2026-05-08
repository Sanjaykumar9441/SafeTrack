import 'package:flutter/material.dart';

/// App theme configuration with consistent colors and styles.
class AppTheme {
  // Primary colors
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF60A5FA);

  // Status colors
  static const Color safeColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color dangerColor = Color(0xFFEF4444);

  // Background colors
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;

  // Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  static ThemeData get lightTheme => ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: bgColor,
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: textLight,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      );
}
