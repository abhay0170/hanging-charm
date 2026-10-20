import 'dart:math' as math;
import 'dart:typed_data';

import 'rope_style.dart';

/// A rope hanging from an anchor with a charm on its free end.
///
/// Particle 0 is the anchor, the last particle is the charm. The rope is
/// integrated with Verlet at a fixed [stepsPerSecond], so it behaves the same
/// on a 60 Hz and a 144 Hz display. It only resists stretching (a rope, not a
/// rod) and never grows beyond its rest length. When nothing moves it falls
/// [asleep] and [step] does no work until something wakes it.
///
/// The swing only ever comes from the user. While nobody is holding the
/// charm, moving the anchor or nudging it, the rope's total energy can only
/// fall, so it never swings higher than the motion that started it, and a
/// throw can lift the charm at most level with the anchor.
class RopeSim {
  RopeSim({
    this._style = RopeStyle.thread,
    required this._anchorX,
    required this._anchorY,
    this.charmMass = 12,
    double startAngle = 0,
  })  : _anchorTargetX = _anchorX,
        _anchorTargetY = _anchorY {
    _build(startAngle);
  }

  static const int stepsPerSecond = 240;
  static const double dt = 1 / stepsPerSecond;

  /// Longest frame the solver will catch up on; longer gaps (a sleeping
  /// laptop, a debugger pause) are dropped rather than simulated.
  static const double maxFrameSeconds = 0.1;

  /// Fastest any particle may move, in logical pixels per second.
  static const double maxSpeed = 6000;

  /// Below this per-step movement (in pixels) the rope counts as still.
  static const double sleepThreshold = 0.01;

  /// How long the rope must stay still before it sleeps.
  static const double sleepAfterSeconds = 0.75;

  /// Longest gap, in steps, the hand's motion is spread over. Pointer moves
  /// arrive every 4 or so steps; spreading each move evenly across the gap
  /// gives the held charm the hand's real speed instead of a jump then a
  /// stop, so a throw leaves at exactly the speed it was thrown.
  static const int maxHandSteps = 12;

  /// How quickly the anchor follows where it was moved to, per step (0..1).
  /// A jerky drag of the pin is spread over a few steps instead of kicking
  /// the rope harder than the hand moved.
  static const double anchorFollow = 0.35;

  /// Mass of the charm relative to one rope particle of mass 1.
  final double charmMass;

  RopeStyle _style;
  double _anchorX;
  double _anchorY;
  double _anchorTargetX;
  double _anchorTargetY;

  late Float64List _px, _py, _ox, _oy, _invMass;

  double _accumulator = 0;
  int _stillSteps = 0;
  bool _asleep = false;

  bool _grabbed = false;

  /// Where the hand is in the simulation, how far it moves per step, and for
  /// how many more steps, to reach the last pointer position.
  double _handX = 0, _handY = 0;
  double _handVX = 0, _handVY = 0;
  int _handStepsLeft = 0;
  int _stepsSinceDrag = 0;
  int _lastHandSteps = 4;

  /// Set when something the user did added energy since the last step.
  bool _userInput = false;
  bool _inputWasActive = false;

  /// The most energy the rope may have right now. Falls with every step
  /// nobody touches it; only user input lets it rise.
  double _energyCap = 0;
  double _kinetic = 0, _potential = 0;

  RopeStyle get style => _style;

  /// Swaps the rope style, rebuilding the rope along the charm's current
  /// direction so the charm does not jump. The new rope starts still.
  set style(RopeStyle value) {
    if (identical(value, _style)) return;
    final angle = charmAngle;
    _style = value;
    _build(angle);
    wake();
  }

  int get particleCount => _px.length;
  double x(int i) => _px[i];
  double y(int i) => _py[i];

  /// Where the anchor is now. It glides toward [anchorTargetX] after a move.
  double get anchorX => _anchorX;
  double get anchorY => _anchorY;

  /// Where the anchor was last moved to.
  double get anchorTargetX => _anchorTargetX;
  double get anchorTargetY => _anchorTargetY;

  double get charmX => _px[_px.length - 1];
  double get charmY => _py[_py.length - 1];

  /// Angle of the last segment from straight down, in radians. Positive when
  /// the charm has swung to the right of the segment above it.
  double get charmAngle {
    final n = _px.length - 1;
    return math.atan2(_px[n] - _px[n - 1], _py[n] - _py[n - 1]);
  }

