import 'dart:math' as math;
import 'dart:typed_data';

/// The little bell sound the charm can make, built from numbers: a few
/// partials of a struck bell, each fading at its own speed. No sound files,
/// nothing downloaded, and the sound is made fresh at the volume asked for.
class Chime {
  const Chime._();

  static const int sampleRate = 22050;

  /// How long the sound rings, in seconds.
  static const double length = 1.1;

  /// The notes, a pentatonic scale (any two sound fine together), in Hz.
  static const List<double> notes = [
    1046.5, // C6
    1174.7, // D6
    1318.5, // E6
    1568.0, // G6
    1760.0, // A6
  ];

  // A bell's partials aren't whole multiples of its pitch, which is what
  // makes it sound like metal rather than a flute.
  static const _ratios = [1.0, 2.76, 5.4, 8.93];
  static const _levels = [1.0, 0.5, 0.25, 0.12];
  static const _ringSeconds = [0.28, 0.16, 0.1, 0.05];

  /// The last stretch fades smoothly to nothing, so the sound can't end
  /// with a click.
  static const double _fadeOut = 0.25;

  /// How loud a strike at [speed] (logical pixels per second) is, 0.25 to 1.
  static double strength(double speed) => (speed / 800).clamp(0.25, 1.0);

  /// The note for a charm of [mass] (3 to 30): heavier charms ring an octave
  /// lower. [pick] chooses among the five notes, so the same charm doesn't
  /// ring the same note every time.
  static double pitch(double mass, int pick) {
    final note = notes[pick % notes.length];
    return mass >= 18 ? note / 2 : note;
  }

  /// A WAV file (16-bit mono) of one strike at [frequency] Hz, at [volume]
  /// (0 to 1) of the loudest the app plays.
  static Uint8List wav(double frequency, double volume) {
    final count = (sampleRate * length).round();
    // Peak at 0.8 of full scale, so the loudest never clips.
    final gain = 0.8 * volume.clamp(0.0, 1.0) * 32767;
    final out = ByteData(44 + count * 2);

    void text(int at, String s) {
      for (var i = 0; i < s.length; i++) {
        out.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    out.setUint32(4, 36 + count * 2, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little); // PCM
    out.setUint16(22, 1, Endian.little); // mono
    out.setUint32(24, sampleRate, Endian.little);
    out.setUint32(28, sampleRate * 2, Endian.little);
    out.setUint16(32, 2, Endian.little);
    out.setUint16(34, 16, Endian.little);
    text(36, 'data');
    out.setUint32(40, count * 2, Endian.little);

    // Add up the partials, then scale so the loudest moment is the gain.
    final samples = Float64List(count);
    var peak = 0.0;
    for (var n = 0; n < count; n++) {
      final t = n / sampleRate;
      var sum = 0.0;
      for (var p = 0; p < _ratios.length; p++) {
        final f = frequency * _ratios[p];
        if (f > sampleRate / 2.2) continue;
        sum += _levels[p] *
            math.exp(-t / _ringSeconds[p]) *
            math.sin(2 * math.pi * f * t);
      }
      // A 3 ms rise, so the strike doesn't click, and a fade at the end.
      sum *= math.min(1.0, t / 0.003);
      final left = length - t;
      if (left < _fadeOut) {
        sum *= 0.5 - 0.5 * math.cos(math.pi * left / _fadeOut);
      }
      samples[n] = sum;
      peak = math.max(peak, sum.abs());
    }
    final scale = peak == 0 ? 0.0 : gain / peak;
    for (var n = 0; n < count; n++) {
      out.setInt16(44 + n * 2, (samples[n] * scale).round(), Endian.little);
    }
    return out.buffer.asUint8List();
  }
}
