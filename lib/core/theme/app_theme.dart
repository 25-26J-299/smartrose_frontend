import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Premium 2026 Agricultural Color Palette
  static const Color deepForestGreen = Color(0xFF1B5E20); // Deep forest
  static const Color freshMeadow = Color(0xFF4CAF50); // Fresh meadow green
  static const Color earthBrown = Color(0xFF5D4037); // Rich earth brown
  static const Color sunsetAmber = Color(0xFFFF6F00); // Warm sunset
  static const Color roseBloom = Color(0xFFE91E63); // Rose bloom
  static const Color soilBrown = Color(0xFF8D6E63); // Natural soil
  static const Color skyBlue = Color(0xFF42A5F5); // Clear sky
  static const Color leafGreen = Color(0xFF66BB6A); // Leaf green
  static const Color creamBackground = Color(0xFFFFFBF0); // Cream background
  static const Color naturalLight = Color(0xFFF5F5F0); // Natural light

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: deepForestGreen,
          onPrimary: Colors.white,
          secondary: freshMeadow,
          onSecondary: Colors.white,
          tertiary: roseBloom,
          onTertiary: Colors.white,
          error: const Color(0xFFC62828),
          onError: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF1A1A1A),
          surfaceContainerHighest: const Color(0xFFF5F5F5),
          onSurfaceVariant: const Color(0xFF616161),
          outline: const Color(0xFFE0E0E0),
          outlineVariant: const Color(0xFFF0F0F0),
          shadow: Colors.black26,
          scrim: Colors.black54,
          inverseSurface: const Color(0xFF1A1A1A),
          onInverseSurface: Colors.white,
          inversePrimary: freshMeadow,
          surfaceTint: deepForestGreen,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: creamBackground,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.8,
            color: Color(0xFF1A1A1A),
            height: 1.2,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.6,
            color: Color(0xFF1A1A1A),
            height: 1.2,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Color(0xFF1A1A1A),
            height: 1.3,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
            height: 1.3,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Color(0xFF424242),
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Color(0xFF616161),
            height: 1.5,
          ),
        ),
      );
}

