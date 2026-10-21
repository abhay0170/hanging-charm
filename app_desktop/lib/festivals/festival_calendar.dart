import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../charms/charm.dart';

/// A festival: its name, a greeting, the charms made for it, and the days it
/// falls on in the years the calendar covers.
class Festival {
  const Festival({
    required this.id,
    required this.name,
    required this.greeting,
    required this.charmIds,
    required this.dates,
  });

  final String id;
  final String name;
  final String greeting;
  final List<String> charmIds;

  /// Sorted, date only (midnight).
  final List<DateTime> dates;

  static Festival? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    final greeting = json['greeting'];
    final charms = json['charms'];
    final dates = <DateTime>[];
    if (json['dates'] case final List list) {
      for (final entry in list) {
        if (entry is! String) continue;
        final date = FestivalCalendar.parseDate(entry);
        if (date != null) dates.add(date);
      }
    }
    dates.sort();
    if (dates.isEmpty) return null;
    return Festival(
      id: id,
      name: name,
      greeting: greeting is String && greeting.isNotEmpty ? greeting : name,
      charmIds: [
        if (charms is List)
          for (final c in charms)
            if (c is String && c.isNotEmpty) c,
      ],
      dates: dates,
    );
  }
}

/// A festival that is near: coming up, today, or only just over.
class FestivalSeason {
  const FestivalSeason(this.festival, this.date, this.daysAway);

  final Festival festival;
  final DateTime date;

  /// Days until it (0 on the day itself, negative once it has passed).
  final int daysAway;

  /// "today", "tomorrow", "in 18 days", "yesterday", "2 days ago".
  String get when => switch (daysAway) {
        0 => 'today',
        1 => 'tomorrow',
        -1 => 'yesterday',
        > 1 => 'in $daysAway days',
        _ => '${-daysAway} days ago',
      };

  /// The greeting is for the day itself and a day either side of it.
  bool get greetingNow => daysAway.abs() <= 1;
}

/// The festivals shipped with the app, which work offline. It knows which
/// are near on a given day and picks a charm for the day.
class FestivalCalendar {
  const FestivalCalendar(this.festivals, {this.firstYear, this.lastYear});

  static const assetPath = 'assets/festivals/festivals.json';

  /// How early the shelf opens, and how long it stays after the day.
  static const int lookAheadDays = 21;
  static const int lookBackDays = 3;

  final List<Festival> festivals;

  /// The years the dates cover.
  final int? firstYear, lastYear;

  static const empty = FestivalCalendar([]);

  /// Reads a calendar; anything unusable is skipped, and unreadable text
  /// gives an empty calendar rather than an error.
  static FestivalCalendar parse(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map) return empty;
      final list = json['festivals'];
      final festivals = [
        if (list is List)
          for (final entry in list) ?Festival.fromJson(entry),
      ];
      final coverage = json['coverage'];
      return FestivalCalendar(
        festivals,
        firstYear: coverage is Map && coverage['from'] is int
            ? coverage['from'] as int
            : null,
        lastYear: coverage is Map && coverage['to'] is int
            ? coverage['to'] as int
            : null,
      );
    } on Object {
      return empty;
    }
  }

  static Future<FestivalCalendar> load(AssetBundle bundle) async {
    try {
      return parse(await bundle.loadString(assetPath));
    } on Object {
      return empty;
    }
  }

  /// Parses `yyyy-mm-dd` into a date, or null if it isn't a real one.
  static DateTime? parseDate(String text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    // 31 February would roll over to March: not a real date.
    return date.year == y && date.month == mo && date.day == d ? date : null;
  }

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Whole days from [from] to [to], by calendar date (so daylight-saving
  /// changes can't make a day 23 or 25 hours long).
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  /// The festivals near [today]: up to [lookAheadDays] ahead and
  /// [lookBackDays] behind, nearest first. Each festival is listed once, at
  /// its closest date.
  List<FestivalSeason> near(DateTime today) {
    final out = <FestivalSeason>[];
    for (final festival in festivals) {
      FestivalSeason? best;
      for (final date in festival.dates) {
        final days = daysBetween(today, date);
        if (days < -lookBackDays || days > lookAheadDays) continue;
        if (best == null || days.abs() < best.daysAway.abs()) {
          best = FestivalSeason(festival, date, days);
        }
      }
      if (best != null) out.add(best);
    }
    out.sort((a, b) => a.daysAway.abs().compareTo(b.daysAway.abs()));
    return out;
  }

  /// Whether the calendar has run out: [today] is past the last year it
  /// covers, so no festival can be shown until the app is updated.
  bool hasEnded(DateTime today) =>
      lastYear != null && today.year > lastYear!;

  /// A different charm each day, the same one all day. During a festival it
  /// is that festival's own charm instead. [pool] holds every charm that may
  /// be picked; [everyday], if given, is the smaller set an ordinary day
  /// picks from (so a Christmas bauble isn't "today's charm" in June).
  Charm? charmOfTheDay(DateTime today, List<Charm> pool,
      {List<Charm>? everyday}) {
    if (pool.isEmpty) return null;
    final byId = {for (final c in pool) c.id: c};
    for (final season in near(today)) {
      if (season.daysAway.abs() > 1) continue;
      for (final id in season.festival.charmIds) {
        if (byId[id] case final charm?) return charm;
      }
    }
    final from = everyday == null || everyday.isEmpty ? pool : everyday;
    final day = daysBetween(DateTime(2020), _dateOnly(today));
    return from[math.Random(day).nextInt(from.length)];
  }
}
