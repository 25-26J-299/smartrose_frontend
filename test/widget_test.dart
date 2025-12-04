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
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    final AppConfigState appConfigState = AppConfigState();
    await AppConfig.init(appConfigState: appConfigState);

    await tester.pumpWidget(SmartRoseApp(appConfigState: appConfigState));
    await tester.pumpAndSettle();

    // Verify login screen elements
    expect(find.text('SmartRose'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create an Account'), findsOneWidget);
  });
}
