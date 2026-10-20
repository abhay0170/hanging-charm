import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter/painting.dart';

import 'photo_charm.dart' show FrameFinish;
import 'shapes.dart';
import 'text_charm.dart' show NameCharmDesign, NameFont;

/// The shape everything sits on.
enum DesignBase {
  none('No base'),
  circle('Circle'),
  roundedSquare('Rounded square'),
  heart('Heart'),
  oval('Oval'),
  bar('Bar');

  const DesignBase(this.label);
  final String label;
}

/// The edge around the base.
enum DesignBorder {
  none('None'),
  plain('Plain rim'),
  beaded('Beaded'),
  double('Double');

  const DesignBorder(this.label);
  final String label;
}

/// What the base is filled with: a metal, or a coloured enamel.
enum BaseFill {
  gold('Gold', metal: FrameFinish.gold),
  silver('Silver', metal: FrameFinish.silver),
  roseGold('Rose gold', metal: FrameFinish.roseGold),
  ivory('Ivory', enamel: Color(0xFFF4EBD9)),
  red('Red', enamel: Color(0xFFC62B3A)),
  blue('Blue', enamel: Color(0xFF2357B5)),
  green('Green', enamel: Color(0xFF2E8B57)),
  midnight('Midnight', enamel: Color(0xFF1B1E33));

  const BaseFill(this.label, {this.metal, this.enamel});
  final String label;
  final FrameFinish? metal;
  final Color? enamel;

  Paint paintFor(Rect bounds) {
    if (metal case final m?) return metalPaint(m, bounds);
    final c = enamel!;
    return Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.1,
        colors: [Color.lerp(c, const Color(0xFFFFFFFF), 0.35)!, c,
          Color.lerp(c, const Color(0xFF000000), 0.35)!],
        stops: const [0, 0.55, 1],
      ).createShader(bounds);
  }
}

/// The colour of a word or sticker: the design's metal, or a plain colour.
enum LayerInk {
  metal('Metal', null),
  white('White', Color(0xFFFFFFFF)),
  black('Black', Color(0xFF16161A)),
  red('Red', Color(0xFFD12D3D)),
  blue('Blue', Color(0xFF2860C8));

  const LayerInk(this.label, this.color);
  final String label;
  final Color? color;
}

/// The stickers on offer: Material symbols, drawn as solid shapes.
const stickers = <IconData>[
  Icons.star_rounded,
  Icons.favorite,
  Icons.auto_awesome,
  Icons.local_florist,
  Icons.spa,
  Icons.pets,
  Icons.music_note,
  Icons.nightlight_round,
  Icons.wb_sunny,
  Icons.diamond,
  Icons.cake,
  Icons.celebration,
  Icons.anchor,
  Icons.flight,
  Icons.sports_cricket,
  Icons.sports_soccer,
  Icons.coffee,
  Icons.home_rounded,
];

/// One thing placed on the charm. Positions are fractions of the base's
/// content area (0..1 across and down); [scale] is a fraction of its width.
sealed class DesignLayer {
  const DesignLayer({
    required this.center,
    required this.scale,
    this.rotation = 0,
  });

  static const double minScale = 0.1, maxScale = 2;

  final Offset center;
  final double scale;

  /// Radians, clockwise.
  final double rotation;

  /// The same layer moved, resized or turned.
  DesignLayer placed({Offset? center, double? scale, double? rotation});

  static Offset clampCenter(Offset c) =>
      Offset(c.dx.clamp(-0.25, 1.25), c.dy.clamp(-0.25, 1.25));
  static double clampScale(double s) => s.clamp(minScale, maxScale);
}

class PhotoLayer extends DesignLayer {
  const PhotoLayer(this.image,
      {super.center = const Offset(0.5, 0.5),
      super.scale = 1,
      super.rotation});

  final ui.Image image;

  @override
  PhotoLayer placed({Offset? center, double? scale, double? rotation}) =>
      PhotoLayer(image,
          center: DesignLayer.clampCenter(center ?? this.center),
          scale: DesignLayer.clampScale(scale ?? this.scale),
          rotation: rotation ?? this.rotation);
}

class TextLayer extends DesignLayer {
  const TextLayer(this.text,
      {this.font = NameFont.classic,
      this.ink = LayerInk.metal,
      super.center = const Offset(0.5, 0.5),
      super.scale = 0.8,
      super.rotation});

