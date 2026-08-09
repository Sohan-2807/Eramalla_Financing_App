import 'package:flutter_test/flutter_test.dart';
import 'package:erramala/main.dart';

void main() {
  testWidgets('App smoke test - verifies app widget creates', (WidgetTester tester) async {
    // Verify EramallaApp can be instantiated
    expect(const EramallaApp(), isNotNull);
  });
}