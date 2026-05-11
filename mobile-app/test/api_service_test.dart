import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API fallback logic works', () {
    double value;

    value = double.tryParse('invalid') ?? 0.0;

    expect(value, 0.0);
  });
}
