import 'dart:io';
import 'dart:ui' as ui;

import 'package:charm_desktop/charms/charm.dart';
import 'package:charm_desktop/charms/charm_sprite.dart';
import 'package:charm_desktop/charms/user_charms.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves assets straight from the project folder.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every shipped charm draws, at its own size and proportions',
      () async {
    final catalog =
        CharmCatalog.parse(File(CharmCatalog.assetPath).readAsStringSync());
    final bundle = _DiskBundle();
    for (final charm in catalog.all) {
      final sprite = await CharmSprite.draw(charm, 2, bundle);
      expect(sprite.charm.id, charm.id);
      expect(sprite.artSize.width, closeTo(charm.size, 0.01),
          reason: charm.id);
      expect(sprite.image.width, greaterThan(charm.size * 2),
          reason: '${charm.id}: image drawn at 2x');
    }
  });

  test('a charm made by the user draws from their charms folder', () async {
    final dir = Directory.systemTemp.createTempSync('charm_sprite_mine_');
    addTearDown(() => dir.deleteSync(recursive: true));
    // A small 20 x 30 PNG, standing in for a saved photo charm.
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 20, 30),
        ui.Paint()..color = const ui.Color(0xFF3366FF));
    final image = await recorder.endRecording().toImage(20, 30);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    final mine = UserCharms(dir);
    final charm = mine.add(name: 'Mine', png: png, size: 40);
    final sprite =
        await CharmSprite.draw(charm, 1, _DiskBundle(), userCharms: mine);
    expect(sprite.charm.id, charm.id);
    expect(sprite.artSize.width, 40);
    expect(sprite.artSize.height, closeTo(60, 0.01)); // 2 x 3 proportions
  });

  test('a charm whose artwork is missing shows the bead instead', () async {
    const lost = Charm(id: 'lost', name: 'Lost', art: 'nowhere/lost.svg');
    final sprite = await CharmSprite.load(lost, 1, bundle: _DiskBundle());
    expect(sprite.charm.id, Charm.goldBead.id);
  });

  test('the hang point sits where the catalog says', () async {
    const coin = Charm(
        id: 'coin_test',
        name: 'Coin',
        art: 'luck/coin.svg',
        size: 44,
        hang: Offset(0.5, 0.41));
    final sprite = await CharmSprite.draw(coin, 1, _DiskBundle());
    // 41% down a 44 px coin is 0.09 x 44 = 3.96 px above its centre.
    expect(sprite.hangOffset.dx, closeTo(0, 0.01));
    expect(sprite.hangOffset.dy, closeTo(-3.96, 0.01));
  });
}
