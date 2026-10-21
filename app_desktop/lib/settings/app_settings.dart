import 'package:charm_physics/charm_physics.dart';

/// Which edge of the screen the charm hangs from when it is not hanging from
/// a window: from the top, or beside the left or right edge.
enum ScreenEdge { top, left, right }

/// Everything the app remembers between launches.
///
/// Launch at login is not here: the operating system's own startup list is
/// the only record of it, so the two can never disagree.
class AppSettings {
  const AppSettings({
    this.charmId = 'gold_bead',
    this.ropeStyleId = 'thread',
    this.followWindow = true,
    this.charmVisible = true,
    this.animateCharms = true,
    this.reactToWiggle = false,
    this.savePower = true,
    this.soundVolume = 0,
    this.breeze = 0,
    this.screenEdge = ScreenEdge.top,
    this.sideAnchorFraction = 0.2,
    this.extraCharmIds = const [],
    this.windowAnchorFraction = defaultAnchorFraction,
    this.screenAnchorFraction = defaultAnchorFraction,
    this.welcomeCompleted = false,
    this.shareStats = false,
    this.statsId = '',
  });

  /// Bumped when the file's meaning changes, so an older app can tell.
  static const int version = 1;

  /// Where along an edge the pin sits by default, 0 = left, 1 = right.
  static const double defaultAnchorFraction = 0.72;

  /// Which charm hangs, by its catalog id. One that is no longer in the
  /// catalog shows as the gold bead.
  final String charmId;

  final String ropeStyleId;

  /// Hang from the active window (true) or the top of the screen.
  final bool followWindow;

  /// Shown, or hidden from the tray menu.
  final bool charmVisible;

  /// Whether animated charms play. Off, they show their first frame and
  /// cost nothing more than a still charm.
  final bool animateCharms;

  /// Whether shaking the mouse makes the charm sway a little. Off unless
  /// asked for, since it means watching where the cursor goes.
  final bool reactToWiggle;

  /// Draw fewer frames and pause animated charms while on battery or in
  /// Windows' Battery Saver.
  final bool savePower;

  /// How loud the chime is, 0 to 1. 0 is off, which is how it starts: a
  /// sound from the desktop should be something you asked for.
  final double soundVolume;

  /// How strong the breeze is, 0 to 1: 0 is none (how it starts), 1 sways the
  /// rope about 10 degrees at most. It blows on the local clock, not from
  /// the weather: no internet and no location.
  final double breeze;

  /// The screen edge it hangs from when not hanging from a window.
  final ScreenEdge screenEdge;

  /// How far down a side edge the pin sits (0 top, 1 bottom).
  final double sideAnchorFraction;

  /// More charms on the same rope, besides [charmId]; at most [maxExtras].
  final List<String> extraCharmIds;

  static const int maxExtras = 2;

  static List<String> _limited(List<String> ids) =>
      List.unmodifiable(ids.take(maxExtras));

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// How far along a window's top edge the pin sits, set by dragging it.
  final double windowAnchorFraction;

  /// How far along the screen's top edge the pin sits.
  final double screenAnchorFraction;

  /// The welcome has been shown (it is shown once, on first launch).
  final bool welcomeCompleted;

  /// The user agreed to share anonymous usage stats. Off unless they turn
  /// it on.
  final bool shareStats;

  /// A random id for those stats, made only when [shareStats] is turned on
  /// and deleted when it is turned off. Empty otherwise.
  final String statsId;

  RopeStyle get ropeStyle => RopeStyle.all.firstWhere(
        (s) => s.id == ropeStyleId,
        orElse: () => RopeStyle.thread,
      );

  AppSettings copyWith({
    String? charmId,
    String? ropeStyleId,
    bool? followWindow,
    bool? charmVisible,
    bool? animateCharms,
    bool? reactToWiggle,
    bool? savePower,
    double? soundVolume,
    double? breeze,
    ScreenEdge? screenEdge,
    double? sideAnchorFraction,
    List<String>? extraCharmIds,
    double? windowAnchorFraction,
    double? screenAnchorFraction,
    bool? welcomeCompleted,
    bool? shareStats,
    String? statsId,
  }) {
    return AppSettings(
      charmId: charmId ?? this.charmId,
      ropeStyleId: ropeStyleId ?? this.ropeStyleId,
      followWindow: followWindow ?? this.followWindow,
      charmVisible: charmVisible ?? this.charmVisible,
      animateCharms: animateCharms ?? this.animateCharms,
      reactToWiggle: reactToWiggle ?? this.reactToWiggle,
      savePower: savePower ?? this.savePower,
      soundVolume: (soundVolume ?? this.soundVolume).clamp(0.0, 1.0).toDouble(),
      breeze: (breeze ?? this.breeze).clamp(0.0, 1.0).toDouble(),
      screenEdge: screenEdge ?? this.screenEdge,
      sideAnchorFraction:
          (sideAnchorFraction ?? this.sideAnchorFraction).clamp(0.0, 1.0).toDouble(),
      extraCharmIds: _limited(extraCharmIds ?? this.extraCharmIds),
      windowAnchorFraction: windowAnchorFraction ?? this.windowAnchorFraction,
      screenAnchorFraction: screenAnchorFraction ?? this.screenAnchorFraction,
      welcomeCompleted: welcomeCompleted ?? this.welcomeCompleted,
      shareStats: shareStats ?? this.shareStats,
      statsId: statsId ?? this.statsId,
    );
  }

