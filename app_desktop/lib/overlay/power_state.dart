/// What the computer says about power and motion, asked of Windows now and
/// then.
class PowerState {
  const PowerState({
    this.onBattery = false,
    this.batterySaver = false,
    this.reduceMotion = false,
  });

  /// Running on battery rather than plugged in.
  final bool onBattery;

  /// Windows' own Battery Saver is on.
  final bool batterySaver;

  /// "Show animations in Windows" is off.
  final bool reduceMotion;

  /// Reads the native answer: `[onBattery, batterySaver, reduceMotion]`.
  /// Anything else means nothing is known, which counts as plugged in with
  /// motion allowed.
  factory PowerState.fromChannel(Object? value) {
    if (value is! List || value.length != 3) return const PowerState();
    bool flag(Object? v) => v is bool && v;
    return PowerState(
      onBattery: flag(value[0]),
      batterySaver: flag(value[1]),
      reduceMotion: flag(value[2]),
    );
  }

  /// Whether to draw fewer frames: on battery or in Battery Saver.
  bool get lowPower => onBattery || batterySaver;

  @override
  bool operator ==(Object other) =>
      other is PowerState &&
      other.onBattery == onBattery &&
      other.batterySaver == batterySaver &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(onBattery, batterySaver, reduceMotion);
}
