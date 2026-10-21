import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'charms/charm.dart';
import 'customize/customize_app.dart';
import 'customize/customize_channel.dart';
import 'festivals/festival_calendar.dart';
import 'overlay/charm_overlay.dart';
import 'settings/settings_store.dart';

/// The charm overlay: the app's main engine, always running.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.open(SettingsStore.defaultDirectory());
  final catalog = await CharmCatalog.load(rootBundle);
  runApp(CharmApp(settings: settings, catalog: catalog));
}

/// The Customize window: the app started with `--customize`, a separate
/// process that lives only while the window is open
/// (`windows/runner/main.cpp`).
/// With `--welcome` it shows the first-launch welcome instead.
@pragma('vm:entry-point')
Future<void> customizeMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final channel = CustomizeChannel();
  final catalog = await CharmCatalog.load(rootBundle);
  final festivals = await FestivalCalendar.load(rootBundle);
  runApp(CustomizeApp(
    channel: channel,
    catalog: catalog,
    festivals: festivals,
    welcome: args.contains('--welcome'),
  ));
  channel.hello();
}

/// No MaterialApp: the window must stay fully transparent apart from what
/// the overlay paints.
class CharmApp extends StatelessWidget {
  const CharmApp({super.key, required this.settings, required this.catalog});

  final SettingsStore settings;
  final CharmCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Segoe UI'),
        child: CharmOverlay(settings: settings, catalog: catalog),
      ),
    );
  }
}
