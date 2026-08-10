// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/app/sakan_app.dart';
void main() {
  testWidgets('Sakan app shell opens successfully', (tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SakanApp());
    await tester.pumpAndSettle(); // Wait for all animations to complete

    // Verify that our app opens successfully.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Digital Twin'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);

  });
}
