import 'package:charm_physics/charm_physics.dart';

/// Times one second of simulated swinging (240 steps) for each rope style.
void main() {
  for (final style in RopeStyle.all) {
    final sim = RopeSim(style: style, anchorX: 0, anchorY: 0, startAngle: 1);
    for (var i = 0; i < 600; i++) {
      sim.step(1 / 60);
      sim.wake();
    }
    final watch = Stopwatch()..start();
    const seconds = 20;
    for (var i = 0; i < seconds * 60; i++) {
      sim.step(1 / 60);
      sim.wake();
    }
    final perSecondMs = watch.elapsedMicroseconds / 1000 / seconds;
    print('${style.name}: ${perSecondMs.toStringAsFixed(2)} ms of CPU per '
        'second of swinging (${(perSecondMs / 10).toStringAsFixed(2)}% of one core)');
  }
}
