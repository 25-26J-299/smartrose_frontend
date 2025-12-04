import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/app_routes.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppConfigState appConfigState = AppConfigState();
  await AppConfig.init(appConfigState: appConfigState);
  runApp(MyApp(appConfigState: appConfigState));
}

class MyApp extends StatelessWidget {
  const MyApp({required this.appConfigState, super.key});

  final AppConfigState appConfigState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppConfigState>.value(value: appConfigState),
      ],
      child: MaterialApp(
        title: 'SmartRose',
        theme: AppTheme.light,
        initialRoute: AppRoutes.home,
        routes: AppRoutes.routes,
      ),
    );
  }
}
