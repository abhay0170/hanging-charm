import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_settings.dart';

/// Holds the current settings, tells listeners when they change, and keeps
/// `settings.json` up to date.
///
/// Writes are batched: a burst of changes (dragging the pin) becomes one
/// write half a second after the last of them. Each write goes to a
/// temporary file first and then replaces the real one, so a crash
/// mid-write never leaves a half-written file behind.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this.file, this._value);

  static const Duration saveDelay = Duration(milliseconds: 500);

  final File file;
  AppSettings _value;
  Timer? _saveTimer;

  AppSettings get value => _value;

  /// Reads [directory]/settings.json, or starts from defaults when it is
  /// missing or unreadable.
  static Future<SettingsStore> open(Directory directory) async {
    final file = File('${directory.path}${Platform.pathSeparator}settings.json');
    var value = const AppSettings();
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, Object?>) value = AppSettings.fromJson(json);
    } on Object {
      // Missing or damaged: keep the defaults. The next save replaces it.
    }
    return SettingsStore._(file, value);
  }

  /// The usual place for this app's settings on each platform.
  static Directory defaultDirectory() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return Directory('${env['APPDATA']}\\Charm');
    }
    if (Platform.isMacOS) {
      return Directory(
          '${env['HOME']}/Library/Application Support/Charm');
    }
    final config = env['XDG_CONFIG_HOME'] ?? '${env['HOME']}/.config';
    return Directory('$config/charm');
  }

  void update(AppSettings Function(AppSettings current) change) {
    final next = change(_value);
    if (next == _value) return;
    _value = next;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, save);
  }

  /// Writes now. Call before quitting so nothing waiting is lost.
  Future<void> save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_value.toJson()),
        flush: true);
    await temp.rename(file.path);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
