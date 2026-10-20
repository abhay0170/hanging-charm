import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'shapes.dart';

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
  static const double _bail = bailHeight;
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
        FrameShape.heart => heartPath(r),
      };

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
    final metal = metalPaint(finish, Offset.zero & artBox);
    paintBail(canvas, artBox.width, metal);

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
