import 'package:flutter/widgets.dart';

import 'overlay/charm_overlay.dart';
import 'settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.open(SettingsStore.defaultDirectory());
  runApp(CharmApp(settings: settings));
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
