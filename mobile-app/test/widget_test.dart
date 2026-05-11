import 'package:flutter_test/flutter_test.dart';
import 'package:safetrack/models/bus.dart';

void main() {
  test('Bus.fromJson safely handles missing values', () {
    final json = {
      'busNumber': 'BUS-101',
      'busName': 'SafeTrack Express',
      'temperature': null,
      'currentLatitude': null,
      'currentLongitude': null,
    };

    final bus = Bus.fromJson(json);

    expect(bus.busNumber, 'BUS-101');

    expect(bus.busName, 'SafeTrack Express');

    expect(bus.temperature, 0.0);

    expect(bus.currentLatitude, 0.0);

    expect(bus.currentLongitude, 0.0);
  });
}
