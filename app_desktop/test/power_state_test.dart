import 'package:charm_desktop/overlay/power_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the native answer', () {
    final p = PowerState.fromChannel([true, false, true]);
    expect(p.onBattery, isTrue);
    expect(p.batterySaver, isFalse);
    expect(p.reduceMotion, isTrue);
    expect(p.lowPower, isTrue);
  });

  test('either battery or Battery Saver means low power; plugged in does not',
      () {
    expect(PowerState.fromChannel([true, false, false]).lowPower, isTrue);
    expect(PowerState.fromChannel([false, true, false]).lowPower, isTrue);
    expect(PowerState.fromChannel([false, false, false]).lowPower, isFalse);
    // Reduced motion alone is not low power.
    expect(PowerState.fromChannel([false, false, true]).lowPower, isFalse);
  });

  test('an unknown or odd answer means plugged in with motion allowed', () {
    for (final odd in [null, 'x', 3, <Object?>[], [true], [1, 2, 3]]) {
      expect(PowerState.fromChannel(odd), const PowerState(), reason: '$odd');
    }
  });

  test('equal states compare equal', () {
    expect(PowerState.fromChannel([true, false, true]),
        PowerState.fromChannel([true, false, true]));
    expect(PowerState.fromChannel([true, false, true]),
        isNot(PowerState.fromChannel([true, false, false])));
  });
}
