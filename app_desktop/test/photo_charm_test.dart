import 'dart:ui' as ui;

import 'package:charm_desktop/charms/photo_charm.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// A solid-colour test "photo".
Future<ui.Image> solidPhoto(int width, int height, Color color) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = color);
  return recorder.endRecording().toImage(width, height);
}

Future<Color> pixelAt(ui.Image image, int x, int y) async {
  final data = (await image.toByteData())!;
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i),
      data.getUint8(i + 1), data.getUint8(i + 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the photo always covers the frame, whatever the zoom and offset', () {
    const frame = Rect.fromLTWH(10, 20, 80, 80);
    for (final photo in const [Size(400, 300), Size(300, 800), Size(50, 50)]) {
      for (final zoom in [1.0, 2.5, 4.0]) {
        for (final offset in const [
          Offset.zero,
          Offset(1, 1),
          Offset(-1, 1),
          Offset(1, -1)
        ]) {
          final r = PhotoCharmDesign(zoom: zoom, offset: offset)
              .photoRect(photo, frame);
          expect(r.left, lessThanOrEqualTo(frame.left + 1e-9));
          expect(r.top, lessThanOrEqualTo(frame.top + 1e-9));
          expect(r.right, greaterThanOrEqualTo(frame.right - 1e-9));
          expect(r.bottom, greaterThanOrEqualTo(frame.bottom - 1e-9));
        }
      }
    }
  });

  test('zoom and offset are kept in range', () {
    final d = const PhotoCharmDesign()
        .copyWith(zoom: 99, offset: const Offset(-5, 7));
    expect(d.zoom, PhotoCharmDesign.maxZoom);
    expect(d.offset, const Offset(-1, 1));
    expect(const PhotoCharmDesign().copyWith(zoom: 0).zoom,
        PhotoCharmDesign.minZoom);
  });

  test('renders a PNG of the right size: photo inside, clear outside',
      () async {
    final photo = await solidPhoto(300, 200, const Color(0xFFFF0000));
    for (final shape in FrameShape.values) {
      final design = PhotoCharmDesign(shape: shape);
      final png = await design.renderPng(photo, width: 200);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 200, reason: shape.name);
      expect(image.height,
          (200 * design.artBox.height / design.artBox.width).round(),
          reason: shape.name);

      // The middle of the frame shows the photo.
      final scale = 200 / design.artBox.width;
      final middle = await pixelAt(image, 100,
          ((14 + (design.artBox.height - 14 - 4) / 2) * scale).round());
      expect(middle.r, greaterThan(0.8), reason: '${shape.name}: photo');
      expect(middle.g, lessThan(0.25), reason: '${shape.name}: photo');
      // A corner beside the bail is see-through.
      final corner = await pixelAt(image, 2, 2);
      expect(corner.a, lessThan(0.05), reason: '${shape.name}: corner');
    }
  });
}
