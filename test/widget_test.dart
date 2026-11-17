import 'package:flutter_test/flutter_test.dart';
import 'package:waveform/utils/helpers.dart';

void main() {
  test('AppHelpers.formatDuration works', () {
    expect(AppHelpers.formatDuration(const Duration(minutes: 5, seconds: 30)), '05:30');
    expect(AppHelpers.formatDuration(const Duration(hours: 1, minutes: 5, seconds: 3)), '1:05:03');
    expect(AppHelpers.formatDuration(Duration.zero), '00:00');
  });

  test('AppHelpers.getInitials works', () {
    expect(AppHelpers.getInitials('John Doe'), 'JD');
    expect(AppHelpers.getInitials('Alice'), 'A');
    expect(AppHelpers.getInitials(''), '?');
  });

  test('AppHelpers.generateArtColor returns consistent color', () {
    final c1 = AppHelpers.generateArtColor('test');
    final c2 = AppHelpers.generateArtColor('test');
    expect(c1, equals(c2));
  });

  test('AppHelpers.generateArtGradient returns two colors', () {
    final gradient = AppHelpers.generateArtGradient('seed');
    expect(gradient.length, 2);
  });
}
