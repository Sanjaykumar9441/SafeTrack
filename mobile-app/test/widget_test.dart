import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SafeTrack widget test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('SafeTrack'),
        ),
      ),
    );

    expect(find.text('SafeTrack'), findsOneWidget);
  });
}
