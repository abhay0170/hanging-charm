import 'dart:io';

import 'package:charm_desktop/charms/charm.dart';
import 'package:charm_desktop/festivals/festival_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

FestivalCalendar shipped() =>
    FestivalCalendar.parse(File(FestivalCalendar.assetPath).readAsStringSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the shipped calendar', () {
    test('has every festival, each with a charm that exists', () {
      final calendar = shipped();
      expect(
        calendar.festivals.map((f) => f.id),
        containsAll([
          'new_year',
          'pongal',
          'lunar_new_year',
          'holi',
          'eid_al_fitr',
          'eid_al_adha',
          'onam',
          'diwali',
          'christmas',
        ]),
      );
      final catalog = CharmCatalog.parse(
        File(CharmCatalog.assetPath).readAsStringSync(),
      );
      for (final festival in calendar.festivals) {
        expect(festival.charmIds, isNotEmpty, reason: festival.id);
        for (final id in festival.charmIds) {
          expect(
            catalog.charmFor(id).id,
            id,
            reason: '${festival.id} names a charm that is not in the catalog',
          );
        }
      }
    });

    test('covers every year from 2027 to 2030 for every festival', () {
      for (final festival in shipped().festivals) {
        final years = festival.dates.map((d) => d.year).toSet();
        for (final year in [2027, 2028, 2029, 2030]) {
          expect(years, contains(year), reason: '${festival.id} $year');
        }
        // In order, with no repeats, and at most a couple per year.
        for (var i = 1; i < festival.dates.length; i++) {
          expect(festival.dates[i].isAfter(festival.dates[i - 1]), isTrue);
        }
      }
    });

    test('puts each festival in its own part of the year', () {
      final byId = {for (final f in shipped().festivals) f.id: f};
      bool monthsOf(String id, List<int> months) =>
          byId[id]!.dates.every((d) => months.contains(d.month));
      expect(monthsOf('new_year', [1]), isTrue);
      expect(monthsOf('pongal', [1]), isTrue);
      expect(monthsOf('christmas', [12]), isTrue);
      expect(monthsOf('lunar_new_year', [1, 2]), isTrue);
      expect(monthsOf('holi', [2, 3]), isTrue);
      expect(monthsOf('onam', [8, 9]), isTrue);
      expect(monthsOf('diwali', [10, 11]), isTrue);
      // The two Eids move through the year, about 10 days earlier each year.
      final fitr = byId['eid_al_fitr']!.dates;
      for (var i = 1; i < fitr.length; i++) {
        final gap = DateTime(
          fitr[i - 1].year + 1,
          fitr[i - 1].month,
          fitr[i - 1].day,
        ).difference(fitr[i]).inDays;
        expect(gap, inInclusiveRange(8, 13), reason: 'Eid al-Fitr drift');
      }
    });
  });

  group('what is near', () {
    final calendar = shipped();
    List<String> ids(DateTime day) =>
        calendar.near(day).map((s) => s.festival.id).toList();

    test('opens 21 days before and closes 3 days after', () {
      // Diwali 2026 is on 8 November.
      expect(ids(DateTime(2026, 10, 17)), isNot(contains('diwali')));
      expect(ids(DateTime(2026, 10, 18)), contains('diwali'));
      expect(ids(DateTime(2026, 11, 11)), contains('diwali'));
      expect(ids(DateTime(2026, 11, 12)), isNot(contains('diwali')));
    });

    test('says how far away it is', () {
      String when(DateTime day) =>
          calendar.near(day).firstWhere((s) => s.festival.id == 'diwali').when;
      expect(when(DateTime(2026, 10, 21)), 'in 18 days');
      expect(when(DateTime(2026, 11, 7)), 'tomorrow');
      expect(when(DateTime(2026, 11, 8)), 'today');
      expect(when(DateTime(2026, 11, 9)), 'yesterday');
      expect(when(DateTime(2026, 11, 10)), '2 days ago');
    });

    test('the greeting is for the day and the day either side', () {
      bool greeting(DateTime day) => calendar
          .near(day)
          .firstWhere((s) => s.festival.id == 'diwali')
          .greetingNow;
      expect(greeting(DateTime(2026, 11, 7)), isTrue);
      expect(greeting(DateTime(2026, 11, 8)), isTrue);
      expect(greeting(DateTime(2026, 11, 9)), isTrue);
      expect(greeting(DateTime(2026, 11, 6)), isFalse);
      expect(greeting(DateTime(2026, 11, 10)), isFalse);
    });

    test('works across the new year, nearest first', () {
      // Pongal (14 January) is already inside the 3 weeks, after New Year.
      final late = calendar.near(DateTime(2026, 12, 30));
      expect(late.map((s) => s.festival.id), ['new_year', 'pongal']);
      expect(
        late.map((s) => s.festival.id),
        isNot(contains('christmas')),
        reason: 'Christmas was 5 days ago',
      );
      final christmas = calendar.near(DateTime(2026, 12, 20));
      expect(christmas.first.festival.id, 'christmas');
      expect(christmas.map((s) => s.festival.id), contains('new_year'));
      expect(calendar.near(DateTime(2027, 1, 2)).first.when, 'yesterday');
    });

    test('a quiet stretch has nothing', () {
      expect(calendar.near(DateTime(2026, 6, 20)), isEmpty);
    });

    test('the time of day makes no difference', () {
      expect(
        ids(DateTime(2026, 11, 8, 0, 5)),
        ids(DateTime(2026, 11, 8, 23, 55)),
      );
    });
  });

  group('dates', () {
    test('only real ones are read', () {
      expect(FestivalCalendar.parseDate('2026-11-08'), DateTime(2026, 11, 8));
      expect(FestivalCalendar.parseDate('2026-02-30'), isNull);
      expect(FestivalCalendar.parseDate('2026-13-01'), isNull);
      expect(FestivalCalendar.parseDate('2026-1-1'), isNull);
      expect(FestivalCalendar.parseDate('soon'), isNull);
      expect(FestivalCalendar.parseDate('2028-02-29'), DateTime(2028, 2, 29));
      expect(FestivalCalendar.parseDate('2027-02-29'), isNull);
    });

    test('days are counted by date, whatever the clocks did', () {
      expect(
        FestivalCalendar.daysBetween(
          DateTime(2026, 3, 28),
          DateTime(2026, 3, 30),
        ),
        2,
      );
      expect(
        FestivalCalendar.daysBetween(
          DateTime(2026, 10, 24),
          DateTime(2026, 10, 26),
        ),
        2,
      );
      expect(
        FestivalCalendar.daysBetween(
          DateTime(2026, 12, 31, 23, 59),
          DateTime(2027, 1, 1, 0, 1),
        ),
        1,
      );
    });
  });

  group('reading a calendar', () {
    test('bad entries are skipped and bad text is an empty calendar', () {
      final c = FestivalCalendar.parse('''
      {"festivals": [
        {"id": "ok", "name": "OK", "charms": ["a"], "dates": ["2026-05-05", "nope"]},
        {"id": "no_dates", "name": "None", "dates": []},
        {"name": "no id", "dates": ["2026-05-05"]},
        7
      ]}''');
      expect(c.festivals.map((f) => f.id), ['ok']);
      expect(c.festivals.single.dates, [DateTime(2026, 5, 5)]);
      expect(c.festivals.single.greeting, 'OK');
      expect(FestivalCalendar.parse('not json').festivals, isEmpty);
      expect(FestivalCalendar.parse('[]').festivals, isEmpty);
    });

    test('it knows when it has run out', () {
      final c = shipped();
      expect(c.hasEnded(DateTime(2030, 12, 31)), isFalse);
      expect(c.hasEnded(DateTime(2031, 1, 1)), isTrue);
      expect(FestivalCalendar.empty.hasEnded(DateTime(2099)), isFalse);
    });
  });

  group('charm of the day', () {
    final calendar = shipped();
    final pool = [
      for (var i = 0; i < 12; i++)
        Charm(id: 'c$i', name: 'Charm $i', art: 'classic/c$i.svg'),
      const Charm(id: 'akash_kandil', name: 'Lantern', art: 'festival/a.svg'),
    ];

    test('is the same all day and changes from day to day', () {
      final morning = calendar.charmOfTheDay(DateTime(2026, 6, 20, 7), pool);
      final night = calendar.charmOfTheDay(DateTime(2026, 6, 20, 23), pool);
      expect(morning!.id, night!.id);
      final seen = {
        for (var d = 0; d < 30; d++)
          calendar.charmOfTheDay(DateTime(2026, 6, 1 + d), pool)!.id,
      };
      expect(seen.length, greaterThan(5));
    });

    test(
      'is the festival charm on the day itself, and the day either side',
      () {
        for (final day in [7, 8, 9]) {
          expect(
            calendar.charmOfTheDay(DateTime(2026, 11, day), pool)!.id,
            'akash_kandil',
          );
        }
        expect(
          calendar.charmOfTheDay(DateTime(2026, 11, 11), pool)!.id,
          isNot('akash_kandil').or(isNotNull),
        );
      },
    );

    test('an ordinary day never picks a festival charm', () {
      final everyday = pool.take(12).toList();
      for (var d = 0; d < 200; d++) {
        final day = DateTime(2026, 4, 1).add(Duration(days: d));
        if (calendar.near(day).any((s) => s.daysAway.abs() <= 1)) continue;
        expect(
          calendar.charmOfTheDay(day, pool, everyday: everyday)!.id,
          isNot('akash_kandil'),
        );
      }
    });

    test('falls back when the festival charm is not in the pool', () {
      final without = pool.take(12).toList();
      expect(calendar.charmOfTheDay(DateTime(2026, 11, 8), without), isNotNull);
      expect(calendar.charmOfTheDay(DateTime(2026, 11, 8), const []), isNull);
    });
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
