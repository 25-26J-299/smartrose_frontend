import 'package:flutter/material.dart';

import '../../screens/bottom_navigation_shell.dart';

/// Wrapper that ensures the bottom navigation bar is always visible
/// This widget wraps screens that need to be displayed with persistent bottom nav
class PersistentBottomNavWrapper extends StatelessWidget {
  const PersistentBottomNavWrapper({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Check if we're already inside a BottomNavigationShell
    final bool hasBottomNav = _hasBottomNav(context);
    
    if (hasBottomNav) {
      // Already inside shell, just return child
      return child;
    }
    
    // Wrap with bottom nav shell
    return BottomNavigationShell();
  }

  bool _hasBottomNav(BuildContext context) {
    // Check if we can find a NavigationBar in the widget tree
    return context.findAncestorWidgetOfExactType<BottomNavigationShell>() != null;
  }
}









