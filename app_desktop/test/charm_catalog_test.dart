import 'dart:convert';
import 'dart:io';

import 'package:charm_desktop/charms/charm.dart';
import 'package:flutter_test/flutter_test.dart';

String catalog(List<Map<String, Object?>> collections) =>
    jsonEncode({'collections': collections});

void main() {
  test('reads collections and charms', () {
    final c = CharmCatalog.parse(catalog([
      {
        'id': 'luck',
        'name': 'Luck',
        'description': 'For luck.',
        'charms': [
          {
            'id': 'clover',
            'name': 'Clover',
            'art': 'luck/clover.svg',
            'size': 40,
            'mass': 7,
            'hang': [0.5, 0.05],
          },
        ],
      },
    ]));
    final clover = c.charmFor('clover');
    expect(clover.name, 'Clover');
    expect(clover.size, 40);
    expect(clover.mass, 7);
    expect(clover.hang, const Offset(0.5, 0.05));
    expect(c.collections.single.description, 'For luck.');
  });

  test('the gold bead is always there, and is the fallback', () {
    final c = CharmCatalog.parse(catalog([
      {
        'id': 'luck',
        'name': 'Luck',
        'charms': [
          {'id': 'clover', 'name': 'Clover', 'art': 'luck/clover.svg'},
        ],
      },
    ]));
    expect(c.all.first.id, 'gold_bead');
    expect(c.charmFor('no_such_charm'), Charm.goldBead);
  });

  test('a damaged or empty catalog still gives the gold bead', () {
    expect(CharmCatalog.parse('{ nope').all, [Charm.goldBead]);
    expect(CharmCatalog.parse('{}').all, [Charm.goldBead]);
    expect(CharmCatalog.parse(catalog([])).all, [Charm.goldBead]);
  });

  test('skips unusable charms and repeated ids, keeps the rest', () {
    final c = CharmCatalog.parse(catalog([
      {
        'id': 'mixed',
        'name': 'Mixed',
        'charms': [
          {'id': 'ok', 'name': 'OK', 'art': 'a/ok.svg'},
          {'id': 'ok', 'name': 'Duplicate', 'art': 'a/dup.svg'},
          {'name': 'No id', 'art': 'a/x.svg'},
          {'id': 'no_art', 'name': 'No art'},
          {'id': 'gif', 'name': 'Wrong type', 'art': 'a/x.gif'},
          {'id': 'escape', 'name': 'Escape', 'art': '../../secret.svg'},
          'not even a map',
        ],
      },
    ]));
    expect(c.all.map((ch) => ch.id), ['gold_bead', 'ok']);
    expect(c.charmFor('ok').name, 'OK');
  });

  test('pulls sizes, weights and hang points into range', () {
    final c = CharmCatalog.parse(catalog([
      {
        'id': 'x',
        'name': 'X',
        'charms': [
          {
            'id': 'huge',
            'name': 'Huge',
            'art': 'a/h.svg',
            'size': 500,
            'mass': -4,
            'hang': [3, -1],
          },
          {
            'id': 'centre',
            'name': 'Hung from its middle',
            'art': 'a/c.svg',
            'hang': [0.5, 0.5],
          },
        ],
      },
    ]));
    final huge = c.charmFor('huge');
    expect(huge.size, Charm.maxSize);
    expect(huge.mass, Charm.minMass);
    expect(huge.hang, const Offset(1, 0));
    // Hanging from the centre is meaningless: back to top centre.
    expect(c.charmFor('centre').hang, const Offset(0.5, 0));
  });

  test('the shipped catalog is valid and every artwork file exists', () {
    final source = File('assets/charms/catalog.json').readAsStringSync();
    final json = jsonDecode(source) as Map;
    final listed = [
      for (final c in json['collections'] as List)
        for (final ch in (c as Map)['charms'] as List) (ch as Map)['id'],
    ];
    final c = CharmCatalog.parse(source);
    // Nothing in the shipped file may be silently dropped.
    expect(c.all.map((ch) => ch.id).toSet(),
        {...listed, Charm.goldBead.id});
    for (final charm in c.all.where((ch) => !ch.isBuiltIn)) {
      expect(File('assets/charms/${charm.art}').existsSync(), isTrue,
          reason: '${charm.id}: ${charm.art} is missing');
    }
  });
}
