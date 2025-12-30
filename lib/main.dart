import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/app_routes.dart';
import 'core/auth/auth_state.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppConfigState appConfigState = AppConfigState();
  await AppConfig.init(appConfigState: appConfigState);
  final AuthState authState = AuthState();
  await authState.restoreSession();
  runApp(
    SmartRoseApp(
      appConfigState: appConfigState,
      authState: authState,
    ),
  );
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