  /// How fast the charm moved over the last step, in logical pixels per
  /// second.
  double get charmSpeed {
    final n = _px.length - 1;
    final dx = _px[n] - _ox[n];
    final dy = _py[n] - _oy[n];
    return math.sqrt(dx * dx + dy * dy) / dt;
  }

  /// Whether the anchor is still gliding toward where it was moved to.
  bool get anchorMoving =>
      _anchorX != _anchorTargetX || _anchorY != _anchorTargetY;

  /// Angle of the charm from straight below the anchor, in radians.
  double get swingAngle =>
      math.atan2(charmX - _anchorX, charmY - _anchorY);

  /// Total energy of the rope and charm after the last step: kinetic plus
  /// gravitational, zero when everything is at rest level with the anchor.
  double get energy => _kinetic + _potential;

  bool get asleep => _asleep;
  bool get isGrabbed => _grabbed;

  double get restLength => _style.restLength;

  /// Current length of the rope measured along its particles.
  double get ropeLength {
    var total = 0.0;
    for (var i = 1; i < _px.length; i++) {
      total += _dist(i - 1, i);
    }
    return total;
  }

  void wake() {
    _asleep = false;
    _stillSteps = 0;
  }

  /// Moves the anchor to ([x], [y]). It glides there over a few steps.
  void moveAnchor(double x, double y) {
    if (x == _anchorTargetX && y == _anchorTargetY) return;
    _anchorTargetX = x;
    _anchorTargetY = y;
    wake();
  }

  /// Moves the coordinate frame: every particle, the anchor and any grab
  /// target shift by ([dx], [dy]) with their velocities unchanged. Used when
  /// the window the rope is drawn in moves, so the rope stays put on screen.
  void shiftFrame(double dx, double dy) {
    for (var i = 0; i < _px.length; i++) {
      _px[i] += dx;
      _py[i] += dy;
      _ox[i] += dx;
      _oy[i] += dy;
    }
    _anchorX += dx;
    _anchorY += dy;
    _anchorTargetX += dx;
    _anchorTargetY += dy;
    _handX += dx;
    _handY += dy;
  }

  /// Starts holding the charm with the hand at ([x], [y]).
  void grab(double x, double y) {
    _grabbed = true;
    _handX = x;
    _handY = y;
    _handVX = _handVY = 0;
    _handStepsLeft = 0;
    _stepsSinceDrag = maxHandSteps;
    wake();
  }

  /// The hand moved to ([x], [y]). The charm travels there evenly over the
  /// time since the previous move, so it carries the hand's real speed.
  void dragTo(double x, double y) {
    if (!_grabbed) return;
    // Several moves within one frame share that frame's time.
    final steps = _stepsSinceDrag == 0
        ? _lastHandSteps
        : _stepsSinceDrag.clamp(1, maxHandSteps);
    _lastHandSteps = steps;
    _handVX = (x - _handX) / steps;
    _handVY = (y - _handY) / steps;
    _handStepsLeft = steps;
    _stepsSinceDrag = 0;
    wake();
  }

  /// Lets go; the charm keeps the velocity the hand gave it, no more.
  void release() {
    _grabbed = false;
    wake();
  }

  /// Adds a velocity, in logical pixels per second, to the charm.
  void nudge(double vx, double vy) {
    final n = _px.length - 1;
    _ox[n] -= vx * dt;
    _oy[n] -= vy * dt;
    _userInput = true;
    wake();
  }

  /// Advances the simulation by [seconds] of wall time. Returns the number of
  /// fixed steps taken (0 while asleep).
  int step(double seconds) {
    if (_asleep) return 0;
    _accumulator += math.min(seconds, maxFrameSeconds);
    var steps = 0;
    // The epsilon keeps 4 x (1/240) from landing a hair under 1/60.
    while (_accumulator >= dt - 1e-9) {
      _substep();
      _accumulator -= dt;
      steps++;
      if (_asleep) {
        _accumulator = 0;
        break;
      }
    }
    return steps;
  }