  Map<String, Object?> toJson() => {
        'version': version,
        'charm': charmId,
        'ropeStyle': ropeStyleId,
        'followWindow': followWindow,
        'charmVisible': charmVisible,
        'animateCharms': animateCharms,
        'reactToWiggle': reactToWiggle,
        'savePower': savePower,
        'soundVolume': soundVolume,
        'breeze': breeze,
        'screenEdge': screenEdge.name,
        'sideAnchorFraction': sideAnchorFraction,
        'extraCharms': extraCharmIds,
        'windowAnchorFraction': windowAnchorFraction,
        'screenAnchorFraction': screenAnchorFraction,
        'welcomeCompleted': welcomeCompleted,
        'shareStats': shareStats,
        'statsId': statsId,
      };

  /// Reads what it can. A missing, mistyped or out-of-range value falls back
  /// to its default instead of failing the whole file, and an unknown rope
  /// (say, from a newer version) becomes the thread.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const d = AppSettings();
    T read<T>(String key, T fallback) {
      final value = json[key];
      return value is T ? value : fallback;
    }

    double fraction(String key, double fallback) {
      final value = json[key];
      if (value is! num || !value.isFinite) return fallback;
      return value.toDouble().clamp(0.0, 1.0);
    }

    final ropeId = read<String>('ropeStyle', d.ropeStyleId);
    final charmId = read<String>('charm', d.charmId);
    final shareStats = read<bool>('shareStats', d.shareStats);
    return AppSettings(
      charmId: charmId.isEmpty ? d.charmId : charmId,
      ropeStyleId: RopeStyle.all.any((s) => s.id == ropeId)
          ? ropeId
          : d.ropeStyleId,
      followWindow: read<bool>('followWindow', d.followWindow),
      charmVisible: read<bool>('charmVisible', d.charmVisible),
      animateCharms: read<bool>('animateCharms', d.animateCharms),
      reactToWiggle: read<bool>('reactToWiggle', d.reactToWiggle),
      savePower: read<bool>('savePower', d.savePower),
      soundVolume: fraction('soundVolume', d.soundVolume),
      breeze: fraction('breeze', d.breeze),
      screenEdge: ScreenEdge.values.firstWhere(
        (e) => e.name == json['screenEdge'],
        orElse: () => d.screenEdge,
      ),
      sideAnchorFraction: fraction('sideAnchorFraction', d.sideAnchorFraction),
      extraCharmIds: _limited([
        if (json['extraCharms'] case final List list)
          for (final id in list)
            if (id is String && id.isNotEmpty) id,
      ]),
      windowAnchorFraction:
          fraction('windowAnchorFraction', d.windowAnchorFraction),
      screenAnchorFraction:
          fraction('screenAnchorFraction', d.screenAnchorFraction),
      welcomeCompleted: read<bool>('welcomeCompleted', d.welcomeCompleted),
      shareStats: shareStats,
      // An id without consent is never kept.
      statsId: shareStats ? read<String>('statsId', d.statsId) : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.charmId == charmId &&
      other.ropeStyleId == ropeStyleId &&
      other.followWindow == followWindow &&
      other.charmVisible == charmVisible &&
      other.animateCharms == animateCharms &&
      other.reactToWiggle == reactToWiggle &&
      other.savePower == savePower &&
      other.soundVolume == soundVolume &&
      other.breeze == breeze &&
      other.screenEdge == screenEdge &&
      other.sideAnchorFraction == sideAnchorFraction &&
      _sameIds(other.extraCharmIds, extraCharmIds) &&
      other.windowAnchorFraction == windowAnchorFraction &&
      other.screenAnchorFraction == screenAnchorFraction &&
      other.welcomeCompleted == welcomeCompleted &&
      other.shareStats == shareStats &&
      other.statsId == statsId;

  @override
  int get hashCode => Object.hash(
      charmId,
      ropeStyleId,
      followWindow,
      charmVisible,
      animateCharms,
      reactToWiggle,
      savePower,
      soundVolume,
      breeze,
      screenEdge,
      sideAnchorFraction,
      Object.hashAll(extraCharmIds),
      windowAnchorFraction,
      screenAnchorFraction,
      welcomeCompleted,
      shareStats,
      statsId);
}
