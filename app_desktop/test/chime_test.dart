import 'dart:math' as math;
import 'dart:typed_data';

import 'package:charm_desktop/overlay/chime.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> samplesOf(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  return [
    for (var i = 44; i + 1 < wav.length; i += 2) data.getInt16(i, Endian.little),
  ];
}

/// How strongly [samples] contain [frequency] (Goertzel).
double energyAt(List<int> samples, double frequency) {
  final w = 2 * math.pi * frequency / Chime.sampleRate;
  final coeff = 2 * math.cos(w);
  var s1 = 0.0, s2 = 0.0;
  for (final x in samples) {
    final s = x + coeff * s1 - s2;
    s2 = s1;
    s1 = s;
  }
  return s1 * s1 + s2 * s2 - coeff * s1 * s2;
}

void main() {
  test('it is a well-formed 16-bit mono WAV of the right length', () {
    final wav = Chime.wav(1318.5, 1);
    final data = ByteData.sublistView(wav);
    String text(int at) => String.fromCharCodes(wav.sublist(at, at + 4));
    expect(text(0), 'RIFF');
    expect(text(8), 'WAVE');
    expect(text(12), 'fmt ');
    expect(text(36), 'data');
    expect(data.getUint16(20, Endian.little), 1, reason: 'PCM');
    expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(data.getUint32(24, Endian.little), Chime.sampleRate);
    expect(data.getUint16(34, Endian.little), 16);
    final frames = (Chime.sampleRate * Chime.length).round();
    expect(data.getUint32(40, Endian.little), frames * 2);
    expect(data.getUint32(4, Endian.little), wav.length - 8);
    expect(wav.length, 44 + frames * 2);
  });

  test('the loudest sample follows the volume and never clips', () {
    int peak(double v) =>
        samplesOf(Chime.wav(1046.5, v)).map((s) => s.abs()).reduce(math.max);
    expect(peak(1), inInclusiveRange(0.79 * 32767, 0.81 * 32767));
    expect(peak(0.5), closeTo(peak(1) / 2, 40));
    expect(peak(0), 0);
    expect(peak(7), peak(1), reason: 'volume is capped at 1');
    expect(peak(-1), 0);
  });

  test('it starts and ends quietly: no click, and it dies away', () {
    final s = samplesOf(Chime.wav(1568, 1));
    expect(s.first.abs(), lessThan(300));
    final tail = s.sublist(s.length - 2000).map((x) => x.abs()).reduce(math.max);
    expect(tail, lessThan(0.02 * 32767));
  });

  test('it rings at the pitch asked for', () {
    final s = samplesOf(Chime.wav(1318.5, 1)).sublist(0, 6000);
    final at = energyAt(s, 1318.5);
    expect(at, greaterThan(20 * energyAt(s, 1318.5 * 1.5)));
    expect(at, greaterThan(20 * energyAt(s, 1318.5 * 0.66)));
  });

  test('a harder strike is louder, within limits', () {
    expect(Chime.strength(0), 0.25);
    expect(Chime.strength(100), 0.25);
    expect(Chime.strength(400), 0.5);
    expect(Chime.strength(5000), 1);
  });

  test('heavy charms ring an octave lower, and every pick is a real note', () {
    for (var pick = 0; pick < 12; pick++) {
      final light = Chime.pitch(8, pick);
      final heavy = Chime.pitch(25, pick);
      expect(Chime.notes, contains(light));
      expect(heavy, closeTo(light / 2, 1e-9));
    }
    expect(Chime.pitch(17.9, 0), Chime.notes[0]);
    expect(Chime.pitch(18, 0), Chime.notes[0] / 2);
  });
}
