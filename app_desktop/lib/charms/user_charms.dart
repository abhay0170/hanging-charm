import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import '../settings/settings_store.dart';
import 'charm.dart';

/// Charms the user made, kept in their charms folder (next to the
/// settings): one PNG each, listed in `my_charms.json` in the same format as
/// the built-in catalog. Nothing here ever leaves the computer.
class UserCharms {
  UserCharms(this.directory);

  /// The usual folder, `%APPDATA%\Charm\charms` on Windows.
  factory UserCharms.standard() => UserCharms(Directory(
      '${SettingsStore.defaultDirectory().path}${Platform.pathSeparator}charms'));

  final Directory directory;

  File get _manifest =>
      File('${directory.path}${Platform.pathSeparator}my_charms.json');

  /// The PNG behind a user charm.
  File fileFor(Charm charm) => File('${directory.path}'
      '${Platform.pathSeparator}${charm.art.substring(Charm.userArtPrefix.length)}');

  /// Every saved charm whose entry is usable, newest first. A missing or
  /// damaged list reads as none.
  List<Charm> load() {
    try {
      final json = jsonDecode(_manifest.readAsStringSync());
      final list = json is Map ? json['charms'] : null;
      if (list is! List) return const [];
      return [
        for (final entry in list)
          if (Charm.fromJson(entry) case final charm?
              when charm.isUser && fileFor(charm).existsSync())
            charm,
      ];
    } on Object {
      return const [];
    }
  }

  /// Saves a new charm from its finished artwork: a [png], or the [bytes]
  /// of an animation with its [extension] (`gif` or `webp`). Returns it, ready to hang.
  Charm add({
    required String name,
    Uint8List? png,
    Uint8List? bytes,
    String extension = 'png',
    String description = '',
    double size = 48,
    double mass = 10,
    Offset hang = const Offset(0.5, 0),
  }) {
    directory.createSync(recursive: true);
    final id = 'mine_${_randomHex(8)}';
    assert((png ?? bytes) != null, 'the artwork is needed');
    File('${directory.path}${Platform.pathSeparator}$id.$extension')
        .writeAsBytesSync((png ?? bytes)!, flush: true);
    final charm = Charm(
      id: id,
      name: name.trim().isEmpty ? 'My charm' : name.trim(),
      description: description,
      art: '${Charm.userArtPrefix}$id.$extension',
      size: size,
      mass: mass,
      hang: hang,
    );
    _write([charm, ...load()]);
    return charm;
  }

  /// Removes a charm and its artwork.
  void delete(String id) {
    final all = load();
    for (final charm in all.where((c) => c.id == id)) {
      try {
        fileFor(charm).deleteSync();
      } on FileSystemException {
        // Already gone.
      }
    }
    _write([for (final c in all) if (c.id != id) c]);
  }

  void _write(List<Charm> charms) {
    directory.createSync(recursive: true);
    final temp = File('${_manifest.path}.tmp');
    temp.writeAsStringSync(
        const JsonEncoder.withIndent('  ')
            .convert({'charms': [for (final c in charms) c.toJson()]}),
        flush: true);
    temp.renameSync(_manifest.path);
  }

  static String _randomHex(int bytes) {
    final random = Random.secure();
    return [
      for (var i = 0; i < bytes; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
