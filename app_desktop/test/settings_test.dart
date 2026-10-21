import 'dart:convert';
import 'dart:io';

import 'package:charm_desktop/settings/app_settings.dart';
import 'package:charm_desktop/settings/settings_store.dart';
import 'package:charm_physics/charm_physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('charm_settings_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File settingsFile() => File('${dir.path}${Platform.pathSeparator}settings.json');

  test('starts from defaults when there is no file', () async {
    final store = await SettingsStore.open(dir);
    expect(store.value, const AppSettings());
    expect(store.value.ropeStyle, RopeStyle.thread);
    expect(store.value.followWindow, isTrue);
    expect(store.value.charmVisible, isTrue);
    expect(store.value.animateCharms, isTrue);
    expect(store.value.reactToWiggle, isFalse);
    expect(store.value.savePower, isTrue);
    expect(store.value.soundVolume, 0);
    expect(store.value.breeze, 0);
    expect(store.value.screenEdge, ScreenEdge.top);
    expect(store.value.extraCharmIds, isEmpty);
  });

  test('saves and reads back every setting', () async {
    final store = await SettingsStore.open(dir);
    store.update((s) => s.copyWith(
          charmId: 'horseshoe',
          ropeStyleId: 'gold_chain',
          followWindow: false,
          charmVisible: false,
          animateCharms: false,
          reactToWiggle: true,
          savePower: false,
          soundVolume: 0.6,
          breeze: 0.66,
          screenEdge: ScreenEdge.right,
          sideAnchorFraction: 0.4,
          extraCharmIds: ['star', 'heart'],
          windowAnchorFraction: 0.31,
          screenAnchorFraction: 0.9,
        ));
    await store.save();

    final again = await SettingsStore.open(dir);
    expect(again.value, store.value);
    expect(again.value.ropeStyle, RopeStyle.goldChain);
    expect(again.value.animateCharms, isFalse);
    expect(again.value.reactToWiggle, isTrue);
    expect(again.value.savePower, isFalse);
    expect(again.value.soundVolume, 0.6);
    expect(again.value.breeze, 0.66);
    expect(again.value.screenEdge, ScreenEdge.right);
    expect(again.value.sideAnchorFraction, 0.4);
    expect(again.value.extraCharmIds, ['star', 'heart']);
  });

  test('a burst of changes becomes one write after a pause', () async {
    final store = await SettingsStore.open(dir);
    for (var i = 0; i < 20; i++) {
      store.update((s) => s.copyWith(screenAnchorFraction: i / 20));
    }
    expect(settingsFile().existsSync(), isFalse);
    await Future<void>.delayed(
        SettingsStore.saveDelay + const Duration(milliseconds: 300));
    final json = jsonDecode(settingsFile().readAsStringSync()) as Map;
    expect(json['screenAnchorFraction'], 19 / 20);
  });

  test('a damaged file falls back to defaults instead of failing', () async {
    settingsFile().writeAsStringSync('{ this is not json');
    final store = await SettingsStore.open(dir);
    expect(store.value, const AppSettings());
  });

  test('bad or unknown values fall back one by one', () async {
    settingsFile().writeAsStringSync(jsonEncode({
      'version': 99,
      'ropeStyle': 'rainbow_unicorn',
      'followWindow': 'yes',
      'charmVisible': false,
      'windowAnchorFraction': 7,
      'screenAnchorFraction': 0.25,
    }));
    final store = await SettingsStore.open(dir);
    expect(store.value.ropeStyleId, 'thread');
    expect(store.value.followWindow, isTrue);
    expect(store.value.charmVisible, isFalse);
    expect(store.value.windowAnchorFraction, 1.0);
    expect(store.value.screenAnchorFraction, 0.25);
  });

  test('listeners hear about real changes only', () async {
    final store = await SettingsStore.open(dir);
    var calls = 0;
    store.addListener(() => calls++);
    store.update((s) => s.copyWith(followWindow: true)); // already true
    store.update((s) => s.copyWith(followWindow: false));
    expect(calls, 1);
    store.dispose();
  });

  test('extra charms are kept in order, at most four, strings only', () {
    final s = AppSettings.fromJson({
      'extraCharms': ['a', 7, '', 'b', null, 'c', 'd', 'e', 'f'],
    });
    expect(s.extraCharmIds, ['a', 'b', 'c', 'd']);
    expect(AppSettings.fromJson({'extraCharms': 'nope'}).extraCharmIds,
        isEmpty);
    expect(const AppSettings().copyWith(extraCharmIds: ['1', '2', '3', '4', '5'])
        .extraCharmIds, hasLength(4));
    expect(AppSettings.fromJson({'extraCharms': ['a']}),
        AppSettings.fromJson({'extraCharms': ['a']}));
    expect(AppSettings.fromJson({'extraCharms': ['a']}),
        isNot(AppSettings.fromJson({'extraCharms': ['b']})));
  });

  test('breeze is a fraction and starts off', () {
    expect(const AppSettings().breeze, 0);
    expect(AppSettings.fromJson({'breeze': 5}).breeze, 1);
    expect(AppSettings.fromJson({'breeze': -2}).breeze, 0);
    expect(AppSettings.fromJson({'breeze': 'x'}).breeze, 0);
  });
}
