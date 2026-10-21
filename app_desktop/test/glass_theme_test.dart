import 'package:charm_desktop/customize/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {double width = 900}) => MaterialApp(
  theme: Glass.theme(),
  themeMode: ThemeMode.dark,
  builder: (context, c) => GlassBackground(child: c!),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  test('the theme is dark with the neon accent', () {
    final theme = Glass.theme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, Glass.neon);
    // Pages draw straight onto the glow, so the scaffold must be clear.
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
  });

  testWidgets('every control in the theme builds without trouble', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: Column(
            children: [
              GlassGroup(
                rows: [
                  GlassRow(
                    title: 'A switch',
                    subtitle: 'With words under it.',
                    trailing: Switch(value: true, onChanged: (_) {}),
                  ),
                  GlassRow(
                    title: 'A slider',
                    wide: true,
                    trailing: SizedBox(
                      width: 200,
                      child: Slider(value: 0.5, onChanged: (_) {}),
                    ),
                  ),
                  GlassRow(
                    title: 'A choice',
                    wide: true,
                    trailing: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('One')),
                        ButtonSegment(value: 2, label: Text('Two')),
                      ],
                      selected: const {1},
                      onSelectionChanged: (_) {},
                    ),
                  ),
                ],
              ),
              const GlassLabel('A heading'),
              Row(
                children: [
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Main action'),
                  ),
                  OutlinedButton(onPressed: () {}, child: const Text('Other')),
                  TextButton(onPressed: () {}, child: const Text('Quiet')),
                  const FilledButton(onPressed: null, child: Text('Off')),
                ],
              ),
              const TextField(decoration: InputDecoration(labelText: 'Name')),
              InputChip(label: const Text('Chip'), onDeleted: () {}),
              const GlassCard(glowing: true, child: Text('A chosen card')),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final label in [
      'A switch',
      'A slider',
      'A choice',
      'Main action',
      'Other',
      'Quiet',
      'Off',
      'A chosen card',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Upper-cased by the heading style.
    expect(find.text('A heading'), findsOneWidget);
  });

  testWidgets('a wide control sits beside its words, or under them when '
      'the window is narrow', (tester) async {
    Future<(Offset, Offset)> place(double width) async {
      await tester.pumpWidget(
        host(
          GlassRow(
            title: 'Chime volume',
            subtitle: 'A soft bell.',
            wide: true,
            trailing: const SizedBox(
              key: Key('control'),
              width: 240,
              height: 30,
            ),
          ),
          width: width,
        ),
      );
      return (
        tester.getTopLeft(find.text('Chime volume')),
        tester.getTopLeft(find.byKey(const Key('control'))),
      );
    }

    final (titleWide, controlWide) = await place(1000);
    expect(controlWide.dx, greaterThan(titleWide.dx + 100));
    expect((controlWide.dy - titleWide.dy).abs(), lessThan(40));

    final (titleNarrow, controlNarrow) = await place(560);
    expect(controlNarrow.dy, greaterThan(titleNarrow.dy + 30));
  });

  testWidgets('a small control never leaves its words', (tester) async {
    await tester.pumpWidget(
      host(
        GlassRow(
          title: 'Show charm',
          subtitle: 'Hide it for a while.',
          trailing: Switch(value: true, onChanged: (_) {}),
        ),
        width: 520,
      ),
    );
    final title = tester.getTopLeft(find.text('Show charm'));
    final control = tester.getCenter(find.byType(Switch));
    expect((control.dy - title.dy).abs(), lessThan(40));
  });
}
