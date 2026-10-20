import 'dart:math';

import '../settings/app_settings.dart';

/// Anonymous usage stats: only with the user's consent, and only these few
/// fields.
///
/// This version has no stats server and sends nothing at all. [payload] is
/// exactly what Customize shows under "See what would be shared", and is
/// the most a future sender may send.
abstract final class UsageStats {
  /// The only fields that may ever be shared.
  static const allowedFields = {
    'id',
    'appVersion',
    'os',
    'charm',
    'rope',
    'hangFrom',
  };

  /// A random id that says nothing about the person or the computer.
  static String newId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// Makes the stats id follow consent: one is made when sharing is turned
  /// on, and deleted when it is turned off.
  static AppSettings withConsentApplied(AppSettings settings,
      {String Function() newId = UsageStats.newId}) {
    if (settings.shareStats && settings.statsId.isEmpty) {
      return settings.copyWith(statsId: newId());
    }
    if (!settings.shareStats && settings.statsId.isNotEmpty) {
      return settings.copyWith(statsId: '');
    }
    return settings;
  }

  /// What would be shared, or null when the user hasn't agreed.
  static Map<String, Object?>? payload(
    AppSettings settings, {
    required String appVersion,
    required String os,
  }) {
    if (!settings.shareStats || settings.statsId.isEmpty) return null;
    return {
      'id': settings.statsId,
      'appVersion': appVersion,
      'os': os,
      'charm': settings.charmId,
      'rope': settings.ropeStyleId,
      'hangFrom': settings.followWindow ? 'window' : 'screen',
    };
  }
}
