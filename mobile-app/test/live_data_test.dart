import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Live sensor data parses safely', () {
    final speed = double.tryParse('45.6') ?? 0.0;

    final temperature = double.tryParse('invalid') ?? 0.0;

    expect(speed, 45.6);

    expect(temperature, 0.0);
  });
}
