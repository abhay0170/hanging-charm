import 'dart:math' as math;

import 'package:charm_physics/charm_physics.dart';
import 'package:test/test.dart';

const deg = math.pi / 180;

void run(RopeSim sim, double seconds, [void Function()? onFrame]) {
  final frames = (seconds * 60).round();
  for (var f = 0; f < frames; f++) {
    sim.step(1 / 60);
    onFrame?.call();
  }
}

const _extras = [
  ExtraCharm(mass: 10, radius: 20, reach: 56),
  ExtraCharm(mass: 8, radius: 18, reach: 82),
  ExtraCharm(mass: 12, radius: 22, reach: 108),
  ExtraCharm(mass: 6, radius: 16, reach: 134),
];

RopeSim cluster({RopeStyle style = RopeStyle.thread}) {
  final sim = RopeSim(style: style, anchorX: 0, anchorY: 0);
  sim.setExtras(_extras, primaryRadius: 24, primaryHangDistance: 24);
  return sim;
}

double distanceToRing(RopeSim sim, int k) => math.sqrt(
  math.pow(sim.extraX(k) - sim.ringX, 2) +
      math.pow(sim.extraY(k) - sim.ringY, 2),
);

/// Throws the main charm: carries it [reach] px sideways over a quarter
/// second and lets go.
void throwCharm(RopeSim sim, double reach) {
  sim.grab(sim.charmX, sim.charmY);
  for (var f = 1; f <= 15; f++) {
    sim.dragTo(sim.charmX + reach / 15 * 4, sim.charmY);
    run(sim, 1 / 60);
  }
  sim.release();
}

