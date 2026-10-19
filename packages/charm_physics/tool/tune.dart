import 'dart:math' as math;

import 'package:charm_physics/charm_physics.dart';

/// Lets each rope style go from 35 degrees at rest and reports how it swings:
/// period, how much of each swing survives, the highest it ever goes, and how
/// long until it settles.
void main() {
  const start = 35 * math.pi / 180;
  for (final style in RopeStyle.all) {
    final sim = RopeSim(style: style, anchorX: 0, anchorY: 0, startAngle: start);
    final peaks = <double>[];
    final crossings = <double>[];
    var maxAngle = 0.0;
    var prev = sim.swingAngle;
    var prevDelta = 0.0;
    var t = 0.0;
    double? sleptAt;
    while (t < 30) {
      sim.step(1 / 240);
      t += 1 / 240;
      final a = sim.swingAngle;
      maxAngle = math.max(maxAngle, a.abs());
      if (prev.sign != a.sign && a != 0) crossings.add(t);
      final delta = a - prev;
      if (delta.sign != prevDelta.sign && prevDelta != 0) peaks.add(prev.abs());
      prev = a;
      prevDelta = delta;
      if (sim.asleep) {
        sleptAt = t;
        break;
      }
    }
    final period = crossings.length >= 3 ? crossings[2] - crossings[0] : double.nan;
    String deg(double r) => (r * 180 / math.pi).toStringAsFixed(1);
    print('${style.name.padRight(11)} period ${period.toStringAsFixed(2)} s | '
        'peaks ${peaks.take(5).map(deg).join(', ')} deg | '
        'kept per pass ${peaks.length > 1 ? (peaks[1] / peaks[0]).toStringAsFixed(2) : '-'} | '
        'max ${deg(maxAngle)} deg | settles ${sleptAt?.toStringAsFixed(1) ?? '>30'} s');
  }
}