  void _build(double angle) {
    final count = _style.segments + 1;
    _px = Float64List(count);
    _py = Float64List(count);
    _ox = Float64List(count);
    _oy = Float64List(count);
    _invMass = Float64List(count);
    final sx = math.sin(angle), sy = math.cos(angle);
    for (var i = 0; i < count; i++) {
      final d = i * _style.segmentLength;
      _px[i] = _ox[i] = _anchorX + sx * d;
      _py[i] = _oy[i] = _anchorY + sy * d;
      _invMass[i] = 1 / _style.segmentMass;
    }
    _invMass[0] = 0;
    _invMass[count - 1] = 1 / charmMass;
    _accumulator = 0;
    _measureEnergy();
    _energyCap = energy;
    _inputWasActive = false;
  }

  void _substep() {
    final n = _px.length - 1;
    final damping = _style.damping;
    final gravityStep = _style.gravity * dt * dt;
    final frictionStep = _style.friction * dt * dt;
    const maxStep = maxSpeed * dt;

    final anchorMoving = _glideAnchor();
    _px[0] = _ox[0] = _anchorX;
    _py[0] = _oy[0] = _anchorY;

    if (_grabbed) _moveHand();

    for (var i = 1; i <= n; i++) {
      if (i == n && _grabbed) {
        _ox[i] = _px[i];
        _oy[i] = _py[i];
        _px[i] = _handX;
        _py[i] = _handY;
        continue;
      }
      var vx = (_px[i] - _ox[i]) * damping;
      var vy = (_py[i] - _oy[i]) * damping;
      final speed = math.sqrt(vx * vx + vy * vy);
      if (speed > maxStep) {
        vx *= maxStep / speed;
        vy *= maxStep / speed;
      } else if (speed > 0) {
        final slowed = math.max(0.0, speed - frictionStep) / speed;
        vx *= slowed;
        vy *= slowed;
      }
      _ox[i] = _px[i];
      _oy[i] = _py[i];
      _px[i] += vx;
      _py[i] += vy + gravityStep;
    }

    _attachToAnchor();
    _solveConstraints();
    _attachToAnchor();
    _tightenRope();
    _limitEnergy(userInput: _grabbed || anchorMoving || _userInput);
    _userInput = false;
    _updateSleep();
  }

  void _moveHand() {
    _stepsSinceDrag++;
    if (_handStepsLeft <= 0) return;
    _handX += _handVX;
    _handY += _handVY;
    _handStepsLeft--;
  }

  /// Moves the anchor part of the way to its target. Returns whether it
  /// moved.
  bool _glideAnchor() {
    final dx = _anchorTargetX - _anchorX;
    final dy = _anchorTargetY - _anchorY;
    if (dx == 0 && dy == 0) return false;
    if (dx.abs() < 0.01 && dy.abs() < 0.01) {
      _anchorX = _anchorTargetX;
      _anchorY = _anchorTargetY;
    } else {
      _anchorX += dx * anchorFollow;
      _anchorY += dy * anchorFollow;
    }
    return true;
  }

  /// Pulls stretched segments back toward rest length, weighted by mass.
  void _solveConstraints() {
    final n = _px.length - 1;
    final rest = _style.segmentLength;
    for (var it = 0; it < _style.iterations; it++) {
      for (var i = 0; i < n; i++) {
        final j = i + 1;
        final dx = _px[j] - _px[i];
        final dy = _py[j] - _py[i];
        final d = math.sqrt(dx * dx + dy * dy);
        if (d <= rest) continue;
        final wA = _invMass[i];
        final wB = (j == n && _grabbed) ? 0.0 : _invMass[j];
        final w = wA + wB;
        if (w == 0) continue;
        final c = (d - rest) / (d * w);
        _px[i] += dx * c * wA;
        _py[i] += dy * c * wA;
        _px[j] -= dx * c * wB;
        _py[j] -= dy * c * wB;
      }
    }
  }

  /// Long-range attachment: particle i may be no further from the anchor than
  /// i rope segments. Projects straight back toward the anchor, which only
  /// removes outward speed, so it cannot add energy.
  void _attachToAnchor() {
    final rest = _style.segmentLength;
    final n = _px.length - 1;
    for (var i = 1; i <= n; i++) {
      final dx = _px[i] - _anchorX;
      final dy = _py[i] - _anchorY;
      final d = math.sqrt(dx * dx + dy * dy);
      final limit = i * rest;
      if (d <= limit) continue;
      final k = limit / d;
      _px[i] = _anchorX + dx * k;
      _py[i] = _anchorY + dy * k;
    }
  }

