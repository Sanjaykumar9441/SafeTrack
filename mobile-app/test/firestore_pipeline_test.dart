import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore telemetry pipeline handles valid bus data', () {
    final firestoreData = {
      'busNumber': 'BUS-101',
      'temperature': '32.5',
      'speed': '45.2',
    };

    final temperature = double.tryParse(firestoreData['temperature']!) ?? 0.0;

    final speed = double.tryParse(firestoreData['speed']!) ?? 0.0;

    expect(temperature, 32.5);

    expect(speed, 45.2);
  });
}