void main() {
  wallTests();
  group('breeze', () {
    test('no breeze means the rope never moves by itself', () {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      run(sim, 20);
      expect(sim.swingAngle, 0);
      expect(sim.asleep, isTrue);
    });

    test(
      'a breeze sways it both ways, no further than its strength allows',
      () {
        for (final style in RopeStyle.all) {
          for (final strength in [3.0, 6.0, 10.0]) {
            final sim = RopeSim(style: style, anchorX: 0, anchorY: 0);
            sim.windAngle = strength * deg;
            var left = 0.0, right = 0.0;
            run(sim, 60, () {
              left = math.min(left, sim.swingAngle);
              right = math.max(right, sim.swingAngle);
            });
            expect(sim.asleep, isFalse, reason: 'a breeze keeps it moving');
            final widest = math.max(-left, right);
            expect(
              widest,
              lessThan(strength * 1.5 * deg),
              reason: '${style.name} at $strength degrees',
            );
            expect(
              widest,
              greaterThan(strength * 0.3 * deg),
              reason: '${style.name} should visibly sway',
            );
            expect(left, lessThan(0), reason: 'sways to the left too');
            expect(right, greaterThan(0), reason: 'and to the right');
          }
        }
      },
    );

    test('a stronger breeze sways it further', () {
      double widest(double strength) {
        final sim = RopeSim(anchorX: 0, anchorY: 0);
        sim.windAngle = strength * deg;
        var most = 0.0;
        run(sim, 40, () => most = math.max(most, sim.swingAngle.abs()));
        return most;
      }

      expect(widest(3), lessThan(widest(6)));
      expect(widest(6), lessThan(widest(10)));
    });

    test('when the breeze stops the rope settles and sleeps', () {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      sim.windAngle = 8 * deg;
      run(sim, 20);
      sim.windAngle = 0;
      run(sim, 90);
      expect(sim.asleep, isTrue);
      expect(sim.swingAngle.abs(), lessThan(1 * deg));
    });

    test('odd values are made safe', () {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      sim.windAngle = double.nan;
      expect(sim.windAngle, 0);
      sim.windAngle = -1;
      expect(sim.windAngle, 0);
      sim.windAngle = 100;
      expect(sim.windAngle, lessThanOrEqualTo(0.5));
    });

    test('a breeze never makes a touch swing higher than the touch did', () {
      // Let go at 20 degrees in a light breeze: it must not go past about
      // 20 degrees plus what the breeze alone can do.
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      sim.windAngle = 4 * deg;
      sim.grab(sim.charmX, sim.charmY);
      final reach = sim.restLength * 0.98;
      for (var f = 1; f <= 30; f++) {
        final a = 20 * deg * f / 30;
        sim.dragTo(math.sin(a) * reach, math.cos(a) * reach);
        run(sim, 1 / 60);
      }
      sim.release();
      var widest = 0.0;
      run(sim, 20, () => widest = math.max(widest, sim.swingAngle.abs()));
      expect(widest, lessThan((20 + 4 * 1.5) * deg));
    });
  });

  group('extra charms', () {
    test('they hang on their cords, apart from each other, and settle', () {
      final sim = cluster();
      run(sim, 12);
      expect(sim.asleep, isTrue);
      expect(sim.extraCount, 4);
      for (var k = 0; k < 4; k++) {
        expect(
          distanceToRing(sim, k),
          lessThanOrEqualTo(_extras[k].reach + 0.5),
        );
        expect(sim.extraX(k).isFinite && sim.extraY(k).isFinite, isTrue);
      }
      // No two overlap by more than a pixel or two.
      final radii = [24.0, for (final e in _extras) e.radius];
      final xs = [sim.charmCenterX, for (var k = 0; k < 4; k++) sim.extraX(k)];
      final ys = [sim.charmCenterY, for (var k = 0; k < 4; k++) sim.extraY(k)];
      for (var a = 0; a < 5; a++) {
        for (var b = a + 1; b < 5; b++) {
          final d = math.sqrt(
            math.pow(xs[a] - xs[b], 2) + math.pow(ys[a] - ys[b], 2),
          );
          expect(
            d,
            greaterThan(radii[a] + radii[b] - 3),
            reason: 'charms $a and $b overlap',
          );
        }
      }
    });

    test('a throw never sends one past its cord, and nothing blows up', () {
      for (final style in RopeStyle.all) {
        final sim = cluster(style: style);
        run(sim, 3);
        throwCharm(sim, 160);
        run(sim, 12, () {
          for (var k = 0; k < 4; k++) {
            expect(
              distanceToRing(sim, k),
              lessThanOrEqualTo(_extras[k].reach + 1.5),
            );
            expect(sim.extraX(k).abs(), lessThan(600));
            expect(sim.extraY(k), lessThan(600));
          }
        });
      }
    });

    test('they knock together when thrown, and it is reported once', () {
      final sim = cluster();
      run(sim, 3);
      throwCharm(sim, 180);
      final knocks = <Collision>[];
      run(sim, 6, () => knocks.addAll(sim.takeCollisions()));
      expect(knocks, isNotEmpty);
      for (final k in knocks) {
        expect(k.speed, greaterThan(RopeSim.minKnockSpeed));
        expect(k.a, lessThan(k.b));
        expect(k.b, lessThanOrEqualTo(4));
      }
      expect(sim.takeCollisions(), isEmpty);
    });

    test('a gentle sway makes no knocks', () {
      final sim = cluster();
      run(sim, 5);
      sim.takeCollisions();
      sim.nudge(40, 0);
      final knocks = <Collision>[];
      run(sim, 5, () => knocks.addAll(sim.takeCollisions()));
      expect(knocks, isEmpty);
    });

    test('an extra can be picked up and carried', () {
      final sim = cluster();
      run(sim, 5);
      final k = 1;
      sim.grab(sim.extraX(k), sim.extraY(k), charm: k + 1);
      expect(sim.isGrabbed, isTrue);
      final targetX = sim.extraX(k) + 40, targetY = sim.extraY(k) + 10;
      for (var f = 0; f < 30; f++) {
        sim.dragTo(targetX, targetY);
        run(sim, 1 / 60);
      }
      expect(sim.extraX(k), closeTo(targetX, 2));
      expect(sim.extraY(k), closeTo(targetY, 2));
      sim.release();
      // Carrying one pulls the ring a little, so the whole rope swings and
      // takes a while to settle.
      run(sim, 60);
      expect(sim.isGrabbed, isFalse);
      expect(sim.asleep, isTrue);
    });

    test('the rope never stretches because of its extras', () {
      final sim = cluster();
      var longest = 0.0;
      run(sim, 3);
      throwCharm(sim, 150);
      run(sim, 10, () => longest = math.max(longest, sim.ropeLength));
      expect(longest, lessThan(sim.restLength * 1.06));
    });

    test('a hard shake of every charm stays finite and in range', () {
      final random = math.Random(7);
      final sim = cluster();
      for (var round = 0; round < 40; round++) {
        final pick = random.nextInt(5);
        final x = pick == 0 ? sim.charmX : sim.extraX(pick - 1);
        final y = pick == 0 ? sim.charmY : sim.extraY(pick - 1);
        sim.grab(x, y, charm: pick);
        for (var f = 0; f < 20; f++) {
          sim.dragTo(
            x + (random.nextDouble() - 0.5) * 300,
            y + (random.nextDouble() - 0.3) * 200,
          );
          run(sim, 1 / 60);
        }
        sim.release();
        run(sim, 0.4);
        for (var k = 0; k < 4; k++) {
          expect(sim.extraX(k).abs(), lessThan(1500));
          expect(sim.extraY(k).abs(), lessThan(1500));
        }
        expect(sim.charmX.abs(), lessThan(1500));
      }
    });

    test('extras sway in a breeze too, and stay on their cords', () {
      final sim = cluster();
      sim.windAngle = 8 * deg;
      var wide = 0.0;
      run(sim, 40, () {
        wide = math.max(wide, (sim.extraX(3) - sim.ringX).abs());
        expect(distanceToRing(sim, 3), lessThanOrEqualTo(134 + 1.5));
      });
      expect(wide, greaterThan(3));
    });

    test('taking the extras away leaves the main charm alone', () {
      final sim = cluster();
      run(sim, 3);
      sim.setExtras(const []);
      expect(sim.extraCount, 0);
      run(sim, 5);
      expect(sim.asleep, isTrue);
    });
  });
}

