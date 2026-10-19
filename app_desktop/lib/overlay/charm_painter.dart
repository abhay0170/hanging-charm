import 'dart:math' as math;

import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Size of the placeholder charm and the jump ring it hangs from.
const double charmRadius = 22;
const double ringRadius = 4;

/// Centre of the charm body, which hangs below the rope's last particle.
Offset charmCenter(RopeSim sim) {
  final a = sim.charmAngle;
  const d = charmRadius + ringRadius * 2;
  return Offset(sim.charmX + math.sin(a) * d, sim.charmY + math.cos(a) * d);
}

/// Draws the anchor pin, the rope in its style, and a gold bead charm.
class CharmPainter extends CustomPainter {
  CharmPainter(this.sim, {required Listenable super.repaint});

  final RopeSim sim;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      for (var i = 0; i < sim.particleCount; i++) Offset(sim.x(i), sim.y(i)),
    ];
    switch (sim.style.id) {
      case 'gold_chain':
        _paintChain(canvas, points);
      case 'neon':
        _paintNeon(canvas, points);
      default:
        _paintThread(canvas, points);
    }
    _paintAnchor(canvas, points.first);
    _paintCharm(canvas);
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
        canvas.drawLine(
            Offset(-length / 2, 0), Offset(length / 2, 0), edge);
      }
      canvas.restore();
    }
  }

  void _paintNeon(Canvas canvas, List<Offset> p) {
    final path = _smoothPath(p);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x99FF4FB8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
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

  void _paintCharm(Canvas canvas) {
    final end = Offset(sim.charmX, sim.charmY);
    final angle = sim.charmAngle;
    final center = charmCenter(sim);

    // Jump ring between the rope and the charm.
    final ringCenter = Offset(end.dx + math.sin(angle) * ringRadius,
        end.dy + math.cos(angle) * ringRadius);
    canvas.drawCircle(
      ringCenter,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFC8962E),
    );

    // Soft shadow so the charm reads on light and dark wallpapers.
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
      Rect.fromCenter(
          center: center.translate(-7, -9), width: 12, height: 7),
      Paint()..color = const Color(0xCCFFFFFF),
    );
  }

  @override
  bool shouldRepaint(CharmPainter oldDelegate) => oldDelegate.sim != sim;
}
