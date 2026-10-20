import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charm_desktop/charms/charm.dart';
import 'package:charm_desktop/charms/user_charms.dart';
import 'package:flutter_test/flutter_test.dart';

final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

void main() {
  late Directory dir;
  late UserCharms mine;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('charm_mine_');
    mine = UserCharms(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('starts with none', () => expect(mine.load(), isEmpty));

  test('saves a charm with its artwork and reads it back, newest first', () {
    final first = mine.add(name: 'Grandma', png: _png);
    final second = mine.add(name: '  Rex  ', png: _png);
    expect(second.name, 'Rex');
    expect(first.isUser, isTrue);
    expect(mine.fileFor(first).readAsBytesSync(), _png);
    expect(UserCharms(dir).load().map((c) => c.id), [second.id, first.id]);
  });

  test('a blank name becomes "My charm"', () {
    expect(mine.add(name: '   ', png: _png).name, 'My charm');
  });

  test('deleting removes the entry and the file', () {
    final keep = mine.add(name: 'Keep', png: _png);
    final drop = mine.add(name: 'Drop', png: _png);
    mine.delete(drop.id);
    expect(mine.load().map((c) => c.id), [keep.id]);
    expect(mine.fileFor(drop).existsSync(), isFalse);
  });

  test('entries whose file is missing, or that point outside, are ignored',
      () {
    final ok = mine.add(name: 'OK', png: _png);
    final manifest = File('${dir.path}${Platform.pathSeparator}my_charms.json');
    final json = jsonDecode(manifest.readAsStringSync()) as Map;
    (json['charms'] as List).addAll([
      {'id': 'gone', 'name': 'Gone', 'art': 'user:gone.png'},
      {'id': 'sneaky', 'name': 'Sneaky', 'art': 'user:../../secret.png'},
      {'id': 'pathy', 'name': 'Pathy', 'art': r'user:C:\x.png'},
    ]);
    manifest.writeAsStringSync(jsonEncode(json));
    expect(mine.load().map((c) => c.id), [ok.id]);
  });

  test('a damaged list reads as none', () {
    File('${dir.path}${Platform.pathSeparator}my_charms.json')
        .writeAsStringSync('{ nope');
    expect(mine.load(), isEmpty);
  });

  test('"My charms" goes first in the catalog, and only when not empty', () {
    final base = CharmCatalog.builtIn();
    expect(base.withUserCharms(const []).collections.map((c) => c.id),
        ['classic']);
    final made = mine.add(name: 'Rex', png: _png);
    final merged = base.withUserCharms(mine.load());
    expect(merged.collections.first.name, 'My charms');
    expect(merged.charmFor(made.id).name, 'Rex');
    // Merging again replaces, rather than stacks, the user's collection.
    expect(merged.withUserCharms(const []).collections.map((c) => c.id),
        ['classic']);
  });
}
