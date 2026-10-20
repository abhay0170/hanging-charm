import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/app_settings.dart';
import 'protocol.dart';

/// The Customize window's line to the charm, which owns the settings. The
/// charm runs in another process; messages travel as JSON through the
/// native side (windows/runner/app_messages.h).
class CustomizeChannel {
  CustomizeChannel() {
    _channel.setMethodCallHandler(_handle);
  }

  static const _channel = MethodChannel('charm/customize');

  /// The settings as the charm last reported them; null until the first
  /// report arrives.
  final settings = ValueNotifier<AppSettings?>(null);

  /// True when the charm could not be reached (it isn't running).
  final charmMissing = ValueNotifier<bool>(false);

  /// Asks the charm for the current settings.
  Future<void> hello() async {
    final sent =
        await _toCharm({CustomizeProtocol.type: CustomizeProtocol.hello});
    charmMissing.value = !sent;
  }

  /// Changes some settings. Shown here at once; the charm applies, saves
  /// and confirms them.
  Future<void> update(Map<String, Object?> changes) async {
    final current = settings.value;
    if (current != null) {
      settings.value =
          AppSettings.fromJson({...current.toJson(), ...changes});
    }
    final sent = await _toCharm({
      CustomizeProtocol.type: CustomizeProtocol.update,
      CustomizeProtocol.changes: changes,
    });
    if (!sent) charmMissing.value = true;
  }

  Future<bool> getLaunchAtLogin() async =>
      await _channel.invokeMethod<bool>('getLaunchAtLogin') ?? false;

  /// Returns false if Windows refused.
  Future<bool> setLaunchAtLogin(bool enabled) async =>
      await _channel.invokeMethod<bool>('setLaunchAtLogin', enabled) ?? false;

  Future<void> close() => _channel.invokeMethod<void>('close');

  /// False if the charm isn't running.
  Future<bool> _toCharm(Map<String, Object?> message) async =>
      await _channel.invokeMethod<bool>('toCharm', jsonEncode(message)) ??
      false;

  Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'fromCharm') return null;
    final json = call.arguments;
    if (json is! String) return null;
    final message = jsonDecode(json);
    if (message is! Map) return null;
    if (message[CustomizeProtocol.type] != CustomizeProtocol.state) return null;
    final settingsJson = message[CustomizeProtocol.settings];
    if (settingsJson is Map) {
      charmMissing.value = false;
      settings.value =
          AppSettings.fromJson(settingsJson.cast<String, Object?>());
    }
    return null;
  }
}
