import 'dart:ui' as ui;

import 'package:charm_desktop/charms/photo_charm.dart';
import 'package:charm_desktop/charms/text_charm.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('knows Tamil, Hindi and English', () {
    expect(NameCharmDesign.scriptOf('அம்மா'), NameScript.tamil);
    expect(NameCharmDesign.scriptOf('माँ'), NameScript.devanagari);
    expect(NameCharmDesign.scriptOf('Abhay'), NameScript.latin);
    expect(NameCharmDesign.scriptOf('  2026 ♥ '), NameScript.other);
  });

  test('Hindi and Tamil are set in a font that shapes them', () {
    for (final text in ['अमृता', 'தமிழ்']) {
      expect(NameCharmDesign(text: text).fontFamilies.first, 'Nirmala UI');
    }
    expect(
        const NameCharmDesign(text: 'Rex', font: NameFont.script)
            .fontFamilies
            .first,
        'Segoe Script');
  });

  test('trims, and cuts long text by letters, not code units', () {
    expect(const NameCharmDesign(text: '  Rex  ').displayText, 'Rex');
    final long = NameCharmDesign(text: 'தமிழ்' * 10).displayText;
    expect(long.characters.length, NameCharmDesign.maxLength);
  });

  test('the text fits its plate or tag, however long the name', () {
    for (final shape in NameShape.values) {
      for (final text in ['A', 'Grandma', 'Supercalifragi']) {
        final d = NameCharmDesign(text: text, shape: shape);
        final painter = d.layoutText(Paint());
        expect(painter.width, lessThanOrEqualTo(d.textArea.width + 0.5),
            reason: '$shape "$text"');
        expect(painter.height, lessThanOrEqualTo(d.textArea.height + 0.5),
            reason: '$shape "$text"');
        painter.dispose();
      }
    }
  });

  test('renders a PNG of the right size with something drawn on it',
      () async {
    for (final shape in NameShape.values) {
      final d = NameCharmDesign(
          text: 'Rex', shape: shape, finish: FrameFinish.roseGold);
      final png = await d.renderPng(width: 200);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 200);
      expect(image.height, (200 * d.artBox.height / d.artBox.width).round());
      final bytes = (await image.toByteData())!;
      var drawn = 0;
      for (var i = 3; i < bytes.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) > 0) drawn++;
      }
      expect(drawn, greaterThan(200), reason: '$shape is blank');
    }
  });
}
