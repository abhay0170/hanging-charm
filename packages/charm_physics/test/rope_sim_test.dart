import 'dart:math' as math;

import 'package:charm_physics/charm_physics.dart';
import 'package:test/test.dart';

/// Runs [sim] for [seconds] in 60 Hz frames, calling [onFrame] after each.
void run(RopeSim sim, double seconds, [void Function()? onFrame]) {
  final frames = (seconds * 60).round();
  for (var f = 0; f < frames; f++) {
    sim.step(1 / 60);
    onFrame?.call();
  }
}

/// Grabs the charm, carries it by hand to [angle] from the anchor over half
/// a second, holds it still for half a second, and lets go.
void holdAndRelease(RopeSim sim, double angle) {
  sim.grab(sim.charmX, sim.charmY);
  final reach = sim.restLength * 0.98;
  for (var f = 1; f <= 30; f++) {
    final a = angle * f / 30;
    sim.dragTo(sim.anchorX + math.sin(a) * reach,
        sim.anchorY + math.cos(a) * reach);
    sim.step(1 / 60);
  }
  run(sim, 0.5);
  sim.release();
}

/// Largest swing angle, in radians, over [seconds] of free swinging.
double maxSwing(RopeSim sim, double seconds) {
  var most = 0.0;
  run(sim, seconds, () => most = math.max(most, sim.swingAngle.abs()));
  return most;
}

const deg = math.pi / 180;

