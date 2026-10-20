import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:charm_desktop/charms/charm_design.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> solid(int w, int h, Color color) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = color);
  return recorder.endRecording().toImage(w, h);
}

Future<ui.Image> decode(List<int> png) async =>
    (await (await ui.instantiateImageCodec(Uint8List.fromList(png)))
            .getNextFrame())
        .image;

Future<Color> pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData())!;
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i),
      data.getUint8(i + 1), data.getUint8(i + 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every base renders at its own proportions, even with no layers',
      () async {
    for (final base in DesignBase.values) {
      for (final border in DesignBorder.values) {
        final d = CharmDesign(base: base, border: border);
        final image = await decode(await d.renderPng(width: 160));
        expect(image.width, 160);
        expect(image.height, (160 * d.artBox.height / d.artBox.width).round(),
            reason: '$base $border');
      }
    }
  });

  test('layers stay inside the base, but float freely with no base',
      () async {
    final red = await solid(50, 50, const Color(0xFFFF0000));
    // A photo far bigger than the charm, covering everything.
    final layer = PhotoLayer(red, scale: 2);
    for (final base in [DesignBase.circle, DesignBase.none]) {
      final d = CharmDesign(base: base, border: DesignBorder.none, layers: [layer]);
      final image = await decode(await d.renderPng(width: 200));
      final scale = 200 / d.artBox.width;
      // Just inside the body's bottom-left corner: outside a circle.
      final corner = await pixel(image, (6 * scale).round(),
          image.height - (6 * scale).round());
      if (base == DesignBase.circle) {
        expect(corner.a, lessThan(0.05), reason: 'clipped by the circle');
      } else {
        expect(corner.r, greaterThan(0.8), reason: 'no base: not clipped');
      }
    }
  });

  test('finds the topmost layer under a point, even when turned', () async {
    final d = CharmDesign(layers: [
      const StickerLayer(Icons.star_rounded, center: Offset(0.5, 0.5), scale: 0.6),
      const StickerLayer(Icons.favorite,
          center: Offset(0.5, 0.5), scale: 0.3, rotation: math.pi / 4),
    ]);
    final middle = d.layerCenter(d.layers[0]);
    expect(d.layerAt(middle), 1, reason: 'the small one is on top');
    // Off the small one but on the big one.
    expect(d.layerAt(middle.translate(d.contentRect.width * 0.25, 0)), 0);
    expect(d.layerAt(const Offset(-50, -50)), isNull);
  });

  test('moving and resizing stay in range', () {
    const s = StickerLayer(Icons.pets);
    final moved = s.placed(center: const Offset(9, -9), scale: 99);
    expect(moved.center, const Offset(1.25, -0.25));
    expect(moved.scale, DesignLayer.maxScale);
    expect(moved.icon, Icons.pets);
    expect(s.placed(scale: 0).scale, DesignLayer.minScale);
  });

  test('stickers and words draw something', () async {
    final d = CharmDesign(base: DesignBase.none, layers: [
      const StickerLayer(Icons.favorite, ink: LayerInk.red, scale: 0.8),
      const TextLayer('Hi', ink: LayerInk.black, center: Offset(0.5, 0.85)),
    ]);
    final image = await decode(await d.renderPng(width: 200));
    final data = (await image.toByteData())!;
    var drawn = 0;
    for (var i = 3; i < data.lengthInBytes; i += 4) {
      if (data.getUint8(i) > 0) drawn++;
    }
    // Far more than the bail alone.
    expect(drawn, greaterThan(2000));
  });
}
