import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'photo_charm.dart' show FrameFinish;
import 'shapes.dart';

/// What the name hangs as.
enum NameShape {
  letters('Letters'),
  roundTag('Round tag'),
  barTag('Bar tag'),
  heartTag('Heart tag');

  const NameShape(this.label);
  final String label;
}

/// The lettering style.
enum NameFont {
  classic('Classic'),
  modern('Modern'),
  script('Script');

  const NameFont(this.label);
  final String label;
}

/// Writing systems the name charm knows how to set.
enum NameScript { latin, devanagari, tamil, other }

/// A name or short word made into a charm: letters on a nameplate bar, or
/// stamped into a tag. The same drawing makes the editor's preview and the
/// saved artwork.
class NameCharmDesign {
  const NameCharmDesign({
    this.text = '',
    this.shape = NameShape.letters,
    this.finish = FrameFinish.gold,
    this.font = NameFont.classic,
  });

  /// Long enough for a name, short enough to read at charm size.
  static const int maxLength = 14;

  final String text;
  final NameShape shape;
  final FrameFinish finish;
  final NameFont font;

  NameCharmDesign copyWith({
    String? text,
    NameShape? shape,
    FrameFinish? finish,
    NameFont? font,
  }) {
    return NameCharmDesign(
      text: text ?? this.text,
      shape: shape ?? this.shape,
      finish: finish ?? this.finish,
      font: font ?? this.font,
    );
  }

  /// What is drawn: the text trimmed and cut to [maxLength] characters.
  String get displayText {
    final trimmed = text.trim();
    final chars = trimmed.characters;
    return chars.length <= maxLength ? trimmed : chars.take(maxLength).toString();
  }

  /// The script of the first letter that belongs to one we know.
  static NameScript scriptOf(String text) {
    for (final rune in text.runes) {
      if (rune >= 0x0B80 && rune <= 0x0BFF) return NameScript.tamil;
      if (rune >= 0x0900 && rune <= 0x097F) return NameScript.devanagari;
      if ((rune >= 0x41 && rune <= 0x5A) ||
          (rune >= 0x61 && rune <= 0x7A) ||
          (rune >= 0xC0 && rune <= 0x24F)) {
        return NameScript.latin;
      }
    }
    return NameScript.other;
  }

  /// Font families to try, in order. Hindi and Tamil need a font that
  /// shapes them properly; Windows' Nirmala UI does, so it leads for those
  /// and is the fallback for everything else.
  List<String> get fontFamilies {
    const indic = ['Nirmala UI', 'Mangal', 'Latha'];
    return switch (scriptOf(displayText)) {
      NameScript.devanagari || NameScript.tamil => indic,
      _ => [
          ...switch (font) {
            NameFont.classic => ['Georgia', 'Times New Roman'],
            NameFont.modern => ['Segoe UI', 'Arial'],
            NameFont.script => ['Segoe Script', 'Gabriola'],
          },
          ...indic,
        ],
    };
  }

  // Laid out in an art box: a bail (the small loop the ring goes through)
  // on top, then the plate or tag.
  static const double _bail = bailHeight;
  static const double _margin = 4;

  /// The artwork's proportions.
  Size get artBox => switch (shape) {
        NameShape.letters => const Size(160, _bail + 12 + 60 + _margin),
        NameShape.barTag => const Size(160, _bail + 56 + _margin),
        NameShape.roundTag || NameShape.heartTag =>
          const Size(100, _bail + 92 + _margin),
      };

  /// Width on screen when hung, in logical pixels; height follows.
  double get charmSize => switch (shape) {
        NameShape.letters || NameShape.barTag => 64,
        _ => 48,
      };

  /// The ring goes through the top of the bail.
  Offset get hang => const Offset(0.5, 0);

  Rect get _body => Rect.fromLTRB(
      _margin, _bail, artBox.width - _margin, artBox.height - _margin);

  /// Where the text must fit, inside the plate or tag.
  Rect get textArea => switch (shape) {
        NameShape.letters => Rect.fromLTRB(
            _margin, _bail + 12, artBox.width - _margin, artBox.height - _margin),
        NameShape.barTag => _body.deflate(10),
        NameShape.roundTag => Rect.fromCenter(
            center: _body.center,
            width: _body.width * 0.72,
            height: _body.height * 0.5),
        NameShape.heartTag => Rect.fromCenter(
            center: _body.center.translate(0, -_body.height * 0.06),
            width: _body.width * 0.62,
            height: _body.height * 0.36),
      };

  Path _tagPath() {
    final r = _body;
    return switch (shape) {
      NameShape.roundTag => Path()..addOval(r),
      NameShape.barTag => Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2))),
      NameShape.heartTag => heartPath(r),
      NameShape.letters => Path(),
    };
  }

  /// The text set at the largest size that fits [textArea], painted with
  /// [paint]. Long names come out smaller rather than overflowing.
  TextPainter layoutText(Paint paint) {
    const probeSize = 100.0;
    TextPainter make(double fontSize) => TextPainter(
          text: TextSpan(
            text: displayText.isEmpty ? ' ' : displayText,
            style: TextStyle(
              fontFamily: fontFamilies.first,
              fontFamilyFallback: fontFamilies.skip(1).toList(),
              fontSize: fontSize,
              fontWeight: shape == NameShape.letters
                  ? FontWeight.w700
                  : FontWeight.w600,
              foreground: paint,
              height: 1.15,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

    final probe = make(probeSize);
    final area = textArea;
    final fit = math.min(area.width / probe.width, area.height / probe.height);
    probe.dispose();
    return make(probeSize * fit);
  }

  Paint _metal(Rect bounds) => metalPaint(finish, bounds);

  /// Draws the charm into [size] (any size with the art box's proportions).
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / artBox.width, size.height / artBox.height);
    final metal = _metal(Offset.zero & artBox);
    paintBail(canvas, artBox.width, metal);

    final area = textArea;
    if (shape == NameShape.letters) {
      // A slim nameplate bar that the letters hang from.
      final bar = RRect.fromRectAndRadius(
          Rect.fromLTWH(artBox.width * 0.2, _bail + 2, artBox.width * 0.6, 5),
          const Radius.circular(2.5));
      canvas.drawRRect(bar, metal);
      // Letters cast in the finish, outlined in its dark tone.
      final fill = layoutText(_metal(area));
      final origin = Offset(area.center.dx - fill.width / 2,
          area.center.dy - fill.height / 2);
      fill.paint(canvas, origin);
      final outline = layoutText(Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = finish.dark);
      outline.paint(canvas, origin);
      fill.dispose();
      outline.dispose();
    } else {
      // A tag with the name stamped into it.
      final tag = _tagPath();
      canvas.drawPath(tag, metal);
      canvas.drawPath(
          tag,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = finish.dark);
      final stampColor = finish == FrameFinish.black
          ? const Color(0xFFE8D7A8)
          : finish.dark;
      final light = layoutText(Paint()..color = finish.light.withValues(alpha: 0.8));
      final stamp = layoutText(Paint()..color = stampColor);
      final origin = Offset(area.center.dx - stamp.width / 2,
          area.center.dy - stamp.height / 2);
      // A lighter copy just below makes the letters look pressed in.
      light.paint(canvas, origin.translate(0, 0.8));
      stamp.paint(canvas, origin);
      light.dispose();
      stamp.dispose();
    }
    canvas.restore();
  }

  /// The finished artwork as a PNG, [width] pixels wide.
  Future<Uint8List> renderPng({int width = 320}) async {
    final height = (width * artBox.height / artBox.width).round();
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
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
