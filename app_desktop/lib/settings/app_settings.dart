import 'package:charm_physics/charm_physics.dart';

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
      windowAnchorFraction,
      screenAnchorFraction,
      welcomeCompleted,
      shareStats,
      statsId);
}
