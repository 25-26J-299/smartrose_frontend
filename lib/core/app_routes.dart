import 'package:flutter/material.dart';

import '../features/disease/screens/disease_home_screen.dart';
import '../features/freshness/screens/freshness_home_screen.dart';
import '../features/nutrition/screens/nutrition_home_screen.dart';
import '../features/stress/screens/stress_home_screen.dart';
import '../screens/bottom_navigation_shell.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/registration_screen.dart';
import '../screens/settings_screen.dart';

class AppRoutes {
  // Authentication routes
  static const String login = '/login';
  static const String register = '/register';

  // Main routes
  static const String home = '/home';

  // Legacy/other routes
  static const String registration = '/registration';
  static const String settings = '/settings';
  static const String freshness = '/freshness';
  static const String nutrition = '/nutrition';
  static const String stress = '/stress';
  static const String disease = '/disease';

  static final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
    // Authentication routes
    login: (BuildContext context) => const LoginScreen(),
    register: (BuildContext context) => const RegisterScreen(),

    // Main routes (both / and /home point to home)
    '/': (BuildContext context) => const BottomNavigationShell(),
    home: (BuildContext context) => const BottomNavigationShell(),

    // Legacy/other routes
    registration: (BuildContext context) => const RegistrationScreen(),
    settings: (BuildContext context) => const SettingsScreen(),
    freshness: (BuildContext context) => const FreshnessHomeScreen(),
    nutrition: (BuildContext context) => const NutritionHomeScreen(),
    stress: (BuildContext context) => const StressHomeScreen(),
    disease: (BuildContext context) => const DiseaseHomeScreen(),
  };
}
