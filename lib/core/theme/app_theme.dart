import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF81C784), // Light green color
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );
}