  final String text;
  final NameFont font;
  final LayerInk ink;

  TextLayer withStyle({String? text, NameFont? font, LayerInk? ink}) => TextLayer(
      text ?? this.text,
      font: font ?? this.font,
      ink: ink ?? this.ink,
      center: center,
      scale: scale,
      rotation: rotation);

  @override
  TextLayer placed({Offset? center, double? scale, double? rotation}) =>
      TextLayer(text,
          font: font,
          ink: ink,
          center: DesignLayer.clampCenter(center ?? this.center),
          scale: DesignLayer.clampScale(scale ?? this.scale),
          rotation: rotation ?? this.rotation);
}

class StickerLayer extends DesignLayer {
  const StickerLayer(this.icon,
      {this.ink = LayerInk.metal,
      super.center = const Offset(0.5, 0.5),
      super.scale = 0.45,
      super.rotation});

  final IconData icon;
  final LayerInk ink;

  StickerLayer withInk(LayerInk ink) => StickerLayer(icon,
      ink: ink, center: center, scale: scale, rotation: rotation);

  @override
  StickerLayer placed({Offset? center, double? scale, double? rotation}) =>
      StickerLayer(icon,
          ink: ink,
          center: DesignLayer.clampCenter(center ?? this.center),
          scale: DesignLayer.clampScale(scale ?? this.scale),
          rotation: rotation ?? this.rotation);
}

/// A charm built from layers on a base. The same drawing makes the
/// designer's preview and the saved artwork.
class CharmDesign {
  const CharmDesign({
    this.base = DesignBase.circle,
    this.fill = BaseFill.ivory,
    this.border = DesignBorder.plain,
    this.finish = FrameFinish.gold,
    this.layers = const [],
  });

  final DesignBase base;
  final BaseFill fill;
  final DesignBorder border;

  /// The metal of the rim, the bail, and any metal words or stickers.
  final FrameFinish finish;

  /// Bottom first.
  final List<DesignLayer> layers;

  static const double _margin = 4;
  static const double _rim = 6;

  CharmDesign copyWith({
    DesignBase? base,
    BaseFill? fill,
    DesignBorder? border,
    FrameFinish? finish,
    List<DesignLayer>? layers,
  }) {
    return CharmDesign(
      base: base ?? this.base,
      fill: fill ?? this.fill,
      border: border ?? this.border,
      finish: finish ?? this.finish,
      layers: layers ?? this.layers,
    );
  }

  /// The artwork's proportions.
  Size get artBox => switch (base) {
        DesignBase.oval => const Size(84, bailHeight + 116 + _margin),
        DesignBase.bar => const Size(160, bailHeight + 56 + _margin),
        _ => const Size(100, bailHeight + 92 + _margin),
      };

  /// Width on screen when hung, in logical pixels; height follows.
  double get charmSize => switch (base) {
        DesignBase.bar => 64,
        DesignBase.oval => 42,
        _ => 48,
      };

  Offset get hang => const Offset(0.5, 0);

  Rect get _body => Rect.fromLTRB(_margin, bailHeight, artBox.width - _margin,
      artBox.height - _margin);

  /// Where layers are placed (and, on a base, clipped).
  Rect get contentRect =>
      border == DesignBorder.none || base == DesignBase.none
          ? _body
          : _body.deflate(_rim);

