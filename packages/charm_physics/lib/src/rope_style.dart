/// Physical values for one kind of rope. Two ropes look different because
/// their values differ, not only their pictures.
class RopeStyle {
  const RopeStyle({
    required this.id,
    required this.name,
    this.segments = 20,
    this.segmentLength = 9,
    this.damping = 0.9985,
    this.gravity = 4800,
    this.segmentMass = 0.25,
    this.iterations = 24,
    this.friction = 25,
  });

  final String id;
  final String name;

  /// Number of segments the rope is solved in.
  final int segments;

  /// Rest length of one segment, in logical pixels.
  final double segmentLength;

  /// Fraction of velocity kept on each 240 Hz step (1 = no energy loss).
  /// This is the air and friction that makes a swing die down.
  final double damping;

  /// Downward acceleration in logical pixels per second squared.
  final double gravity;

  /// Mass of one rope particle; the charm is 12. A light rope lets the charm
  /// swing like a pendulum, a heavy one carries its own momentum.
  final double segmentMass;

  /// Constraint passes per step. More passes = stiffer, less stretchy rope.
  final int iterations;

  /// Steady slowing, in logical pixels per second squared, like friction at
  /// the hook. Barely touches a big swing but stops the last faint sway
  /// instead of letting it linger.
  final double friction;

  double get restLength => segments * segmentLength;

  /// Light gold thread: the charm does the swinging.
  static const thread = RopeStyle(id: 'thread', name: 'Thread');

  /// Heavy chain: the links carry real weight and rub, so it swings a little
  /// slower and settles sooner.
  static const goldChain = RopeStyle(
    id: 'gold_chain',
    name: 'Gold Chain',
    damping: 0.997,
    gravity: 5200,
    segmentMass: 1,
    iterations: 30,
  );

  /// Neon filament: very light, the freest swing.
  static const neon = RopeStyle(
    id: 'neon',
    name: 'Neon',
    damping: 0.9988,
    gravity: 4400,
    segmentMass: 0.15,
  );

  static const all = [thread, goldChain, neon];
}
