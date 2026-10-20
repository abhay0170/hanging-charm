import 'package:flutter/painting.dart';

import 'photo_charm.dart' show FrameFinish;

/// Height of the bail (the small loop on top that the ring goes through),
/// in art-box units.
const double bailHeight = 14;

/// A heart filling [r], point down.
Path heartPath(Rect r) {
  Offset p(double x, double y) =>
      Offset(r.left + r.width * x / 100, r.top + r.height * y / 100);
  final a = p(50, 96);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(p(20, 74).dx, p(20, 74).dy, p(2, 54).dx, p(2, 54).dy,
        p(2, 32).dx, p(2, 32).dy)
    ..cubicTo(p(2, 14).dx, p(2, 14).dy, p(14, 2).dx, p(14, 2).dy,
        p(28, 2).dx, p(28, 2).dy)
    ..cubicTo(p(38, 2).dx, p(38, 2).dy, p(46, 8).dx, p(46, 8).dy,
        p(50, 18).dx, p(50, 18).dy)
    ..cubicTo(p(54, 8).dx, p(54, 8).dy, p(62, 2).dx, p(62, 2).dy,
        p(72, 2).dx, p(72, 2).dy)
    ..cubicTo(p(86, 2).dx, p(86, 2).dy, p(98, 14).dx, p(98, 14).dy,
        p(98, 32).dx, p(98, 32).dy)
    ..cubicTo(p(98, 54).dx, p(98, 54).dy, p(80, 74).dx, p(80, 74).dy,
        a.dx, a.dy)
    ..close();
}

/// A metal gradient in [finish] across [bounds], light at the top left.
Paint metalPaint(FrameFinish finish, Rect bounds) => Paint()
  ..shader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [finish.light, finish.middle, finish.dark],
    stops: const [0, 0.5, 1],
  ).createShader(bounds);

/// The bail at the top centre of an art box [width] wide, in [metal].
void paintBail(Canvas canvas, double width, Paint metal) {
  canvas.drawCircle(
      Offset(width / 2, bailHeight / 2 + 1),
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = metal.shader);
  canvas.drawRect(
      Rect.fromCenter(
          center: Offset(width / 2, bailHeight + 1), width: 5, height: 6),
      metal);
}
