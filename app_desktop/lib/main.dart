import 'package:flutter/widgets.dart';

import 'overlay/charm_overlay.dart';

void main() {
  runApp(const CharmApp());
}

/// No MaterialApp: the window must stay fully transparent apart from what
/// the overlay paints.
class CharmApp extends StatelessWidget {
  const CharmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: TextStyle(fontFamily: 'Segoe UI'),
        child: CharmOverlay(),
      ),
    );
  }
}
