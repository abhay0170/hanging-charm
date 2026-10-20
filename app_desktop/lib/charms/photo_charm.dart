import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The frame a photo sits in.
enum FrameShape {
  circle('Circle'),
  roundedSquare('Rounded square'),
  heart('Heart'),
  oval('Oval');

  const FrameShape(this.label);
  final String label;
}

/// The metal (or enamel) of the frame, as light, middle and dark tones.
enum FrameFinish {
  gold('Gold', Color(0xFFFFF1B8), Color(0xFFD9A33A), Color(0xFF7A4E0E)),
  silver('Silver', Color(0xFFFFFFFF), Color(0xFFB3BCC6), Color(0xFF59626B)),
  roseGold('Rose gold', Color(0xFFFFE1D6), Color(0xFFD99A86), Color(0xFF8A4B3B)),
  black('Black', Color(0xFF6B6B73), Color(0xFF2A2A30), Color(0xFF0A0A0D));

  const FrameFinish(this.label, this.light, this.middle, this.dark);
  final String label;
  final Color light, middle, dark;
}

/// How a photo is made into a charm: its frame, finish, and how it is
/// zoomed and placed inside. The same drawing makes the editor's preview and
/// the saved artwork, so what you see is what hangs.
class PhotoCharmDesign {
  const PhotoCharmDesign({
    this.shape = FrameShape.circle,
    this.finish = FrameFinish.gold,
    this.zoom = 1,
    this.offset = Offset.zero,
  });

  static const double minZoom = 1, maxZoom = 4;

  final FrameShape shape;
  final FrameFinish finish;

  /// 1 = the photo just covers the frame; more zooms in.
  final double zoom;

  /// Where the photo sits, from -1 to 1 on each axis: the furthest it can
  /// move each way while still covering the frame.
  final Offset offset;

  PhotoCharmDesign copyWith({
    FrameShape? shape,
    FrameFinish? finish,
    double? zoom,
    Offset? offset,
  }) {
    return PhotoCharmDesign(
      shape: shape ?? this.shape,
      finish: finish ?? this.finish,
      zoom: (zoom ?? this.zoom).clamp(minZoom, maxZoom),
      offset: Offset((offset ?? this.offset).dx.clamp(-1.0, 1.0),
          (offset ?? this.offset).dy.clamp(-1.0, 1.0)),
    );
  }

  // The artwork is laid out in a box 100 wide: a bail (the small loop the
  // ring goes through) on top, then the frame.
  static const double _bail = 14;
  static const double _margin = 4;
  static const double _rim = 6;

  /// The artwork's proportions (width 100).
  Size get artBox => switch (shape) {
        FrameShape.oval => const Size(84, _bail + 116 + _margin),
        _ => const Size(100, _bail + 92 + _margin),
      };

  /// Width on screen when hung, in logical pixels; height follows.
  double get charmSize => shape == FrameShape.oval ? 42 : 48;

  /// The ring goes through the top of the bail.
  Offset get hang => const Offset(0.5, 0);

  Rect get _frameRect => Rect.fromLTRB(
      _margin, _bail, artBox.width - _margin, artBox.height - _margin);

  /// The area inside the rim that shows the photo, in art-box units.
  Rect get photoArea => _frameRect.deflate(_rim);

  Path _framePath(Rect r) => switch (shape) {
        FrameShape.circle || FrameShape.oval => Path()..addOval(r),
        FrameShape.roundedSquare => Path()
          ..addRRect(RRect.fromRectAndRadius(
              r, Radius.circular(r.shortestSide * 0.2))),
        FrameShape.heart => _heart(r),
      };

  static Path _heart(Rect r) {
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

  /// Where the photo is drawn so it covers [frame] at this zoom and offset.
  Rect photoRect(Size photo, Rect frame) {
    final scale =
        math.max(frame.width / photo.width, frame.height / photo.height) *
            zoom;
    final w = photo.width * scale, h = photo.height * scale;
    // Spare photo beyond the frame on each axis; the offset moves within it.
    final spareX = (w - frame.width) / 2, spareY = (h - frame.height) / 2;
    final center = frame.center.translate(-offset.dx * spareX, -offset.dy * spareY);
    return Rect.fromCenter(center: center, width: w, height: h);
  }

  /// Draws the charm into [size] (any size with the art box's proportions).
  void paint(Canvas canvas, Size size, ui.Image photo) {
    canvas.save();
    canvas.scale(size.width / artBox.width, size.height / artBox.height);
    final frame = _frameRect;
    final outline = _framePath(frame);
    final metal = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [finish.light, finish.middle, finish.dark],
        stops: const [0, 0.5, 1],
      ).createShader(Offset.zero & artBox);

    // Bail: a small loop above the frame.
    final bailCenter = Offset(artBox.width / 2, _bail / 2 + 1);
    canvas.drawCircle(
        bailCenter,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..shader = metal.shader);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(artBox.width / 2, _bail + 1), width: 5, height: 6),
        metal);

    // The rim, then the photo inside it.
    canvas.drawPath(outline, metal);
    final inner = _framePath(frame.deflate(_rim));
    canvas.save();
    canvas.clipPath(inner);
    final photoSize =
        Size(photo.width.toDouble(), photo.height.toDouble());
    canvas.drawImageRect(
      photo,
      Offset.zero & photoSize,
      photoRect(photoSize, frame.deflate(_rim)),
      Paint()..filterQuality = FilterQuality.high,
    );
    // A soft glass shine across the top left.
    canvas.drawOval(
      Rect.fromLTWH(frame.left + frame.width * 0.12,
          frame.top + frame.height * 0.08, frame.width * 0.45,
          frame.height * 0.28),
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.restore();
    canvas.drawPath(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = finish.dark.withValues(alpha: 0.7));
    canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = finish.dark);
    canvas.restore();
  }

  /// The finished artwork as a PNG, [width] pixels wide.
  Future<Uint8List> renderPng(ui.Image photo, {int width = 256}) async {
    final height = (width * artBox.height / artBox.width).round();
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()), photo);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
