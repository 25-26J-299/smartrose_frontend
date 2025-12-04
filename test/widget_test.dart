// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:smartrose_frontend/main.dart';
import 'package:smartrose_frontend/core/config/app_config.dart';

void main() {
  testWidgets('Home screen renders dashboard cards', (WidgetTester tester) async {
    final AppConfigState appConfigState = AppConfigState();
    await AppConfig.init(appConfigState: appConfigState);

    await tester.pumpWidget(MyApp(appConfigState: appConfigState));

    expect(find.text('SmartRose Dashboard'), findsOneWidget);
    expect(find.text('Freshness Monitoring'), findsOneWidget);
    expect(find.text('Nutrition Monitoring'), findsOneWidget);
  });
}
