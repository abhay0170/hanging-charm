/// One more charm hanging from the same ring as the main charm, on its own
/// short cord.
class ExtraCharm {
  const ExtraCharm({
    required this.mass,
    required this.radius,
    required this.reach,
  });

  /// Weight, like the main charm's (3 to 30).
  final double mass;

  /// Half its width, in logical pixels: how close another charm may come.
  final double radius;

  /// How far the charm's centre hangs below the ring on a taut cord.
  final double reach;
}

/// Two charms that knocked together.
class Collision {
  const Collision(this.a, this.b, this.speed);

  /// Which charms: 0 is the main charm, 1 and up are the extras in order.
  final int a, b;

  /// How fast they came together, in logical pixels per second.
  final double speed;
}
