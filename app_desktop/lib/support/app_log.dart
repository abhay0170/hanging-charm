import 'dart:io';

import '../settings/settings_store.dart';

/// A small plain-text log next to the settings (`charm.log`), for problems
/// that would otherwise pass silently, such as artwork that fails to load.
/// It never grows past about 256 KB: when full it starts over.
abstract final class AppLog {
  static const int _maxBytes = 256 * 1024;

  static File get file => File(
      '${SettingsStore.defaultDirectory().path}${Platform.pathSeparator}charm.log');

  static void error(String what, Object error, [StackTrace? stack]) {
    try {
      final f = file;
      f.parent.createSync(recursive: true);
      final tooBig = f.existsSync() && f.lengthSync() > _maxBytes;
      final entry = '${DateTime.now().toIso8601String()} $what: $error\n'
          '${stack == null ? '' : '$stack\n'}';
      f.writeAsStringSync(entry,
          mode: tooBig ? FileMode.write : FileMode.append, flush: true);
    } on Object {
      // Logging must never be the thing that breaks the app.
    }
  }
}
