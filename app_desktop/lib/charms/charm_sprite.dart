import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../support/app_log.dart';
import 'charm.dart';
import 'user_charms.dart';

/// A charm's artwork drawn once into an image at the screen's pixel
/// density, with a soft shadow in its own shape. Each frame only places and
/// turns it, so even detailed artwork costs nothing extra while swinging.
class CharmSprite {
  CharmSprite._(this.charm, this.devicePixelRatio, this.frames, this.artSize,
      [this.delays = const []]);

  /// Room around the artwork for its shadow.
  static const double pad = 12;

  final Charm charm;
  final double devicePixelRatio;
  /// The artwork: one image for a still charm, one per frame for an
  /// animated one.
  final List<ui.Image> frames;

  /// How long each frame shows; empty for a still charm.
  final List<Duration> delays;

  ui.Image get image => frames.first;

  bool get isAnimated => frames.length > 1;

  /// Frames kept from an animation. Longer ones are cut here, so a huge
  /// file can't fill the memory.
  static const int maxFrames = 120;

  /// The shortest a frame is shown. Browsers treat the 0 and 10 ms delays
  /// that many GIFs carry as 100 ms; so do we. It also keeps the repaint
  /// rate, and so the CPU cost, modest.
  static const Duration minDelay = Duration(milliseconds: 60);

  Duration get _loop => delays.fold(Duration.zero, (a, b) => a + b);

  Duration _intoLoop(Duration time) =>
      Duration(microseconds: time.inMicroseconds % _loop.inMicroseconds);

  /// The image to show [time] after the animation began (looping).
  ui.Image imageAt(Duration time) {
    if (!isAnimated) return image;
    var into = _intoLoop(time);
    for (var i = 0; i < delays.length; i++) {
      if (into < delays[i]) return frames[i];
      into -= delays[i];
    }
    return frames.last;
  }

  /// How long until the frame shown at [time] is replaced.
  Duration untilNextFrame(Duration time) {
    var into = _intoLoop(time);
    for (final delay in delays) {
      if (into < delay) return delay - into;
      into -= delay;
    }
    return delays.last;
  }

  /// Time since the app started: what an animation's frames are read
  /// against, so every painter shows the same frame.
  static final clock = Stopwatch()..start();

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
      {AssetBundle? bundle, UserCharms? userCharms}) {
    return _cache.putIfAbsent((charm.id, devicePixelRatio), () async {
      try {
        return await _draw(charm, devicePixelRatio, bundle ?? rootBundle,
            userCharms: userCharms);
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
          Charm charm, double dpr, AssetBundle bundle,
          {UserCharms? userCharms}) =>
      _draw(charm, dpr, bundle, userCharms: userCharms);

  static Future<CharmSprite> _draw(
      Charm charm, double dpr, AssetBundle bundle,
      {UserCharms? userCharms}) async {
    if (charm.isBuiltIn) return goldBead(dpr);
    // Read the file here, so a missing one fails in this function rather
    // than inside the SVG library's own loading. The user's own charms come
    // from their charms folder, the rest from the app's assets.
    final Uint8List bytes;
    if (charm.isUser) {
      bytes = await (userCharms ?? UserCharms.standard())
          .fileFor(charm)
          .readAsBytes();
    } else {
      final data = await bundle.load('assets/charms/${charm.art}');
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }

    if (charm.art.toLowerCase().endsWith('.svg')) {
      final info = await vg.loadPicture(SvgBytesLoader(bytes), null);
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

    // Decoded no larger than needed: a big GIF costs memory per frame.
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: (charm.size * dpr * 2).ceil());
    try {
      final wanted = math.min(codec.frameCount, maxFrames);
      final images = <ui.Image>[];
      final delays = <Duration>[];
      Size? art;
      for (var i = 0; i < wanted; i++) {
        final frame = await codec.getNextFrame();
        final source = frame.image;
        try {
          final size = art ??=
              Size(charm.size, charm.size * source.height / source.width);
          images.add(_renderImage(dpr, size, (canvas) {
            canvas.drawImageRect(
              source,
              Rect.fromLTWH(
                  0, 0, source.width.toDouble(), source.height.toDouble()),
              Offset.zero & size,
              Paint()..filterQuality = FilterQuality.medium,
            );
          }));
          final shown = frame.duration;
          delays.add(shown <= const Duration(milliseconds: 10)
              ? const Duration(milliseconds: 100)
              : shown < minDelay
                  ? minDelay
                  : shown);
        } finally {
          source.dispose();
        }
      }
      return CharmSprite._(charm, dpr, images, art!, delays);
    } finally {
      codec.dispose();
    }
  }

  /// Draws the artwork (via [paintArt], in a box of [art] logical pixels
  /// at the origin) with its shadow beneath, into an image.
  static CharmSprite _render(Charm charm, double dpr, Size art,
          void Function(Canvas canvas) paintArt) =>
      CharmSprite._(charm, dpr, [_renderImage(dpr, art, paintArt)], art);

  static ui.Image _renderImage(
      double dpr, Size art, void Function(Canvas canvas) paintArt) {
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
    return image;
  }
}
