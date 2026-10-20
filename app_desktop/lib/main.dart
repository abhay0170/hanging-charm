import 'package:flutter/widgets.dart';

import 'customize/customize_app.dart';
import 'customize/customize_channel.dart';
import 'overlay/charm_overlay.dart';
import 'settings/settings_store.dart';

/// The charm overlay: the app's main engine, always running.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.open(SettingsStore.defaultDirectory());
  runApp(CharmApp(settings: settings));
}

/// The Customize window: the app started with `--customize`, a separate
/// process that lives only while the window is open
/// (`windows/runner/main.cpp`).
@pragma('vm:entry-point')
void customizeMain() {
  WidgetsFlutterBinding.ensureInitialized();
  final channel = CustomizeChannel();
  runApp(CustomizeApp(channel: channel));
  channel.hello();
}

/// No MaterialApp: the window must stay fully transparent apart from what
/// the overlay paints.
class CharmApp extends StatelessWidget {
  const CharmApp({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Segoe UI'),
        child: CharmOverlay(settings: settings),
      ),
    );
  }
}
