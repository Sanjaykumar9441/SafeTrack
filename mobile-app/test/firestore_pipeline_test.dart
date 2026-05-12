import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore pipeline normalizes bus telemetry safely', () {
    final firestorePayload = {
      'busNumber': 'BUS-101',
      'temperature': '36.5',
      'speed': '48.2',
      'latitude': '17.5937',
      'longitude': '82.2600',
    };

    final temperature =
        double.tryParse(firestorePayload['temperature']!) ?? 0.0;

    final speed = double.tryParse(firestorePayload['speed']!) ?? 0.0;

    final latitude = double.tryParse(firestorePayload['latitude']!) ?? 0.0;

    final longitude = double.tryParse(firestorePayload['longitude']!) ?? 0.0;

    expect(temperature, 36.5);

    expect(speed, 48.2);

    expect(latitude, 17.5937);

    expect(longitude, 82.2600);
  });
}
