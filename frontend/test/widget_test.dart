// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_demo/main.dart';

void main() {
  testWidgets('configuration error is visible', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ConfigurationErrorApp(message: 'Missing SUPABASE_URL'),
    );

    expect(find.text('Missing SUPABASE_URL'), findsOneWidget);
  });
}
