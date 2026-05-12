import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Route search filters correctly', () {
    final routes = ['Aditya University', 'Rajahmundry', 'Kakinada'];

    final result = routes.where((r) => r.contains('Raj')).toList();

    expect(result.length, 1);

    expect(result[0], 'Rajahmundry');
  });
}
