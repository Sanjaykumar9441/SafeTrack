import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Invalid sensor values fallback safely', () {
    final payload = {
      'temperature': 'invalid',
      'speed': null,
    };

    final temperature =
        double.tryParse(payload['temperature']?.toString() ?? '') ?? 0.0;

    final speed = double.tryParse(payload['speed']?.toString() ?? '') ?? 0.0;

    expect(temperature, 0.0);

    expect(speed, 0.0);
  });
}
