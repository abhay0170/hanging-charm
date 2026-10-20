import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Size of the placeholder charm and the jump ring it hangs from.
const double charmRadius = 22;
const double ringRadius = 4;

/// Centre of the charm body. The rope's last particle is the charm itself,
/// so the bead you see swings exactly as far as the physics allows; hanging
/// it below the rope's end would act as a longer lever and swing further.
Offset charmCenter(RopeSim sim) => Offset(sim.charmX, sim.charmY);

/// Distance from the charm's centre up to where the rope meets the ring.
const double _ropeCut = charmRadius + ringRadius * 2;

/// Unit vector from the charm's centre up toward where the rope enters it.
Offset _upFromCharm(RopeSim sim) {
  final a = sim.charmAngle;
  return Offset(-math.sin(a), -math.cos(a));
}

/// The bead (shadow, gradient body, rim, highlight) drawn once into an image
/// at the screen's pixel density. Its light comes from a fixed direction, so
/// it never needs redrawing while it swings: each frame only places it.
class CharmSprite {
  CharmSprite(this.devicePixelRatio) : image = _render(devicePixelRatio);

  /// Room around the bead for its blurred shadow.
  static const double _pad = 12;
  static const double extent = (charmRadius + _pad) * 2;

  final double devicePixelRatio;
  final ui.Image image;

  static ui.Image _render(double dpr) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    const center = Offset(extent / 2, extent / 2);

    // Soft shadow so the charm reads on light and dark backgrounds.
    canvas.drawCircle(
      center.translate(0, 3),
      charmRadius,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    final body = Rect.fromCircle(center: center, radius: charmRadius);
    canvas.drawCircle(
      center,
      charmRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [Color(0xFFFFF3C4), Color(0xFFE0A93B), Color(0xFF7A4E0E)],
          stops: [0, 0.45, 1],
        ).createShader(body),
    );
    canvas.drawCircle(
      center,
      charmRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF6B430B),
    );
    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(-7, -9), width: 12, height: 7),
      Paint()..color = const Color(0xCCFFFFFF),
    );

    final size = (extent * dpr).ceil();
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size, size);
    picture.dispose();
    return image;
  }

  void dispose() => image.dispose();
}

/// Draws the anchor pin, the rope in its style, and the charm.
class CharmPainter extends CustomPainter {
  CharmPainter(this.sim, this.sprite, {required Listenable super.repaint});

  final RopeSim sim;
  final CharmSprite sprite;

  @override
  void paint(Canvas canvas, Size size) {
    // The rope ends at the jump ring on top of the charm; the particles
    // inside the charm are not drawn.
    final center = charmCenter(sim);
    final ringTop = center + _upFromCharm(sim) * _ropeCut;
    final points = <Offset>[];
    for (var i = 0; i < sim.particleCount - 1; i++) {
      final p = Offset(sim.x(i), sim.y(i));
      if (i > 0 && (p - center).distance < _ropeCut) break;
      points.add(p);
    }
    points.add(ringTop);

    switch (sim.style.id) {
      case 'gold_chain':
        _paintChain(canvas, points);
      case 'neon':
        _paintNeon(canvas, points);
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

  void _paintChain(Canvas canvas, List<Offset> p) {
    final face = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFFD9A93E);
    final edge = Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB0832A);
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
            face);
      } else {
        canvas.drawLine(Offset(-length / 2, 0), Offset(length / 2, 0), edge);
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
    // Jump ring between the rope and the charm.
    final ringCenter =
        center + _upFromCharm(sim) * (charmRadius + ringRadius);
    canvas.drawCircle(
      ringCenter,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFC8962E),
    );

    final image = sprite.image;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
          center: center,
          width: CharmSprite.extent,
          height: CharmSprite.extent),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(CharmPainter oldDelegate) =>
      oldDelegate.sim != sim || oldDelegate.sprite != sprite;
}
