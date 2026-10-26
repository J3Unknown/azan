import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/helpers/ui_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Qibla angle calculation from Cairo to Kaaba', () {
    // Cairo coordinates ~ (30.0444, 31.2357)
    final qibla = calculateQibla(30.0444, 31.2357);

    // Qibla from Cairo is approximately 136° (South-East)
    expect(qibla.bearing, greaterThan(130.0));
    expect(qibla.bearing, lessThan(145.0));
    expect(qibla.directionText, 'SE');
    expect(qibla.distanceKm, greaterThan(1200.0));
  });

  test('UI helpers time and duration formatting', () {
    final dt = DateTime(2026, 10, 27, 4, 52);
    expect(UiHelpers.formatTime12(dt), '04:52 AM');

    final duration = const Duration(hours: 2, minutes: 14, seconds: 35);
    expect(UiHelpers.formatDuration(duration), '02:14:35');
  });
}
