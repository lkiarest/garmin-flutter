import 'package:flutter_test/flutter_test.dart';
import 'package:garmin_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GarminFlutterApp());

    // Verify the app starts with the home page
    expect(find.text('Garmin Navigation'), findsOneWidget);
    expect(find.text('Scan for Devices'), findsOneWidget);
  });
}
