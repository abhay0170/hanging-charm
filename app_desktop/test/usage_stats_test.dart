import 'package:charm_desktop/privacy/usage_stats.dart';
import 'package:charm_desktop/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('off by default: no id and nothing to share', () {
    const s = AppSettings();
    expect(s.shareStats, isFalse);
    expect(s.statsId, isEmpty);
    expect(UsageStats.payload(s, appVersion: '1', os: 'windows'), isNull);
  });

  test('turning sharing on makes a random id; it stays the same after', () {
    final on = UsageStats.withConsentApplied(
        const AppSettings().copyWith(shareStats: true));
    expect(on.statsId, matches(RegExp(r'^[0-9a-f]{32}$')));
    final later = UsageStats.withConsentApplied(on.copyWith(charmId: 'star'));
    expect(later.statsId, on.statsId);
    expect(UsageStats.newId(), isNot(on.statsId));
  });

  test('turning sharing off deletes the id', () {
    final on = UsageStats.withConsentApplied(
        const AppSettings().copyWith(shareStats: true));
    final off = UsageStats.withConsentApplied(on.copyWith(shareStats: false));
    expect(off.statsId, isEmpty);
    expect(UsageStats.payload(off, appVersion: '1', os: 'windows'), isNull);
  });

  test('an id saved without consent is dropped when the file is read', () {
    final s = AppSettings.fromJson({'shareStats': false, 'statsId': 'abc'});
    expect(s.statsId, isEmpty);
  });

  test('shares only the allowed fields, and nothing personal', () {
    final s = UsageStats.withConsentApplied(const AppSettings().copyWith(
        shareStats: true, charmId: 'horseshoe', followWindow: false));
    final payload = UsageStats.payload(s, appVersion: '0.1.0', os: 'windows')!;
    expect(payload.keys.toSet(), UsageStats.allowedFields);
    expect(payload['charm'], 'horseshoe');
    expect(payload['hangFrom'], 'screen');
    expect(payload['id'], s.statsId);
  });

  test('the welcome is remembered once shown', () {
    final s = AppSettings.fromJson({'welcomeCompleted': true});
    expect(s.welcomeCompleted, isTrue);
    expect(AppSettings.fromJson({}).welcomeCompleted, isFalse);
  });
}
