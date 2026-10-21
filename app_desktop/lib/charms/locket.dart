import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'photo_charm.dart';
import 'shapes.dart';
import 'text_charm.dart';

/// A locket: a photo charm with a cover. Closed, it is a plain engraved
/// piece of metal; tap it and it turns over to show the photo inside. The
/// inside is the photo charm's own drawing, so the two are always the same
/// size and shape.
class LocketDesign {
  const LocketDesign({
    this.photo = const PhotoCharmDesign(),
    this.engraving = '',
  });

  /// Letters that fit on a cover.
  static const int maxEngraving = 3;

  /// The inside: the photo, its frame, finish, zoom and place.
  final PhotoCharmDesign photo;

  /// A monogram or short word cut into the cover. Empty gets a small
  /// sparkle instead.
  final String engraving;

  LocketDesign copyWith({PhotoCharmDesign? photo, String? engraving}) =>
      LocketDesign(
          photo: photo ?? this.photo, engraving: engraving ?? this.engraving);

  String get engravingText {
    final chars = engraving.trim().characters;
    return chars.length <= maxEngraving
        ? engraving.trim()
        : chars.take(maxEngraving).toString();
  }

  Size get artBox => photo.artBox;

  /// Draws the closed cover into [size] (any size with the art box's
  /// proportions).
  void paintCover(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / artBox.width, size.height / artBox.height);
    final finish = photo.finish;
    final frame = photo.frameRect;
    final metal = metalPaint(finish, Offset.zero & artBox);
    paintBail(canvas, artBox.width, metal);

    final body = photo.outline(frame);
    canvas.drawPath(body, metal);
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = finish.dark);

    // A fine line cut just inside the edge: a dark groove with a light
    // edge a little below it.
    final groove = photo.outline(frame.deflate(5));
    canvas.drawPath(
        groove.shift(const Offset(0.6, 0.6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = finish.light.withValues(alpha: 0.9));
    canvas.drawPath(
        groove,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = finish.dark.withValues(alpha: 0.75));

    _paintEngraving(canvas, frame);
    _paintHinge(canvas, frame, metal);
    canvas.restore();
  }

  void _paintEngraving(Canvas canvas, Rect frame) {
    final finish = photo.finish;
    final centre = frame.center;
    final text = engravingText;
    if (text.isEmpty) {
      // A four-pointed sparkle.
      final r = frame.shortestSide * 0.2;
      final path = Path()
        ..moveTo(centre.dx, centre.dy - r)
        ..quadraticBezierTo(centre.dx, centre.dy, centre.dx + r, centre.dy)
        ..quadraticBezierTo(centre.dx, centre.dy, centre.dx, centre.dy + r)
        ..quadraticBezierTo(centre.dx, centre.dy, centre.dx - r, centre.dy)
        ..quadraticBezierTo(centre.dx, centre.dy, centre.dx, centre.dy - r)
        ..close();
      canvas.drawPath(path.shift(const Offset(0.6, 0.6)),
          Paint()..color = finish.light.withValues(alpha: 0.9));
      canvas.drawPath(path, Paint()..color = finish.dark);
      return;
    }
    final area = Rect.fromCenter(
        center: centre,
        width: frame.width * 0.56,
        height: frame.height * 0.34);
    final families = NameCharmDesign(text: text).fontFamilies;
    TextPainter make(double size, Color color) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: families.first,
              fontFamilyFallback: families.skip(1).toList(),
              fontSize: size,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
    final probe = make(100, finish.dark);
    final fit = math.min(area.width / probe.width, area.height / probe.height);
    probe.dispose();
    final size = 100 * fit;
    final light = make(size, finish.light.withValues(alpha: 0.9));
    final dark = make(size, finish.dark);
    final origin = centre - Offset(dark.width / 2, dark.height / 2);
    light.paint(canvas, origin.translate(0.6, 0.6));
    dark.paint(canvas, origin);
    light.dispose();
    dark.dispose();
  }

  /// A hinge pin on the left edge and a clasp on the right, so it reads as
  /// something that opens.
  void _paintHinge(Canvas canvas, Rect frame, Paint metal) {
    final finish = photo.finish;
    final heart = photo.shape == FrameShape.heart;
    final y = heart ? frame.top + frame.height * 0.36 : frame.center.dy;
    for (final (x, clasp) in [
      (frame.left + (heart ? frame.width * 0.03 : 0), false),
      (frame.right - (heart ? frame.width * 0.03 : 0), true),
    ]) {
      final centre = Offset(x + (clasp ? -1.5 : 1.5), y);
      canvas.drawCircle(centre, clasp ? 3 : 2.2, metal);
      canvas.drawCircle(
          centre,
          clasp ? 3 : 2.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = finish.dark);
    }
  }

  /// The closed cover as a PNG, [width] pixels wide.
  Future<Uint8List> renderCoverPng({int width = 256}) async {
    final height = (width * artBox.height / artBox.width).round();
    final recorder = ui.PictureRecorder();
    paintCover(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
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
