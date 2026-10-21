import 'package:charm_desktop/overlay/wiggle_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds a cursor going to each x in [stops] in turn, a step every 30 ms
/// (as the app's cursor timer does), [px] pixels at a time. Returns the
/// strengths reported and when.
List<(Duration, double)> run(WiggleDetector d, List<double> stops,
    {double px = 30, Duration start = Duration.zero}) {
  final found = <(Duration, double)>[];
  var t = start;
  var x = stops.first;
  void feed() {
    final r = d.add(t, x);
    if (r != null) found.add((t, r));
    t += const Duration(milliseconds: 30);
  }

  feed();
  for (final stop in stops.skip(1)) {
    while ((stop - x).abs() > 1e-9) {
      final step = (stop - x).abs() < px ? (stop - x).abs() : px;
      x += stop > x ? step : -step;
      feed();
    }
  }
  return found;
}

void main() {
  test('shaking the mouse side to side is noticed once', () {
    final found = run(WiggleDetector(), [500, 700, 500, 700, 500, 700, 500]);
    expect(found, hasLength(1));
    expect(found.single.$2, inInclusiveRange(0.3, 1.0));
  });

  test('a harder shake is stronger', () {
    final gentle =
        run(WiggleDetector(), [500, 640, 500, 640, 500, 640], px: 20);
    final hard = run(WiggleDetector(),
        [300, 900, 300, 900, 300, 900, 300],
        px: 90);
    expect(gentle, hasLength(1));
    expect(hard, hasLength(1));
    expect(hard.single.$2, greaterThan(gentle.single.$2));
  });

  test('one fast sweep across the screen is not a wiggle', () {
    expect(run(WiggleDetector(), [0, 2000], px: 90), isEmpty);
    expect(run(WiggleDetector(), [0, 1500, 0], px: 90), isEmpty);
  });

  test('a slow back and forth is not a wiggle', () {
    expect(
        run(WiggleDetector(), [500, 700, 500, 700, 500, 700, 500], px: 3),
        isEmpty);
  });

  test('small tremor is ignored', () {
    expect(
        run(WiggleDetector(), [500, 520, 500, 520, 500, 520, 500, 520, 500],
            px: 8),
        isEmpty);
  });

  test('it waits before noticing the next one', () {
    final d = WiggleDetector();
    final first = run(d, [500, 700, 500, 700, 500, 700, 500]);
    expect(first, hasLength(1));
    // Straight away: still in the cooldown.
    final soon = run(d, [500, 700, 500, 700, 500, 700, 500],
        start: first.single.$1 + const Duration(milliseconds: 60));
    expect(soon, isEmpty);
    // Well after it.
    final later = run(WiggleDetector(), [500, 700, 500, 700, 500, 700, 500],
        start: first.single.$1 + const Duration(seconds: 5));
    expect(later, hasLength(1));
  });

  test('strokes spread out over too long do not add up', () {
    final d = WiggleDetector();
    var t = Duration.zero;
    var hits = 0;
    // A stroke every 2 seconds: each is a real turn, but never four within
    // the window.
    for (var i = 0; i < 12; i++) {
      for (final x in [500.0, 700.0]) {
        if (d.add(t, x) != null) hits++;
        t += const Duration(seconds: 1);
      }
    }
    expect(hits, 0);
  });
}
