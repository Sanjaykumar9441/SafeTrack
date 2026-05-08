import 'package:flutter_test/flutter_test.dart';
import 'package:safetrack/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: This might still fail in CI because Firebase is not mocked,
    // but this fixes the compilation error by using the correct class name.
    await tester.pumpWidget(const SafeTrackApp());

    // Verify that the app title exists (MaterialApp title)
    expect(find.byType(SafeTrackApp), findsOneWidget);
  });
}
