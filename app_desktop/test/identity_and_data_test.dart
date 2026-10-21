import 'dart:io';

import 'package:charm_desktop/customize/customize_app.dart';
import 'package:charm_desktop/settings/delete_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the version shown in About is the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(appVersion, version[1]);
  });

  test('the exe carries the app name, not the project name', () {
    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    expect(rc, contains('VALUE "ProductName", "Charm"'));
    expect(rc, contains('VALUE "CompanyName", "Charm"'));
    expect(rc, isNot(contains('VALUE "ProductName", "charm_desktop"')));
    expect(rc, isNot(contains('com.charmapp')));
  });

  test('the app icon holds every size Windows asks for', () {
    final bytes = File('windows/runner/resources/app_icon.ico')
        .readAsBytesSync();
    // ICONDIR: reserved 0, type 1 (icon), then how many pictures.
    expect(bytes[0] | bytes[1] << 8, 0);
    expect(bytes[2] | bytes[3] << 8, 1);
    final count = bytes[4] | bytes[5] << 8;
    final sizes = <int>{
      for (var i = 0; i < count; i++)
        // Width byte of each entry; 0 means 256.
        bytes[6 + i * 16] == 0 ? 256 : bytes[6 + i * 16],
    };
    expect(sizes, containsAll([16, 24, 32, 48, 64, 128, 256]));
  });

  group('deleting all data', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('charm_delete_'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('removes the charms folder and the log, and nothing else', () async {
      final charms = Directory('${dir.path}/charms')..createSync();
      File('${charms.path}/my_charms.json').writeAsStringSync('{}');
      File('${charms.path}/mine_a.png').writeAsBytesSync([1, 2, 3]);
      final log = File('${dir.path}/charm.log')..writeAsStringSync('x');
      final photo = File('${dir.path}/holiday.jpg')..writeAsBytesSync([9]);

      final failed = await deleteUserData(charms: charms, log: log);

      expect(failed, isEmpty);
      expect(charms.existsSync(), isFalse);
      expect(log.existsSync(), isFalse);
      expect(photo.existsSync(), isTrue, reason: 'other files are not touched');
    });

    test('is fine when there is nothing to delete', () async {
      final failed = await deleteUserData(
        charms: Directory('${dir.path}/none'),
        log: File('${dir.path}/none.log'),
      );
      expect(failed, isEmpty);
    });
  });
}
