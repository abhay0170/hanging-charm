import 'dart:math' as math;

import 'package:charm_desktop/overlay/cluster_layout.dart';
import 'package:flutter_test/flutter_test.dart';

List<(double, double)> centres(List<double> reaches) {
  const lean = ClusterLayout.leanDegrees * math.pi / 180;
  return [
    for (var k = 0; k < reaches.length; k++)
      (
        (k.isEven ? 1.0 : -1.0) * reaches[k] * math.sin(lean),
        reaches[k] * math.cos(lean)
      ),
  ];
}

void main() {
  test('extras go to alternate sides and each hangs lower than the last', () {
    final reaches = ClusterLayout.reaches(
        mainHang: 28, mainRadius: 20, radii: [18, 18, 18, 18]);
    final c = centres(reaches);
    expect(c[0].$1, greaterThan(0), reason: 'first goes right');
    expect(c[1].$1, lessThan(0), reason: 'second goes left');
    expect(c[2].$1, greaterThan(0));
    for (var k = 1; k < c.length; k++) {
      expect(c[k].$2, greaterThan(c[k - 1].$2 + 15),
          reason: 'charm $k hangs lower than charm ${k - 1}');
    }
  });

  test('none overlap each other or the main charm, whatever the sizes', () {
    final random = math.Random(3);
    for (var round = 0; round < 200; round++) {
      final mainRadius = 12 + random.nextDouble() * 24;
      final mainHang = 14 + random.nextDouble() * 30;
      final radii = [
        for (var k = 0; k < 1 + random.nextInt(4); k++)
          10 + random.nextDouble() * 24,
      ];
      final reaches = ClusterLayout.reaches(
          mainHang: mainHang, mainRadius: mainRadius, radii: radii);
      final c = centres(reaches);
      for (var a = 0; a < c.length; a++) {
        final dMain =
            math.sqrt(math.pow(c[a].$1, 2) + math.pow(c[a].$2 - mainHang, 2));
        expect(dMain, greaterThanOrEqualTo(mainRadius + radii[a] + 5.9),
            reason: 'extra $a against the main charm');
        for (var b = a + 1; b < c.length; b++) {
          final d = math.sqrt(math.pow(c[a].$1 - c[b].$1, 2) +
              math.pow(c[a].$2 - c[b].$2, 2));
          expect(d, greaterThanOrEqualTo(radii[a] + radii[b] + 5.9),
              reason: 'extras $a and $b');
        }
      }
    }
  });

  test('a small charm hangs closer than a big one', () {
    final small = ClusterLayout.reaches(
        mainHang: 28, mainRadius: 20, radii: [12]).single;
    final big = ClusterLayout.reaches(
        mainHang: 28, mainRadius: 20, radii: [30]).single;
    expect(small, lessThan(big));
  });

  test('no extras, no cords', () {
    expect(
        ClusterLayout.reaches(mainHang: 28, mainRadius: 20, radii: const []),
        isEmpty);
  });
}