void main() {
  for (final style in RopeStyle.all) {
    group(style.name, () {
      test('starts still and stays still until someone touches it', () {
        final sim = RopeSim(style: style, anchorX: 500, anchorY: 0);
        final x = sim.charmX, y = sim.charmY;
        run(sim, 5);
        expect(sim.charmX, closeTo(x, 1e-6));
        expect(sim.charmY, closeTo(y, 1e-6));
        expect(sim.asleep, isTrue);
      });

      test('let go from an angle, never swings past that angle', () {
        for (final angle in [10 * deg, 35 * deg, 70 * deg]) {
          final sim = RopeSim(style: style, anchorX: 500, anchorY: 0);
          holdAndRelease(sim, angle);
          expect(maxSwing(sim, 20), lessThanOrEqualTo(angle + 0.5 * deg),
              reason: 'released at ${angle / deg} degrees');
        }
      });

      test('swings back naturally: the far side reaches most of the way', () {
        final sim = RopeSim(style: style, anchorX: 500, anchorY: 0);
        holdAndRelease(sim, 35 * deg);
        // Measure the first swing to the other side only.
        var farthest = 0.0;
        run(sim, 0.9, () => farthest = math.max(farthest, -sim.swingAngle));
        expect(farthest, greaterThan(35 * deg * 0.7));
        expect(farthest, lessThanOrEqualTo(35 * deg));
      });

      test('settles and sleeps within 12 seconds', () {
        final sim = RopeSim(style: style, anchorX: 500, anchorY: 0);
        holdAndRelease(sim, 45 * deg);
        run(sim, 12);
        expect(sim.asleep, isTrue);
        expect(sim.charmX, closeTo(500, 1));
      });

      test('energy never rises once the hand lets go', () {
        final sim = RopeSim(style: style, anchorX: 500, anchorY: 0);
        sim.grab(sim.charmX, sim.charmY);
        for (var f = 0; f < 20; f++) {
          sim.dragTo(500 - 120 + f * 14.0, 150);
          sim.step(1 / 60);
        }
        sim.release();
        sim.step(1 / 60);
        var last = sim.energy;
        var rose = 0.0;
        run(sim, 8, () {
          rose = math.max(rose, sim.energy - last);
          last = sim.energy;
        });
        expect(rose, lessThanOrEqualTo(1e-6));
      });

      test('never stretches beyond 1.02x its rest length', () {
        final sim = RopeSim(style: style, anchorX: 500, anchorY: 0);
        var longest = 0.0;
        void measure() => longest = math.max(longest, sim.ropeLength);
        sim.grab(sim.charmX, sim.charmY);
        for (var f = 0; f < 60; f++) {
          sim.dragTo(500 + 3000 * math.sin(f / 4), 2000.0 * (f % 2));
          sim.step(1 / 60);
          measure();
        }
        sim.release();
        run(sim, 3, measure);
        sim.nudge(6000, -6000);
        run(sim, 3, measure);
        expect(longest, lessThanOrEqualTo(sim.restLength * 1.02));
      });
    });
  }

  test('a throw leaves at the speed of the hand, not faster', () {
    final sim = RopeSim(anchorX: 0, anchorY: 0);
    sim.grab(sim.charmX, sim.charmY);
    const handStep = 6.0; // pixels per 60 Hz frame = 360 px/s
    for (var f = 0; f < 25; f++) {
      sim.dragTo(-75 + f * handStep, 160);
      sim.step(1 / 60);
    }
    final x0 = sim.charmX, y0 = sim.charmY;
    sim.release();
    sim.step(1 / 60);
    final speed = math.sqrt(math.pow(sim.charmX - x0, 2) +
            math.pow(sim.charmY - y0, 2)) *
        60;
    expect(speed, lessThanOrEqualTo(handStep * 60 * 1.05));
    expect(speed, greaterThan(handStep * 60 * 0.5));
  });

  test('a harder throw swings further, but never above the anchor', () {
    double throwWith(double handSpeed) {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      sim.grab(sim.charmX, sim.charmY);
      final step = handSpeed / 60;
      for (var f = 0; f < 12; f++) {
        sim.dragTo(-step * 6 + f * step, sim.restLength * 0.97);
        sim.step(1 / 60);
      }
      sim.release();
      var highest = double.infinity;
      final most = maxSwing(sim, 0.1);
      run(sim, 6, () => highest = math.min(highest, sim.charmY));
      expect(highest, greaterThanOrEqualTo(sim.anchorY - 1),
          reason: 'thrown at $handSpeed px/s rose above the anchor');
      return math.max(most, maxSwing(sim, 0));
    }

    final soft = throwWith(150);
    final medium = throwWith(500);
    final hard = throwWith(3000);
    expect(soft, lessThan(medium));
    expect(medium, lessThanOrEqualTo(hard));
  });

  test('a nudge swings it in proportion: small push, small swing', () {
    double swingAfter(double push) {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      sim.nudge(push, 0);
      return maxSwing(sim, 3);
    }

    final small = swingAfter(80);
    final big = swingAfter(320);
    expect(small, lessThan(10 * deg));
    expect(big, greaterThan(small * 3));
    expect(big, lessThan(small * 5));
  });

  test('moving the anchor swings the charm no further than the anchor moved',
      () {
    for (final distance in [20.0, 60.0, 150.0]) {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      // A brisk drag of the pin over a tenth of a second, then stop.
      for (var f = 1; f <= 6; f++) {
        sim.moveAnchor(distance * f / 6, 0);
        sim.step(1 / 60);
      }
      var widest = 0.0;
      run(sim, 6, () => widest = math.max(widest, (sim.charmX - sim.anchorX).abs()));
      expect(widest, lessThanOrEqualTo(distance + 0.5),
          reason: 'anchor moved $distance px');
      expect(widest, greaterThan(distance * 0.2),
          reason: 'anchor moved $distance px but the charm barely swung');
    }
  });

  test('steps at a fixed rate whatever the frame rate', () {
    final a = RopeSim(anchorX: 0, anchorY: 0, startAngle: 0.8);
    final b = RopeSim(anchorX: 0, anchorY: 0, startAngle: 0.8);
    var stepsA = 0, stepsB = 0;
    for (var i = 0; i < 60; i++) {
      stepsA += a.step(1 / 60);
    }
    for (var i = 0; i < 144; i++) {
      stepsB += b.step(1 / 144);
    }
    expect(stepsA, RopeSim.stepsPerSecond);
    expect(stepsB, RopeSim.stepsPerSecond);
    expect(a.charmX, closeTo(b.charmX, 1e-6));
    expect(a.charmY, closeTo(b.charmY, 1e-6));
  });

  test('a sleeping rope does no work until woken', () {
    final sim = RopeSim(anchorX: 0, anchorY: 0);
    run(sim, 2);
    expect(sim.asleep, isTrue);
    expect(sim.step(1 / 60), 0);
    sim.nudge(400, 0);
    expect(sim.asleep, isFalse);
    expect(sim.step(1 / 60), greaterThan(0));
  });

  test('shifting the frame moves nothing on screen and wakes nothing', () {
    final sim = RopeSim(anchorX: 260, anchorY: 0);
    run(sim, 2);
    expect(sim.asleep, isTrue);
    final x = sim.charmX, y = sim.charmY;
    sim.shiftFrame(-40, 0);
    expect(sim.asleep, isTrue);
    expect(sim.charmX, x - 40);
    expect(sim.charmY, y);
    expect(sim.anchorX, 220);
    // Putting the anchor back where it was is a 40 px move on screen.
    sim.moveAnchor(260, 0);
    run(sim, 0.1);
    expect(sim.asleep, isFalse);
    expect(sim.charmX, lessThan(sim.anchorX));
  });

  test('a dragged charm stays within reach of the anchor', () {
    final sim = RopeSim(anchorX: 0, anchorY: 0);
    sim.grab(sim.charmX, sim.charmY);
    sim.dragTo(5000, 5000);
    run(sim, 1);
    final reach = math.sqrt(sim.charmX * sim.charmX + sim.charmY * sim.charmY);
    expect(reach, lessThanOrEqualTo(sim.restLength + 1e-6));
  });

  test('changing rope style keeps the charm where it was pointing', () {
    final sim = RopeSim(anchorX: 0, anchorY: 0, startAngle: 0.5);
    final angle = sim.charmAngle;
    sim.style = RopeStyle.goldChain;
    expect(sim.charmAngle, closeTo(angle, 1e-9));
    expect(sim.particleCount, RopeStyle.goldChain.segments + 1);
  });
}
