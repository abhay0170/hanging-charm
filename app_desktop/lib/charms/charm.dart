import 'dart:convert';

import 'package:flutter/services.dart';

/// One charm: its artwork and how it hangs.
///
/// Charms are listed in `assets/charms/catalog.json`. To add one, drop its
/// SVG or PNG into a folder under `assets/charms/` and add an entry there.
class Charm {
  const Charm({
    required this.id,
    required this.name,
    required this.art,
    this.description = '',
    this.size = 44,
    this.mass = 12,
    this.hang = const Offset(0.5, 0),
  });

  /// Size limits keep every charm inside the charm window's swing room.
  static const double minSize = 24;
  static const double maxSize = 64;
  static const double minMass = 3;
  static const double maxMass = 30;

  final String id;
  final String name;
  final String description;

  /// Path under `assets/charms/` (an .svg or .png), or `builtin:gold_bead`.
  final String art;

  /// Width of the artwork on screen, in logical pixels. Its height follows
  /// from the artwork's own proportions.
  final double size;

  /// How heavy it is, against 0.05–1 for each rope point: a heavier charm
  /// pulls its rope straighter and carries more swing.
  final double mass;

  /// Where the ring attaches, as a fraction of the artwork's width and
  /// height (0,0 = top left). The charm hangs with this point straight above
  /// its centre.
  final Offset hang;

  bool get isBuiltIn => art.startsWith('builtin:');

  /// Made by the user: `user:<file>.png` (or .gif, .webp), a file in their charms folder.
  bool get isUser => art.startsWith(userArtPrefix);

  static const userArtPrefix = 'user:';
  static final _userArt = RegExp(r'^user:[A-Za-z0-9_-]+\.(png|gif|webp)$');

  /// Artwork that can move: a GIF or an animated WebP.
  bool get isAnimatedArt {
    final lower = art.toLowerCase();
    return lower.endsWith('.gif') || lower.endsWith('.webp');
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'art': art,
        'size': size,
        'mass': mass,
        'hang': [hang.dx, hang.dy],
      };

  /// The polished bead the app has always had, drawn in code.
  static const goldBead = Charm(
    id: 'gold_bead',
    name: 'Gold bead',
    description: 'Polished, weighty and never out of place.',
    art: 'builtin:gold_bead',
  );

  /// Reads one catalog entry, or returns null if it is unusable. Out-of-range
  /// numbers are pulled into range rather than rejected.
  static Charm? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], art = json['art'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;
    if (art is! String || !_artIsUsable(art)) return null;

    double number(String key, double fallback, double min, double max) {
      final value = json[key];
      if (value is! num || !value.isFinite) return fallback;
      return value.toDouble().clamp(min, max);
    }

    var hang = const Offset(0.5, 0);
    final hangJson = json['hang'];
    if (hangJson is List &&
        hangJson.length == 2 &&
        hangJson.every((v) => v is num && v.isFinite)) {
      final x = (hangJson[0] as num).toDouble().clamp(0.0, 1.0);
      final y = (hangJson[1] as num).toDouble().clamp(0.0, 1.0);
      // Hanging from (near) the centre would leave nothing to hang by.
      if ((Offset(x, y) - const Offset(0.5, 0.5)).distance >= 0.15) {
        hang = Offset(x, y);
      }
    }

    final description = json['description'];
    return Charm(
      id: id,
      name: name,
      art: art,
      description: description is String ? description : '',
      size: number('size', 44, minSize, maxSize),
      mass: number('mass', 12, minMass, maxMass),
      hang: hang,
    );
  }

  static bool _artIsUsable(String art) {
    if (art == goldBead.art) return true;
    // A user charm's art is a bare file name in their charms folder, never
    // a path, so an entry can't point anywhere else on disk.
    if (art.startsWith(userArtPrefix)) return _userArt.hasMatch(art);
    final lower = art.toLowerCase();
    return (lower.endsWith('.svg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.gif') ||
            lower.endsWith('.webp')) &&
        !art.contains('..');
  }
}

/// A named group of charms, shown as one section of the Library.
class CharmCollection {
  const CharmCollection({
    required this.id,
    required this.name,
    this.description = '',
    required this.charms,
  });

  final String id;
  final String name;
  final String description;
  final List<Charm> charms;
}

/// Every charm the app offers, by collection.
class CharmCatalog {
  CharmCatalog(this.collections)
      : _byId = {
          for (final c in collections) for (final charm in c.charms) charm.id: charm,
        };

  static const String assetPath = 'assets/charms/catalog.json';

  final List<CharmCollection> collections;
  final Map<String, Charm> _byId;

  /// Just the gold bead: what the app falls back to if the catalog is missing
  /// or unreadable.
  factory CharmCatalog.builtIn() => CharmCatalog([
        const CharmCollection(
            id: 'classic', name: 'Classic', charms: [Charm.goldBead]),
      ]);

  /// Reads the catalog. Unusable charms and repeated ids are skipped, empty
  /// collections dropped, and the gold bead is always there.
  factory CharmCatalog.parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      return CharmCatalog.builtIn();
    }
    final collectionsJson = json is Map ? json['collections'] : null;
    if (collectionsJson is! List) return CharmCatalog.builtIn();

    final seen = <String>{};
    final collections = <CharmCollection>[];
    for (final c in collectionsJson) {
      if (c is! Map) continue;
      final id = c['id'], name = c['name'], charmsJson = c['charms'];
      if (id is! String || name is! String || charmsJson is! List) continue;
      final charms = <Charm>[];
      for (final entry in charmsJson) {
        final charm = Charm.fromJson(entry);
        if (charm != null && seen.add(charm.id)) charms.add(charm);
      }
      if (charms.isEmpty) continue;
      final description = c['description'];
      collections.add(CharmCollection(
        id: id,
        name: name,
        description: description is String ? description : '',
        charms: charms,
      ));
    }

    if (!seen.contains(Charm.goldBead.id)) {
      if (collections.isEmpty) return CharmCatalog.builtIn();
      final first = collections.first;
      collections[0] = CharmCollection(
        id: first.id,
        name: first.name,
        description: first.description,
        charms: [Charm.goldBead, ...first.charms],
      );
    }
    return CharmCatalog(collections);
  }

  static Future<CharmCatalog> load(AssetBundle bundle) async {
    try {
      return CharmCatalog.parse(await bundle.loadString(assetPath));
    } on Object {
      return CharmCatalog.builtIn();
    }
  }

  /// This catalog with the user's own charms in front, as "My charms".
  CharmCatalog withUserCharms(List<Charm> mine) {
    final builtIn = collections.where((c) => c.id != userCollectionId);
    final ids = {for (final c in builtIn) for (final ch in c.charms) ch.id};
    final own = [for (final ch in mine) if (!ids.contains(ch.id)) ch];
    return CharmCatalog([
      if (own.isNotEmpty)
        CharmCollection(
          id: userCollectionId,
          name: 'My charms',
          description: 'Made by you, from your own photos.',
          charms: own,
        ),
      ...builtIn,
    ]);
  }

  static const userCollectionId = 'mine';

  List<Charm> get all => [for (final c in collections) ...c.charms];

  /// The charm with [id], or the gold bead if there is none.
  Charm charmFor(String id) => _byId[id] ?? Charm.goldBead;
}
