import 'dart:io';

import 'package:charm_desktop/charms/charm.dart';
import 'package:charm_desktop/charms/charm_sprite.dart';
import 'package:charm_desktop/charms/user_charms.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Three 8 x 12 frames (red, green, blue) shown for 100 ms, 200 ms and
/// 0 ms; a delay of 0 is meant to be read as 100 ms.
final _gif = Uint8List.fromList([
  0x47,
  0x49,
  0x46,
  0x38,
  0x39,
  0x61,
  0x08,
  0x00,
  0x0C,
  0x00,
  0x81,
  0x00,
  0x00,
  0xFF,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x21,
  0xFF,
  0x0B,
  0x4E,
  0x45,
  0x54,
  0x53,
  0x43,
  0x41,
  0x50,
  0x45,
  0x32,
  0x2E,
  0x30,
  0x03,
  0x01,
  0x00,
  0x00,
  0x00,
  0x21,
  0xF9,
  0x04,
  0x00,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x2C,
  0x00,
  0x00,
  0x00,
  0x00,
  0x08,
  0x00,
  0x0C,
  0x00,
  0x00,
  0x08,
  0x12,
  0x00,
  0x01,
  0x08,
  0x1C,
  0x48,
  0xB0,
  0xA0,
  0xC1,
  0x83,
  0x08,
  0x13,
  0x2A,
  0x5C,
  0xC8,
  0xB0,
  0x61,
  0xC1,
  0x80,
  0x00,
  0x21,
  0xF9,
  0x04,
  0x01,
  0x14,
  0x00,
  0x01,
  0x00,
  0x2C,
  0x00,
  0x00,
  0x00,
  0x00,
  0x08,
  0x00,
  0x0C,
  0x00,
  0x81,
  0x00,
  0xFF,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x08,
  0x12,
  0x00,
  0x01,
  0x08,
  0x1C,
  0x48,
  0xB0,
  0xA0,
  0xC1,
  0x83,
  0x08,
  0x13,
  0x2A,
  0x5C,
  0xC8,
  0xB0,
  0x61,
  0xC1,
  0x80,
  0x00,
  0x21,
  0xF9,
  0x04,
  0x01,
  0x00,
  0x00,
  0x01,
  0x00,
  0x2C,
  0x00,
  0x00,
  0x00,
  0x00,
  0x08,
  0x00,
  0x0C,
  0x00,
  0x81,
  0x00,
  0x00,
  0xFF,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x08,
  0x12,
  0x00,
  0x01,
  0x08,
  0x1C,
  0x48,
  0xB0,
  0xA0,
  0xC1,
  0x83,
  0x08,
  0x13,
  0x2A,
  0x5C,
  0xC8,
  0xB0,
  0x61,
  0xC1,
  0x80,
  0x00,
  0x3B,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gif and webp art is accepted for user charms and the catalog', () {
    expect(
      Charm.fromJson({'id': 'a', 'name': 'A', 'art': 'user:a_1.gif'}),
      isNotNull,
    );
    expect(
      Charm.fromJson({'id': 'a', 'name': 'A', 'art': 'user:a.webp'}),
      isNotNull,
    );
    expect(
      Charm.fromJson({'id': 'a', 'name': 'A', 'art': 'fun/a.gif'}),
      isNotNull,
    );
    expect(
      Charm.fromJson({'id': 'a', 'name': 'A', 'art': 'user:../a.gif'}),
      isNull,
    );
    expect(
      Charm.fromJson({'id': 'a', 'name': 'A', 'art': 'user:a.exe'}),
      isNull,
    );
  });

  test('only gif and webp count as animated', () {
    const gif = Charm(id: 'g', name: 'G', art: 'user:g.GIF');
    const png = Charm(id: 'p', name: 'P', art: 'user:p.png');
    expect(gif.isAnimatedArt, isTrue);
    expect(png.isAnimatedArt, isFalse);
  });

  test('user charms keep their file type', () {
    final dir = Directory.systemTemp.createTempSync('charm_anim_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final mine = UserCharms(dir);
    final charm = mine.add(name: 'Spin', bytes: _gif, extension: 'gif');
    expect(charm.art, endsWith('.gif'));
    expect(mine.fileFor(charm).readAsBytesSync(), _gif);
    expect(mine.load().single.id, charm.id);
    mine.delete(charm.id);
    expect(mine.load(), isEmpty);
  });

  test('an animated charm draws every frame and plays them in turn', () async {
    final dir = Directory.systemTemp.createTempSync('charm_anim_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final mine = UserCharms(dir);
    final charm = mine.add(name: 'Spin', bytes: _gif, extension: 'gif');

    final sprite = await CharmSprite.draw(
      charm,
      2,
      rootBundle,
      userCharms: mine,
    );
    expect(sprite.isAnimated, isTrue);
    expect(sprite.frames, hasLength(3));
    // 100 ms, 200 ms, and the 0 ms frame raised to 100 ms.
    expect(sprite.delays, [
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 200),
      const Duration(milliseconds: 100),
    ]);

    ms(int n) => Duration(milliseconds: n);
    expect(sprite.imageAt(ms(0)), same(sprite.frames[0]));
    expect(sprite.imageAt(ms(99)), same(sprite.frames[0]));
    expect(sprite.imageAt(ms(100)), same(sprite.frames[1]));
    expect(sprite.imageAt(ms(299)), same(sprite.frames[1]));
    expect(sprite.imageAt(ms(300)), same(sprite.frames[2]));
    // Then it loops.
    expect(sprite.imageAt(ms(400)), same(sprite.frames[0]));
    expect(sprite.untilNextFrame(ms(40)), ms(60));
    expect(sprite.untilNextFrame(ms(100)), ms(200));
    expect(sprite.untilNextFrame(ms(395)), ms(5));
  });

  test('a still charm has one frame and never asks for a repaint', () async {
    final sprite = CharmSprite.goldBead(2);
    expect(sprite.isAnimated, isFalse);
    expect(sprite.imageAt(const Duration(seconds: 5)), same(sprite.image));
  });
}
