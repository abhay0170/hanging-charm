import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/widgets.dart';

import '../overlay/charm_painter.dart';

/// A still picture of the charm hanging on [style], drawn by the same
/// painter as the real one, scaled to fit.
class RopePreview extends StatefulWidget {
  const RopePreview({super.key, required this.style});

  final RopeStyle style;

  @override
  State<RopePreview> createState() => _RopePreviewState();
}

class _RopePreviewState extends State<RopePreview> {
  static const Size _area = Size(240, 236);

  final _repaint = ValueNotifier<int>(0);
  CharmSprite? _sprite;
  late RopeSim _sim = _simFor(widget.style);

  static RopeSim _simFor(RopeStyle style) =>
      RopeSim(style: style, anchorX: _area.width / 2, anchorY: 6);

  @override
  void didUpdateWidget(RopePreview old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style) _sim = _simFor(widget.style);
  }

  @override
  void dispose() {
    _sprite?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = View.of(context).devicePixelRatio;
    if (_sprite?.devicePixelRatio != dpr) {
      _sprite?.dispose();
      _sprite = CharmSprite(dpr);
    }
    return FittedBox(
      child: SizedBox.fromSize(
        size: _area,
        child: CustomPaint(
            painter: CharmPainter(_sim, _sprite!, repaint: _repaint)),
      ),
    );
  }
}
