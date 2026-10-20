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

  /// Flat leather braid: heavier and grippier than thread, so it settles
  /// sooner.
  static const leather = RopeStyle(
    id: 'leather',
    name: 'Leather',
    damping: 0.997,
    gravity: 5000,
    segmentMass: 0.6,
    iterations: 28,
    friction: 40,
  );

  /// Linked silver: a chain like the gold one, a touch lighter.
  static const silverChain = RopeStyle(
    id: 'silver_chain',
    name: 'Silver Chain',
    damping: 0.9975,
    gravity: 5100,
    segmentMass: 0.8,
    iterations: 30,
  );

  /// Spun silk: almost weightless, the floatiest swing of all.
  static const spiderThread = RopeStyle(
    id: 'spider_thread',
    name: 'Spider Thread',
    damping: 0.999,
    gravity: 4200,
    segmentMass: 0.05,
    iterations: 20,
    friction: 35,
  );

  /// A dark braided cord: medium weight, steady.
  static const midnightCord = RopeStyle(
    id: 'midnight_cord',
    name: 'Midnight Cord',
    damping: 0.998,
    gravity: 4800,
    segmentMass: 0.4,
    friction: 30,
  );

  /// Saffron and vermilion cotton: light, but the soft twist catches the air.
  static const templeThread = RopeStyle(
    id: 'temple_thread',
    name: 'Temple Thread',
    damping: 0.9975,
    gravity: 4700,
    segmentMass: 0.2,
    friction: 35,
  );

  /// Woven silver cord: medium weight, smooth.
  static const silverCord = RopeStyle(
    id: 'silver_cord',
    name: 'Silver Cord',
    damping: 0.998,
    gravity: 4900,
    segmentMass: 0.5,
    friction: 30,
  );

  /// Every rope, in the order they are offered.
  static const all = [
    thread,
    leather,
    goldChain,
    silverChain,
    neon,
    spiderThread,
    midnightCord,
    templeThread,
    silverCord,
  ];
}