void wallTests() {
  group('walls', () {
    double leftmost(RopeSim sim) {
      var most = double.infinity;
      for (var i = 0; i < sim.particleCount; i++) {
        most = math.min(most, sim.x(i));
      }
      for (var k = 0; k < sim.extraCount; k++) {
        most = math.min(most, sim.extraX(k) - _extras[k].radius);
      }
      return most;
    }

    test('without a wall a hard throw swings out past the line', () {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      throwCharm(sim, -150);
      var most = 0.0;
      run(sim, 4, () => most = math.min(most, sim.charmX));
      expect(most, lessThan(-60));
    });

    test('a wall on the left stops the charm with its edge on the wall', () {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      sim.setWalls(left: -40, charmRadius: 20);
      throwCharm(sim, -150);
      var most = 0.0;
      run(sim, 8, () {
        most = math.min(most, sim.charmX);
        expect(leftmost(sim), greaterThanOrEqualTo(-40 - 0.5));
      });
      expect(most, greaterThanOrEqualTo(-20 - 0.5));
      expect(most, lessThan(-15), reason: 'it did reach the wall');
    });

    test('a wall on the right works the same way', () {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      sim.setWalls(right: 40, charmRadius: 20);
      throwCharm(sim, 150);
      var most = 0.0;
      run(sim, 8, () {
        most = math.max(most, sim.charmX);
        for (var i = 0; i < sim.particleCount; i++) {
          expect(sim.x(i), lessThanOrEqualTo(40 + 0.5));
        }
      });
      expect(most, lessThanOrEqualTo(20 + 0.5));
    });

    test('it comes back off the wall, and loses energy doing so', () {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      sim.setWalls(left: -40, charmRadius: 20);
      throwCharm(sim, -150);
      var touched = false, cameBack = false;
      var early = double.negativeInfinity, late = double.negativeInfinity;
      run(sim, 1.5, () {
        if (sim.charmX <= -19.5) touched = true;
        early = math.max(early, sim.energy);
      });
      run(sim, 12, () {
        if (sim.charmX <= -19.5) touched = true;
        if (touched && sim.charmX > 0) cameBack = true;
      });
      run(sim, 5, () => late = math.max(late, sim.energy));
      expect(touched, isTrue);
      expect(cameBack, isTrue);
      expect(late, lessThan(early));
    });

    test('extra charms stop at the wall too, and it settles', () {
      final sim = cluster();
      sim.setWalls(left: -60, charmRadius: 24);
      run(sim, 3);
      throwCharm(sim, -170);
      run(
        sim,
        10,
        () => expect(leftmost(sim), greaterThanOrEqualTo(-60 - 0.5)),
      );
      run(sim, 60);
      expect(sim.asleep, isTrue);
    });

    test('taking the walls away lets it swing free again', () {
      final sim = RopeSim(anchorX: 0, anchorY: 0);
      sim.setWalls(left: -40, charmRadius: 20);
      sim.setWalls();
      throwCharm(sim, -150);
      var most = 0.0;
      run(sim, 4, () => most = math.min(most, sim.charmX));
      expect(most, lessThan(-60));
    });
  });
}
