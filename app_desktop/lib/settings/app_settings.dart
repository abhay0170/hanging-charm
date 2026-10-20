import 'package:charm_physics/charm_physics.dart';

/// Everything the app remembers between launches.
///
/// Launch at login is not here: the operating system's own startup list is
/// the only record of it, so the two can never disagree.
class AppSettings {
  const AppSettings({
    this.ropeStyleId = 'thread',
    this.followWindow = true,
    this.charmVisible = true,
    this.windowAnchorFraction = defaultAnchorFraction,
    this.screenAnchorFraction = defaultAnchorFraction,
  });

  /// Bumped when the file's meaning changes, so an older app can tell.
  static const int version = 1;

  /// Where along an edge the pin sits by default, 0 = left, 1 = right.
  static const double defaultAnchorFraction = 0.72;

  final String ropeStyleId;

  /// Hang from the active window (true) or the top of the screen.
  final bool followWindow;

  /// Shown, or hidden from the tray menu.
  final bool charmVisible;

  /// How far along a window's top edge the pin sits, set by dragging it.
  final double windowAnchorFraction;

  /// How far along the screen's top edge the pin sits.
  final double screenAnchorFraction;

  RopeStyle get ropeStyle => RopeStyle.all.firstWhere(
        (s) => s.id == ropeStyleId,
        orElse: () => RopeStyle.thread,
      );

  AppSettings copyWith({
    String? ropeStyleId,
    bool? followWindow,
    bool? charmVisible,
    double? windowAnchorFraction,
    double? screenAnchorFraction,
  }) {
    return AppSettings(
      ropeStyleId: ropeStyleId ?? this.ropeStyleId,
      followWindow: followWindow ?? this.followWindow,
      charmVisible: charmVisible ?? this.charmVisible,
      windowAnchorFraction: windowAnchorFraction ?? this.windowAnchorFraction,
      screenAnchorFraction: screenAnchorFraction ?? this.screenAnchorFraction,
    );
  }

  Map<String, Object?> toJson() => {
        'version': version,
        'ropeStyle': ropeStyleId,
        'followWindow': followWindow,
        'charmVisible': charmVisible,
        'windowAnchorFraction': windowAnchorFraction,
        'screenAnchorFraction': screenAnchorFraction,
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
    return AppSettings(
      ropeStyleId: RopeStyle.all.any((s) => s.id == ropeId)
          ? ropeId
          : d.ropeStyleId,
      followWindow: read<bool>('followWindow', d.followWindow),
      charmVisible: read<bool>('charmVisible', d.charmVisible),
      windowAnchorFraction:
          fraction('windowAnchorFraction', d.windowAnchorFraction),
      screenAnchorFraction:
          fraction('screenAnchorFraction', d.screenAnchorFraction),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.ropeStyleId == ropeStyleId &&
      other.followWindow == followWindow &&
      other.charmVisible == charmVisible &&
      other.windowAnchorFraction == windowAnchorFraction &&
      other.screenAnchorFraction == screenAnchorFraction;

  @override
  int get hashCode => Object.hash(ropeStyleId, followWindow, charmVisible,
      windowAnchorFraction, screenAnchorFraction);
}
