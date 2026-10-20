# charm_physics

Rope and charm physics for the desktop charm app. Pure Dart: no Flutter or
platform types, so it runs and is tested anywhere.

## The rule: every swing comes from the user

- It starts still and stays still until touched.
- While nothing touches it, the total energy can only fall. Let go at 35°
  and it never passes 35°. A throw lifts it at most level with the anchor.
- A throw leaves at the hand's speed: hand movement is spread evenly over
  the solver steps between pointer events.
- Moving the anchor by d px swings the charm at most d px. Jerky pin drags
  are glided over a few steps.
- Nudges are proportional: a push 4× harder swings about 4× further.

## Feel (from 35°, `dart run tool/tune.dart`)

| Rope | Material | Swing period | Each swing keeps | Settles in |
|---|---|---|---|---|
| Thread | light gold thread | 1.22 s | 84% | 9.8 s |
| Leather | flat braid, grippy | 1.17 s | 74% | 6.0 s |
| Gold Chain | heavy links | 1.12 s | 75% | 6.9 s |
| Silver Chain | lighter links | 1.15 s | 78% | 7.6 s |
| Neon | light filament | 1.28 s | 85% | 10.8 s |
| Spider Thread | silk, almost weightless | 1.32 s | 86% | 9.8 s |
| Midnight Cord | dark braid | 1.20 s | 80% | 7.9 s |
| Temple Thread | twisted cotton | 1.23 s | 77% | 6.8 s |
| Silver Cord | woven silver | 1.18 s | 80% | 8.2 s |

The charm carries most of the weight (12 against 0.05–1 per rope point), so
it swings like a pendulum. Heavier ropes carry momentum of their own and
swing a little faster. Air damping plus a little friction at the hook make
the last faint sway stop instead of lingering. Every rope passes every test.

## How it is solved

- Verlet integration, 20 segments, fixed 240 Hz steps whatever the display
  rate. Sleeps when still, so a resting charm costs nothing.
- Long-range attachment (no point further from the anchor than its share
  of the rope), mass-weighted segment constraints, then tightening that
  moves only the light rope points. The old pass that yanked the charm into
  place was adding energy (let go at 35°, it swung to 69°), and is gone.
- An energy cap takes any leftover numerical gain back out of the speed.

```bash
dart test                  # 64 tests (most run once per rope)
dart run tool/tune.dart    # swing period, decay and settle time per rope
dart run tool/bench.dart   # CPU cost: ~0.4% of one core while swinging
```