  /// Takes out any stretch left between the anchor and the charm by moving
  /// only the light rope particles, alternately from each end. The anchor and
  /// the charm stay where they are (the charm is already within reach), so
  /// this straightens the rope without pushing the charm and adding swing.
  void _tightenRope() {
    final rest = _style.segmentLength;
    final n = _px.length - 1;
    void pull(int i, int toward) {
      final dx = _px[i] - _px[toward];
      final dy = _py[i] - _py[toward];
      final d = math.sqrt(dx * dx + dy * dy);
      if (d <= rest) return;
      final k = rest / d;
      _px[i] = _px[toward] + dx * k;
      _py[i] = _py[toward] + dy * k;
    }

    for (var pass = 0; pass < 8; pass++) {
      for (var i = n - 1; i >= 1; i--) {
        pull(i, i + 1);
      }
      for (var i = 1; i < n; i++) {
        pull(i, i - 1);
      }
    }
    // Pulled to full reach the rope must be dead straight, which the passes
    // above only approach, leaving a sliver of stretch in the last link.
    // Only when that sliver is big enough to see, close it at the charm; any
    // energy that adds is taken straight back out by _limitEnergy.
    final dx = _px[n] - _px[n - 1];
    final dy = _py[n] - _py[n - 1];
    final slack = math.sqrt(dx * dx + dy * dy) - rest;
    if (slack > restLength * 0.015) pull(n, n - 1);
  }

  /// Kinetic and gravitational energy of every particle but the anchor, with
  /// the anchor's height as zero.
  void _measureEnergy() {
    var kinetic = 0.0, potential = 0.0;
    final g = _style.gravity;
    for (var i = 1; i < _px.length; i++) {
      final m = 1 / _invMass[i];
      final vx = (_px[i] - _ox[i]) / dt;
      final vy = (_py[i] - _oy[i]) / dt;
      kinetic += 0.5 * m * (vx * vx + vy * vy);
      potential -= m * g * (_py[i] - _anchorY);
    }
    _kinetic = kinetic;
    _potential = potential;
  }

  /// While the user is adding motion, anything goes. The moment they stop,
  /// the rope keeps the energy they gave it, but no more than it takes to
  /// lift the charm level with the anchor. From then on the energy may only
  /// fall: any rise from numerical error is taken back out of the speed.
  void _limitEnergy({required bool userInput}) {
    _measureEnergy();
    if (userInput) {
      _inputWasActive = true;
      return;
    }
    if (_inputWasActive) {
      _inputWasActive = false;
      _energyCap = math.min(energy, math.max(_potential, 0));
    }
    final excess = energy - _energyCap;
    if (excess > 0) {
      final kept = math.max(0.0, _kinetic - excess);
      final scale = _kinetic > 0 ? math.sqrt(kept / _kinetic) : 0.0;
      for (var i = 1; i < _px.length; i++) {
        _ox[i] = _px[i] - (_px[i] - _ox[i]) * scale;
        _oy[i] = _py[i] - (_py[i] - _oy[i]) * scale;
      }
      _measureEnergy();
    }
    _energyCap = math.min(_energyCap, energy);
  }

  void _updateSleep() {
    if (_grabbed || anchorMoving) {
      _stillSteps = 0;
      return;
    }
    var maxMoveSq = 0.0;
    for (var i = 1; i < _px.length; i++) {
      final dx = _px[i] - _ox[i];
      final dy = _py[i] - _oy[i];
      final m = dx * dx + dy * dy;
      if (m > maxMoveSq) maxMoveSq = m;
    }
    if (maxMoveSq < sleepThreshold * sleepThreshold) {
      _stillSteps++;
      if (_stillSteps >= sleepAfterSeconds * stepsPerSecond) {
        _asleep = true;
        // Settle exactly so waking does not start with leftover drift.
        for (var i = 0; i < _px.length; i++) {
          _ox[i] = _px[i];
          _oy[i] = _py[i];
        }
        _measureEnergy();
        _energyCap = energy;
      }
    } else {
      _stillSteps = 0;
    }
  }

  double _dist(int a, int b) {
    final dx = _px[b] - _px[a];
    final dy = _py[b] - _py[a];
    return math.sqrt(dx * dx + dy * dy);
  }
}
