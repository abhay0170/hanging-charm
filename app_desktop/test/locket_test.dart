import 'dart:io';
import 'dart:ui' as ui;

import 'package:charm_desktop/charms/charm.dart';
import 'package:charm_desktop/charms/charm_sprite.dart';
import 'package:charm_desktop/charms/locket.dart';
import 'package:charm_desktop/charms/photo_charm.dart';
import 'package:charm_desktop/charms/user_charms.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> decode(Uint8List png) async =>
    (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;

Future<Color> pixelAt(ui.Image image, int x, int y) async {
  final data = (await image.toByteData())!;
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i),
      data.getUint8(i + 1), data.getUint8(i + 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('engraving is cut to a few letters, by visible letters', () {
    expect(const LocketDesign(engraving: '  AB ').engravingText, 'AB');
    expect(const LocketDesign(engraving: 'ABCDEF').engravingText, 'ABC');
    expect(const LocketDesign(engraving: 'அம்மா').engravingText.characters,
        hasLength(3));
  });

  test('every shape, finish and engraving draws a cover of the right size',
      () async {
    for (final shape in FrameShape.values) {
      for (final engraving in ['', 'A', 'മ', 'அ']) {
        final design = LocketDesign(
            photo: PhotoCharmDesign(shape: shape, finish: FrameFinish.silver),
            engraving: engraving);
        final image = await decode(await design.renderCoverPng(width: 200));
        expect(image.width, 200);
        expect(image.height,
            (200 * design.artBox.height / design.artBox.width).round());
        // The middle of the cover is metal, not empty.
        final centre = await pixelAt(image, 100, image.height * 5 ~/ 8);
        expect(centre.a, greaterThan(0.9), reason: '$shape "$engraving"');
        // The corner is empty.
        expect((await pixelAt(image, 1, image.height - 2)).a, 0);
      }
    }
  });

  test('a locket knows its inside, and only a user charm can have one', () {
    final locket = Charm.fromJson({
      'id': 'a',
      'name': 'A',
      'art': 'user:a.png',
      'openArt': 'user:a_open.png',
    });
    expect(locket!.isLocket, isTrue);
    expect(Charm.fromJson(locket.toJson())!.openArt, 'user:a_open.png');

    for (final bad in [
      'user:../a.png',
      'a_open.png',
      'user:a.exe',
      '/etc/passwd',
      42,
    ]) {
      final charm = Charm.fromJson(
          {'id': 'a', 'name': 'A', 'art': 'user:a.png', 'openArt': bad});
      expect(charm!.isLocket, isFalse, reason: '$bad');
    }
    // A catalog charm can't be a locket.
    expect(
        Charm.fromJson({
          'id': 'a',
          'name': 'A',
          'art': 'x/a.png',
          'openArt': 'user:a_open.png',
        })!
            .isLocket,
        isFalse);
    expect(
        const Charm(id: 'p', name: 'P', art: 'user:p.png').toJson().keys,
        isNot(contains('openArt')));
  });

  test('a locket is saved with its inside, and both go when it is deleted',
      () async {
    final dir = Directory.systemTemp.createTempSync('charm_locket_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final mine = UserCharms(dir);
    final cover = await const LocketDesign().renderCoverPng(width: 64);
    final inside = await const PhotoCharmDesign().renderPng(
        await _solid(40, 40), width: 64);

    final charm = mine.add(name: 'Nana', png: cover, openPng: inside);
    expect(charm.isLocket, isTrue);
    expect(mine.fileFor(charm).readAsBytesSync(), cover);
    expect(mine.openFileFor(charm).readAsBytesSync(), inside);
    expect(mine.load().single.isLocket, isTrue);

    // A locket that has lost its inside is left out.
    mine.openFileFor(charm).deleteSync();
    expect(mine.load(), isEmpty);

    final again = mine.add(name: 'Again', png: cover, openPng: inside);
    mine.delete(again.id);
    expect(mine.fileFor(again).existsSync(), isFalse);
    expect(mine.openFileFor(again).existsSync(), isFalse);
    expect(mine.load(), isEmpty);
  });

  test('a locket sprite holds its cover and its inside, and does not play',
      () async {
    final dir = Directory.systemTemp.createTempSync('charm_locket_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final mine = UserCharms(dir);
    final charm = mine.add(
        name: 'Nana',
        png: await const LocketDesign().renderCoverPng(width: 96),
        openPng: await const PhotoCharmDesign()
            .renderPng(await _solid(40, 40), width: 96));

    final sprite =
        await CharmSprite.draw(charm, 2, rootBundle, userCharms: mine);
    expect(sprite.isLocket, isTrue);
    expect(sprite.isAnimated, isFalse);
    expect(sprite.frames, hasLength(2));
    expect(sprite.openImage, same(sprite.frames[1]));
    expect(sprite.image, same(sprite.frames[0]));
    // Time doesn't change which one a still locket shows.
    expect(sprite.imageAt(const Duration(seconds: 3)), same(sprite.image));
  });
}

Future<ui.Image> _solid(int w, int h) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFFCC4455));
  return recorder.endRecording().toImage(w, h);
}