  Path _shape(Rect r) => switch (base) {
        DesignBase.none => Path()..addRect(r),
        DesignBase.circle || DesignBase.oval => Path()..addOval(r),
        DesignBase.roundedSquare => Path()
          ..addRRect(
              RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.2))),
        DesignBase.heart => heartPath(r),
        DesignBase.bar => Path()
          ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2))),
      };

  /// A layer's size before rotation, in art-box units.
  Size layerSize(DesignLayer layer) {
    final w = contentRect.width * layer.scale;
    return switch (layer) {
      PhotoLayer(:final image) => Size(w, w * image.height / image.width),
      StickerLayer() => Size(w, w),
      TextLayer() => () {
          final painter = _textPainter(layer, Paint());
          final size = painter.size;
          painter.dispose();
          return size;
        }(),
    };
  }

  Offset layerCenter(DesignLayer layer) => Offset(
      contentRect.left + contentRect.width * layer.center.dx,
      contentRect.top + contentRect.height * layer.center.dy);

  /// The topmost layer under [point] (art-box units), or null.
  int? layerAt(Offset point) {
    for (var i = layers.length - 1; i >= 0; i--) {
      final layer = layers[i];
      // Turn the point into the layer's own unrotated frame.
      final local = _rotate(point - layerCenter(layer), -layer.rotation);
      final size = layerSize(layer);
      if (local.dx.abs() <= size.width / 2 && local.dy.abs() <= size.height / 2) {
        return i;
      }
    }
    return null;
  }

  static Offset _rotate(Offset v, double a) => Offset(
      v.dx * math.cos(a) - v.dy * math.sin(a),
      v.dx * math.sin(a) + v.dy * math.cos(a));

  Paint _inkPaint(LayerInk ink, Rect bounds) => ink.color == null
      ? metalPaint(finish, bounds)
      : (Paint()..color = ink.color!);

  TextPainter _textPainter(TextLayer layer, Paint foreground) {
    final families = NameCharmDesign(text: layer.text, font: layer.font)
        .fontFamilies;
    return TextPainter(
      text: TextSpan(
        text: layer.text.isEmpty ? ' ' : layer.text,
        style: TextStyle(
          fontFamily: families.first,
          fontFamilyFallback: families.skip(1).toList(),
          fontSize: contentRect.width * layer.scale * 0.32,
          fontWeight: FontWeight.w700,
          foreground: foreground,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  void _paintLayer(Canvas canvas, DesignLayer layer) {
    final center = layerCenter(layer);
    final size = layerSize(layer);
    final box = Rect.fromCenter(
        center: Offset.zero, width: size.width, height: size.height);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(layer.rotation);
    switch (layer) {
      case PhotoLayer(:final image):
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          box,
          Paint()..filterQuality = FilterQuality.high,
        );
      case TextLayer(:final ink):
        final painter = _textPainter(layer, _inkPaint(ink, box));
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        painter.dispose();
      case StickerLayer(:final icon, :final ink):
        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: size.width,
              height: 1,
              foreground: _inkPaint(ink, box),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        painter.dispose();
    }
    canvas.restore();
  }

  void _paintBorder(Canvas canvas, Paint metal) {
    switch (border) {
      case DesignBorder.none:
        return;
      case DesignBorder.plain:
        canvas.drawPath(
            _shape(_body),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = _rim
              ..shader = metal.shader);
      case DesignBorder.double:
        for (final (inset, width) in const [(1.25, 2.5), (5.0, 1.8)]) {
          canvas.drawPath(
              _shape(_body.deflate(inset)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = width
                ..shader = metal.shader);
        }
      case DesignBorder.beaded:
        final path = _shape(_body.deflate(3));
        for (final metric in path.computeMetrics()) {
          final count = (metric.length / 7).floor();
          for (var i = 0; i < count; i++) {
            final at = metric.getTangentForOffset(metric.length * i / count);
            if (at != null) canvas.drawCircle(at.position, 2.6, metal);
          }
        }
    }
  }

  /// Draws the charm into [size] (any size with the art box's proportions).
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / artBox.width, size.height / artBox.height);
    final metal = metalPaint(finish, Offset.zero & artBox);

    paintBail(canvas, artBox.width, metal);

    if (base != DesignBase.none) {
      canvas.drawPath(_shape(_body), fill.paintFor(_body));
      canvas.save();
      canvas.clipPath(_shape(contentRect));
    }
    for (final layer in layers) {
      _paintLayer(canvas, layer);
    }
    if (base != DesignBase.none) {
      canvas.restore();
      _paintBorder(canvas, metal);
    }
    canvas.restore();
  }

  /// Outlines layer [index] for the designer (not part of the charm).
  void paintSelection(Canvas canvas, Size size, int index, Color color) {
    if (index < 0 || index >= layers.length) return;
    final layer = layers[index];
    canvas.save();
    canvas.scale(size.width / artBox.width, size.height / artBox.height);
    final center = layerCenter(layer);
    final s = layerSize(layer);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(layer.rotation);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: s.width + 3, height: s.height + 3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = color);
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
