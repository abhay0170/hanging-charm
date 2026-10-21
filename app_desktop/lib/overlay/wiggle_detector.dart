import 'dart:collection';

/// Notices when the mouse is shaken side to side: several quick strokes in
/// a row, not just a fast move across the screen.
///
/// Fed the cursor's horizontal position as it moves. Only positions are
/// looked at, never anything typed or clicked, and nothing is kept beyond
/// the last second.
class WiggleDetector {
  WiggleDetector({
    this.minStroke = 40,
    this.minStrokes = 4,
    this.window = const Duration(milliseconds: 800),
    this.minSpeed = 450,
    this.cooldown = const Duration(milliseconds: 1500),
  });

  /// How far the cursor must travel one way before turning back counts as
  /// a stroke, in logical pixels. Smaller hand tremor is ignored.
  final double minStroke;

  /// Strokes (alternating directions) needed within [window].
  final int minStrokes;

  final Duration window;

  /// Average speed over the window, in logical pixels per second.
  final double minSpeed;

  /// After a wiggle is found, wait this long before looking for another.
  final Duration cooldown;

  final _samples = Queue<(Duration, double)>();
  final _strokeEnds = Queue<Duration>();

  double? _extreme;
  int _direction = 0;
  Duration _quietUntil = Duration.zero;

  /// Feeds the cursor at [x] at [time]. Returns how strong the wiggle is,
  /// 0.3 to 1, when this movement completes one; otherwise null.
  double? add(Duration time, double x) {
    if (time < _quietUntil) return null;

    _samples.addLast((time, x));
    while (_samples.isNotEmpty && time - _samples.first.$1 > window) {
      _samples.removeFirst();
    }
    while (_strokeEnds.isNotEmpty && time - _strokeEnds.first > window) {
      _strokeEnds.removeFirst();
    }

    final extreme = _extreme;
    if (extreme == null) {
      _extreme = x;
      return null;
    }
    // Follow the cursor further in the direction it is going; when it turns
    // back by a whole stroke, the stroke is over.
    if (_direction >= 0 && x > extreme) {
      _extreme = x;
      _direction = 1;
    } else if (_direction <= 0 && x < extreme) {
      _extreme = x;
      _direction = -1;
    } else if ((x - extreme).abs() >= minStroke && _direction != 0) {
      _strokeEnds.addLast(time);
      _extreme = x;
      _direction = -_direction;
    } else if (_direction == 0 && (x - extreme).abs() >= minStroke) {
      _direction = x > extreme ? 1 : -1;
      _extreme = x;
    }

    // Strokes are counted at their ends, so n turns make n + 1 strokes.
    if (_strokeEnds.length + 1 < minStrokes) return null;
    var travel = 0.0;
    double? previous;
    for (final (_, sx) in _samples) {
      if (previous != null) travel += (sx - previous).abs();
      previous = sx;
    }
    final seconds = (_samples.last.$1 - _samples.first.$1).inMicroseconds / 1e6;
    if (seconds <= 0) return null;
    final speed = travel / seconds;
    if (speed < minSpeed) return null;

    _reset(time);
    return (0.3 + (speed - minSpeed) / 1500).clamp(0.3, 1.0).toDouble();
  }

  void _reset(Duration time) {
    _samples.clear();
    _strokeEnds.clear();
    _extreme = null;
    _direction = 0;
    _quietUntil = time + cooldown;
  }
}
