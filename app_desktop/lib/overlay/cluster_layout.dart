import 'dart:math' as math;

/// Where the extra charms hang when the rope is at rest: out to alternate
/// sides of the main charm and each a little lower than the one before, so
/// they sit as a loose, staggered cluster rather than in a clump.
class ClusterLayout {
  const ClusterLayout._();

  /// How far each extra's cord leans from straight down at rest (degrees).
  /// The physics fans them out at this angle to start with.
  static const double leanDegrees = 35;

  /// Clear space left between neighbouring charms, in logical pixels.
  static const double gap = 6;

  /// How much lower each extra hangs than the one before it.
  static const double stagger = 26;

  /// The cord length (ring to centre) for each extra, given how far below
  /// the ring the main charm's centre hangs ([mainHang]) and the half-sizes
  /// of the main charm and the extras. The first extra goes right, the next
  /// left, and so on.
  static List<double> reaches({
    required double mainHang,
    required double mainRadius,
    required List<double> radii,
  }) {
    final lean = leanDegrees * math.pi / 180;
    final out = <double>[];
    // Centres of the charms placed so far, from the ring.
    final centres = <(double, double, double)>[(0, mainHang, mainRadius)];
    for (var k = 0; k < radii.length; k++) {
      final side = k.isEven ? 1.0 : -1.0;
      // Shortest cord that clears everything already hanging, and hangs
      // lower than the extra before it.
      var reach = radii[k];
      if (k > 0) reach = math.max(reach, out[k - 1] + stagger);
      while (true) {
        final x = side * reach * math.sin(lean);
        final y = reach * math.cos(lean);
        final clear = centres.every((c) {
          final d = math.sqrt(math.pow(x - c.$1, 2) + math.pow(y - c.$2, 2));
          return d >= c.$3 + radii[k] + gap;
        });
        if (clear) {
          centres.add((x, y, radii[k]));
          out.add(reach);
          break;
        }
        reach += 2;
      }
    }
    return out;
  }
}
