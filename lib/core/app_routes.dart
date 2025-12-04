import 'package:flutter/material.dart';

import '../features/disease/screens/disease_home_screen.dart';
import '../features/freshness/screens/freshness_home_screen.dart';
import '../features/nutrition/screens/nutrition_home_screen.dart';
import '../features/stress/screens/stress_home_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String settings = '/settings';
  static const String freshness = '/freshness';
  static const String nutrition = '/nutrition';
  static const String stress = '/stress';
  static const String disease = '/disease';

  static final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
    home: (BuildContext context) => const HomeScreen(),
    settings: (BuildContext context) => const SettingsScreen(),
    freshness: (BuildContext context) => const FreshnessHomeScreen(),
    nutrition: (BuildContext context) => const NutritionHomeScreen(),
    stress: (BuildContext context) => const StressHomeScreen(),
    disease: (BuildContext context) => const DiseaseHomeScreen(),
  };
}

