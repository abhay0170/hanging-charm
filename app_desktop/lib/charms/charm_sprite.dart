import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../support/app_log.dart';
import 'charm.dart';

/// A charm's artwork drawn once into an image at the screen's pixel
/// density, with a soft shadow in its own shape. Each frame only places and
/// turns it, so even detailed artwork costs nothing extra while swinging.
class CharmSprite {
  CharmSprite._(this.charm, this.devicePixelRatio, this.image, this.artSize);

  /// Room around the artwork for its shadow.
  static const double pad = 12;

  final Charm charm;
  final double devicePixelRatio;
  final ui.Image image;

  /// The artwork's size on screen, in logical pixels.
  final Size artSize;

  /// The image's size on screen, artwork plus shadow room.
  Size get extent => Size(artSize.width + pad * 2, artSize.height + pad * 2);

  /// From the artwork's centre to its hang point, in the artwork's own
  /// upright orientation.
  Offset get hangOffset => Offset((charm.hang.dx - 0.5) * artSize.width,
      (charm.hang.dy - 0.5) * artSize.height);

  /// How far from its centre the charm can be grabbed.
  double get hitRadius => math.max(artSize.width, artSize.height) / 2;

  static final _cache = <(String, double), Future<CharmSprite>>{};

  /// The sprite for [charm] at [devicePixelRatio], drawn once and kept.
  static Future<CharmSprite> load(Charm charm, double devicePixelRatio,
      {AssetBundle? bundle}) {
    return _cache.putIfAbsent((charm.id, devicePixelRatio), () async {
      try {
        return await _draw(charm, devicePixelRatio, bundle ?? rootBundle);
      } on Object catch (error, stack) {
        // Missing or broken artwork: note why, forget the failure so a fixed
        // file can load later, and show the bead meanwhile.
        AppLog.error('Could not draw charm "${charm.id}" (${charm.art})',
            error, stack);
        _cache.remove((charm.id, devicePixelRatio));
        return goldBead(devicePixelRatio);
      }
    });
  }

  /// The built-in bead, available at once (no loading).
  static CharmSprite goldBead(double devicePixelRatio) {
    const art = Size.square(44);
    return _render(Charm.goldBead, devicePixelRatio, art, (canvas) {
      const center = Offset(22, 22);
      const radius = 22.0;
      final body = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
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
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF6B430B),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: center.translate(-7, -9), width: 12, height: 7),
        Paint()..color = const Color(0xCCFFFFFF),
      );
    });
  }

  /// Draws [charm] without the bead fallback, so failures surface.
  @visibleForTesting
  static Future<CharmSprite> draw(
          Charm charm, double dpr, AssetBundle bundle) =>
      _draw(charm, dpr, bundle);

  static Future<CharmSprite> _draw(
      Charm charm, double dpr, AssetBundle bundle) async {
    if (charm.isBuiltIn) return goldBead(dpr);
    final path = 'assets/charms/${charm.art}';
    // Read the file here, so a missing one fails in this function rather
    // than inside the SVG library's own loading.
    final data = await bundle.load(path);

    if (path.toLowerCase().endsWith('.svg')) {
      final info = await vg.loadPicture(
          SvgBytesLoader(data.buffer.asUint8List(
              data.offsetInBytes, data.lengthInBytes)),
          null);
      try {
        final source = info.size;
        final art = Size(charm.size, charm.size * source.height / source.width);
        return _render(charm, dpr, art, (canvas) {
          canvas.scale(art.width / source.width, art.height / source.height);
          canvas.drawPicture(info.picture);
        });
      } finally {
        info.picture.dispose();
      }
    }

    final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final frame = await codec.getNextFrame();
    final png = frame.image;
    try {
      final art =
          Size(charm.size, charm.size * png.height / png.width);
      return _render(charm, dpr, art, (canvas) {
        canvas.drawImageRect(
          png,
          Rect.fromLTWH(0, 0, png.width.toDouble(), png.height.toDouble()),
          Offset.zero & art,
          Paint()..filterQuality = FilterQuality.medium,
        );
      });
    } finally {
      png.dispose();
    }
  }

  /// Draws the artwork (via [paintArt], in a box of [art] logical pixels
  /// at the origin) with its shadow beneath, into an image.
  static CharmSprite _render(Charm charm, double dpr, Size art,
      void Function(Canvas canvas) paintArt) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(dpr)
      ..translate(pad, pad);

    // Shadow: the artwork's own silhouette, darkened, blurred and nudged
    // down a little.
    canvas.saveLayer(
      null,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4)
        ..colorFilter =
            const ColorFilter.mode(Color(0x55000000), BlendMode.srcIn),
    );
    canvas.translate(0, 3);
    paintArt(canvas);
    canvas.restore();

    canvas.save();
    paintArt(canvas);
    canvas.restore();

    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      ((art.width + pad * 2) * dpr).ceil(),
      ((art.height + pad * 2) * dpr).ceil(),
    );
    picture.dispose();
    return CharmSprite._(charm, dpr, image, art);
  }
}
