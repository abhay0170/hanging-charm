import 'package:charm_desktop/charms/charm.dart';
import 'package:charm_desktop/customize/customize_channel.dart';
import 'package:charm_desktop/customize/glass.dart';
import 'package:charm_desktop/customize/library_page.dart';
import 'package:charm_desktop/festivals/festival_calendar.dart';
import 'package:charm_desktop/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalogJson = '''
{"collections": [
  {"id": "classic", "name": "Classic", "description": "", "charms": [
    {"id": "gold_bead", "name": "Gold bead", "art": "builtin:gold_bead"},
    {"id": "star", "name": "Star", "description": "Lucky and light.", "art": "classic/star.svg"}
  ]},
  {"id": "luck", "name": "Luck", "description": "", "charms": [
    {"id": "clover", "name": "Four-leaf clover", "art": "luck/clover.svg"}
  ]}
]}''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CustomizeChannel channel;
  final sent = <MethodCall>[];

  setUp(() {
    sent.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('charm/customize'), (
          call,
        ) async {
          sent.add(call);
          return true;
        });
    channel = CustomizeChannel()..settings.value = const AppSettings();
  });

  Future<void> show(WidgetTester tester, {AppSettings? settings}) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: Glass.theme(),
        themeMode: ThemeMode.dark,
        builder: (context, c) => GlassBackground(child: c!),
        home: Scaffold(
          body: LibraryPage(
            settings: settings ?? const AppSettings(),
            catalog: CharmCatalog.parse(_catalogJson),
            festivals: FestivalCalendar.empty,
            channel: channel,
            onNewFromPhoto: () {},
            onNewAnimated: () {},
            onNewLocket: () {},
            onNewFromName: () {},
            onDesign: () {},
            onDelete: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists every charm, with a tile to make a new one', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('Gold bead'), findsOneWidget);
    expect(find.text('Star'), findsOneWidget);
    expect(find.text('Four-leaf clover'), findsOneWidget);
    expect(find.text('New charm'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('a filter shows one collection and hides the new-charm tile', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Luck'));
    await tester.pump();
    expect(find.text('Four-leaf clover'), findsOneWidget);
    expect(find.text('Star'), findsNothing);
    expect(find.text('New charm'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pump();
    expect(find.text('Star'), findsOneWidget);
  });

  testWidgets('search narrows the grid, by name or description, and says '
      'when nothing matches', (tester) async {
    await show(tester);
    await tester.enterText(find.byType(TextField), 'STA');
    await tester.pump();
    expect(find.text('Star'), findsOneWidget);
    expect(find.text('Gold bead'), findsNothing);
    expect(find.text('New charm'), findsNothing);

    await tester.enterText(find.byType(TextField), 'lucky');
    await tester.pump();
    expect(
      find.text('Star'),
      findsOneWidget,
      reason: 'matches its description',
    );

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.textContaining('No charm matches'), findsOneWidget);
  });

  testWidgets('pressing a charm hangs it', (tester) async {
    await show(tester);
    await tester.tap(find.text('Star'));
    await tester.pump();
    expect(channel.settings.value!.charmId, 'star');
    expect(sent.any((c) => c.arguments.toString().contains('star')), isTrue);
  });

  testWidgets('the chosen charm is marked, and an unknown one means the bead', (
    tester,
  ) async {
    await show(tester, settings: const AppSettings(charmId: 'star'));
    expect(find.byIcon(Icons.check), findsOneWidget);
    await show(tester, settings: const AppSettings(charmId: 'long_gone'));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('the new-charm tile offers the five ways to make one', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('New charm'));
    await tester.pumpAndSettle();
    for (final way in [
      'From a photo',
      'From a name',
      'A locket',
      'Animated',
      'Design your own',
    ]) {
      expect(find.text(way), findsOneWidget, reason: way);
    }
  });
}
