import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'menu_screen.dart';
import 'notification_screen.dart';

class BottomNavigationShell extends StatefulWidget {
  const BottomNavigationShell({super.key});

  @override
  State<BottomNavigationShell> createState() => _BottomNavigationShellState();
}

class _BottomNavigationShellState extends State<BottomNavigationShell> {
  int _currentIndex = 0;
  final List<Widget> _screens = const <Widget>[
    DashboardScreen(),
    InsightsScreen(),
    NotificationScreen(),
    MenuScreen(),
  ];

  final List<String> _titles = const <String>[
    'Dashboard',
    'Insights',
    'Notifications',
    'Menu',
  ];

  String _getAppBarTitle() {
    // Get the current route name from ModalRoute
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final String? routeName = route?.settings.name;

    if (routeName != null &&
        routeName != AppRoutes.home &&
        routeName != AppRoutes.root) {
      switch (routeName) {
        case AppRoutes.freshness:
          return 'Freshness Monitoring';
        case AppRoutes.nutrition:
          return 'Nutrition Monitoring';
        case AppRoutes.stress:
          return 'Stress Monitoring';
        case AppRoutes.disease:
          return 'Disease Detection';
        case AppRoutes.settings:
          return 'Settings';
        default:
          return _titles[_currentIndex];
      }
    }
    return _titles[_currentIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_getAppBarTitle())),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Insights',
          ),
          
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}
