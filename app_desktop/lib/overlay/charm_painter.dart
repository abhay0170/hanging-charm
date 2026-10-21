import 'dart:math' as math;

import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../charms/charm_sprite.dart';

/// The jump ring between rope and charm.
const double ringRadius = 4;

/// Centre of the charm. The rope's last particle is the charm itself, so
/// the charm you see swings exactly as far as the physics allows; hanging it
/// below the rope's end would act as a longer lever and swing further.
Offset charmCenter(RopeSim sim) => Offset(sim.charmX, sim.charmY);

/// Unit vector from the charm's centre up toward where the rope enters it.
Offset _upFromCharm(RopeSim sim) {
  final a = sim.charmAngle;
  return Offset(-math.sin(a), -math.cos(a));
}

/// Draws the anchor pin, the rope in its style, and the charm.
class CharmPainter extends CustomPainter {
  CharmPainter(this.sim, this.sprite,
      {required Listenable super.repaint, this.animate = true});

  final RopeSim sim;
  final CharmSprite sprite;

  /// Whether an animated charm shows its moving frames or just its first.
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    // The rope ends at the jump ring just above the charm's hang point; the
    // particles closer to the charm's centre than that are not drawn.
    final center = charmCenter(sim);
    final ropeCut = sprite.hangOffset.distance + ringRadius * 2;
    final ringTop = center + _upFromCharm(sim) * ropeCut;
    final points = <Offset>[];
    for (var i = 0; i < sim.particleCount - 1; i++) {
      final p = Offset(sim.x(i), sim.y(i));
      if (i > 0 && (p - center).distance < ropeCut) break;
      points.add(p);
    }
    points.add(ringTop);

    switch (sim.style.id) {
      case 'leather':
        _paintBraid(canvas, points,
            base: const Color(0xFF5E3A1F),
            light: const Color(0xFF9A6B3F),
            stitch: const Color(0xFF3A2312),
            width: 3.6);
      case 'gold_chain':
        _paintChain(canvas, points,
            face: const Color(0xFFD9A93E), edge: const Color(0xFFB0832A));
      case 'silver_chain':
        _paintChain(canvas, points,
            face: const Color(0xFFC9D0D8), edge: const Color(0xFF8E979F));
      case 'neon':
        _paintNeon(canvas, points);
      case 'spider_thread':
        _paintSilk(canvas, points);
      case 'midnight_cord':
        _paintBraid(canvas, points,
            base: const Color(0xFF1C2032),
            light: const Color(0xFF4A5372),
            stitch: const Color(0xFF0E101A),
            width: 3.2);
      case 'temple_thread':
        _paintTempleThread(canvas, points);
      case 'silver_cord':
        _paintBraid(canvas, points,
            base: const Color(0xFF8C959F),
            light: const Color(0xFFE4E9EE),
            stitch: const Color(0xFF5F6872),
            width: 3.0);
      default:
        _paintThread(canvas, points);
    }
    _paintAnchor(canvas, points.first);
    _paintCharm(canvas, center);
  }

  Path _smoothPath(List<Offset> p) {
    final path = Path()..moveTo(p[0].dx, p[0].dy);
    for (var i = 1; i < p.length - 1; i++) {
      final mid = (p[i] + p[i + 1]) / 2;
      path.quadraticBezierTo(p[i].dx, p[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(p.last.dx, p.last.dy);
    return path;
  }

  void _paintThread(Canvas canvas, List<Offset> p) {
    final path = _smoothPath(p);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF9C7322),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFF3D98B),
    );
  }

  /// A woven or braided cord: a body stroke, a lighter top strand, and
  /// short diagonal stitches along it so it reads as braided, not smooth.
  void _paintBraid(Canvas canvas, List<Offset> p,
      {required Color base,
      required Color light,
      required Color stitch,
      required double width}) {
    final path = _smoothPath(p);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = base,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.3
        ..color = light,
    );
    final stitches = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = stitch;
    final half = width / 2;
    for (var i = 1; i < p.length - 1; i++) {
      final along = p[i + 1] - p[i - 1];
      final length = along.distance;
      if (length == 0) continue;
      final d = along / length;
      final n = Offset(-d.dy, d.dx);
      canvas.drawLine(p[i] - n * half - d * (half * 0.8),
          p[i] + n * half + d * (half * 0.8), stitches);
    }
  }

  /// Spun silk: barely there, with a faint sheen around a fine line.
  void _paintSilk(Canvas canvas, List<Offset> p) {
    final path = _smoothPath(p);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x26F2F6FA),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xE6EEF2F6),
    );
  }

  /// Saffron cotton twisted with vermilion: the colours alternate segment by
  /// segment, which reads as a two-ply twist.
  void _paintTempleThread(Canvas canvas, List<Offset> p) {
    canvas.drawPath(
      _smoothPath(p),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF2A007),
    );
    final vermilion = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFD7381C);
    for (var i = 0; i < p.length - 1; i += 2) {
      final a = p[i], b = p[i + 1];
      // A short stretch in the middle of every other segment.
      canvas.drawLine(Offset.lerp(a, b, 0.2)!, Offset.lerp(a, b, 0.8)!,
          vermilion);
    }
  }

  void _paintChain(Canvas canvas, List<Offset> p,
      {required Color face, required Color edge}) {
    final facePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = face;
    final edgePaint = Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = edge;
    for (var i = 0; i < p.length - 1; i++) {
      final a = p[i], b = p[i + 1];
      final mid = (a + b) / 2;
      final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
      final length = (b - a).distance * 1.35;
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(angle);
      if (i.isEven) {
        canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: length, height: 6),
            facePaint);
      } else {
        canvas.drawLine(
            Offset(-length / 2, 0), Offset(length / 2, 0), edgePaint);
      }
      canvas.restore();
    }
  }

  /// A glow built from wide, faint strokes under a bright core. Looks like
  /// a blur but costs a fraction of one, every frame.
  void _paintNeon(Canvas canvas, List<Offset> p) {
    final path = _smoothPath(p);
    for (final (width, alpha) in const [(9.0, 0x22), (6.0, 0x44), (3.5, 0x88)]) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = Color.fromARGB(alpha, 0xFF, 0x4F, 0xB8),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFE3F4),
    );
  }

  void _paintAnchor(Canvas canvas, Offset a) {
    final pin = RRect.fromRectAndRadius(
        Rect.fromCenter(center: a.translate(0, 3), width: 16, height: 8),
        const Radius.circular(3));
    canvas.drawRRect(pin, Paint()..color = const Color(0xFF2B2B30));
    canvas.drawRRect(
        pin.deflate(1.5), Paint()..color = const Color(0xFF55555E));
  }

  void _paintCharm(Canvas canvas, Offset center) {
    final up = _upFromCharm(sim);
    final hang = sprite.hangOffset;

    // Jump ring just above the hang point. Drawn first, so a charm hung
    // through a hole (the coin) shows its ring through the hole.
    canvas.drawCircle(
      center + up * (hang.distance + ringRadius),
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFC8962E),
    );

    // Turn the artwork so its hang point lies straight up the rope from its
    // centre, the way a real charm settles under its own weight.
    final turn = up.direction - hang.direction;
    final image =
        animate ? sprite.imageAt(CharmSprite.clock.elapsed) : sprite.image;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(turn);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
          center: Offset.zero,
          width: sprite.extent.width,
          height: sprite.extent.height),
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CharmPainter oldDelegate) =>
      oldDelegate.sim != sim ||
      oldDelegate.sprite != sprite ||
      oldDelegate.animate != animate;
}
