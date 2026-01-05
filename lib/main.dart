import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/app_routes.dart';
import 'core/auth/auth_state.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      // In production, you might want to log to a crash reporting service
      debugPrint('Flutter Error: ${details.exception}');
    }
  };

  // Handle errors from async operations
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Platform Error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

  try {
    final AppConfigState appConfigState = AppConfigState();
    await AppConfig.init(appConfigState: appConfigState);
    final AuthState authState = AuthState();

    // Wrap restoreSession in try-catch to prevent crashes
    try {
      await authState.restoreSession();
    } catch (e, stackTrace) {
      debugPrint('Error restoring session: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continue anyway - user can still log in
    }

    runApp(SmartRoseApp(appConfigState: appConfigState, authState: authState));
  } catch (e, stackTrace) {
    debugPrint('Fatal error during initialization: $e');
    debugPrint('Stack trace: $stackTrace');

    // Show a basic error screen if initialization fails
    runApp(
      MaterialApp(
        title: 'SmartRose',
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  kDebugMode ? e.toString() : 'Please restart the app',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SmartRoseApp extends StatelessWidget {
  const SmartRoseApp({
    required this.appConfigState,
    required this.authState,
    super.key,
  });

  final AppConfigState appConfigState;
  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppConfigState>.value(value: appConfigState),
        ChangeNotifierProvider<AuthState>.value(value: authState),
      ],
      child: Consumer<AuthState>(
        builder: (BuildContext context, AuthState authState, Widget? _) {
          // Show loading screen while initializing
          if (authState.isInitializing) {
            return MaterialApp(
              title: 'SmartRose',
              theme: AppTheme.light,
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: AppTheme.creamBackground,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.local_florist,
                        size: 64,
                        color: AppTheme.deepForestGreen,
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: AppTheme.deepForestGreen,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return MaterialApp(
            title: 'SmartRose',
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            initialRoute: AppRoutes.login,
            onGenerateRoute: (RouteSettings settings) {
              return AppRoutes.onGenerateRoute(
                settings,
                authState.isAuthenticated,
              );
            },
          );
        },
      ),
    );
  }
}
