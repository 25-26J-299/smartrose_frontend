import 'package:flutter/material.dart';

import '../features/disease/screens/disease_home_screen.dart';
import '../features/freshness/screens/freshness_home_screen.dart';
import '../features/inm/screens/inm_dashboard_screen.dart';
import '../features/nutrition/screens/nutrition_home_screen.dart';
import '../features/stress/screens/eosm_home_screen.dart';
import '../screens/bottom_navigation_shell.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/auth/role_selection_page.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/registration_screen.dart';
import '../screens/settings_screen.dart';

class AppRoutes {
  static const String root = '/';
  // Authentication routes
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role-selection';
  static const String profileEdit = '/profile-edit';

  // Main routes
  static const String home = '/home';
  static const String inmSensors = '/inm-sensors';

  // Legacy/other routes
  static const String registration = '/registration';
  static const String settings = '/settings';
  static const String freshness = '/freshness';
  static const String nutrition = '/nutrition';
  static const String stress = '/stress';
  static const String disease = '/disease';

  static final Set<String> _protectedRoutes = <String>{
    root,
    home,
    inmSensors,
    registration,
    settings,
    freshness,
    nutrition,
    stress,
    disease,
    roleSelection,
    profileEdit,
  };

  static final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
    // Authentication routes
    login: (BuildContext context) => const LoginScreen(),
    register: (BuildContext context) => const RegisterScreen(),
    roleSelection: (BuildContext context) => const RoleSelectionPage(),
    profileEdit: (BuildContext context) => const EditProfileScreen(),

    // Main routes (both / and /home point to home)
    root: (BuildContext context) => const BottomNavigationShell(),
    home: (BuildContext context) => const BottomNavigationShell(),
    inmSensors: (BuildContext context) => const InmDashboardScreen(),

    // Legacy/other routes
    registration: (BuildContext context) => const RegistrationScreen(),
    settings: (BuildContext context) => const SettingsScreen(),
    freshness: (BuildContext context) => const FreshnessHomeScreen(),
    nutrition: (BuildContext context) => const NutritionHomeScreen(),
    stress: (BuildContext context) => const EosmHomeScreen(),
    disease: (BuildContext context) => const DiseaseHomeScreen(),
  };

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
    bool isAuthenticated,
  ) {
    final String requestedRoute = settings.name ?? login;
    final bool requiresAuth = _protectedRoutes.contains(requestedRoute);

    String resolvedRoute = requestedRoute;
    if (!isAuthenticated && requiresAuth) {
      resolvedRoute = login;
    } else if (isAuthenticated && requestedRoute == login) {
      resolvedRoute = home;
    }

    final WidgetBuilder? builder = routes[resolvedRoute];
    final WidgetBuilder loginBuilder = routes[login]!;

    return MaterialPageRoute<dynamic>(
      settings: RouteSettings(
        name: resolvedRoute,
        arguments: settings.arguments,
      ),
      builder: builder ?? loginBuilder,
    );
  }
}
