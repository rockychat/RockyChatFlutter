// Basic smoke test for RockyChatApp.

import 'package:flutter_test/flutter_test.dart';

import 'package:rockychat/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RockyChatApp());
    // Verify that the app renders without crashing.
    expect(find.byType(RockyChatApp), findsOneWidget);
  });
}
