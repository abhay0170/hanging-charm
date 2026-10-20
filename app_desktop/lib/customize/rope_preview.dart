import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/widgets.dart';

import '../charms/charm.dart';
import '../charms/charm_sprite.dart';
import '../overlay/charm_painter.dart';

/// Loads [charm]'s sprite at this screen's density and rebuilds when it is
/// ready, showing the bead until then.
mixin _CharmSpriteLoader<T extends StatefulWidget> on State<T> {
  CharmSprite? sprite;
  Charm? _loading;
  double? _dpr;

  Charm get charm;

  CharmSprite spriteFor(BuildContext context) {
    final dpr = View.of(context).devicePixelRatio;
    if (_dpr != dpr || _loading?.id != charm.id) {
      _dpr = dpr;
      final wanted = _loading = charm;
      sprite ??= CharmSprite.goldBead(dpr);
      CharmSprite.load(wanted, dpr).then((loaded) {
        if (mounted && _loading?.id == wanted.id) {
          setState(() => sprite = loaded);
        }
      });
    }
    return sprite!;
  }
}

/// A still picture of [charm] hanging on [style], drawn by the same painter
/// as the real one, scaled to fit.
class RopePreview extends StatefulWidget {
  const RopePreview({super.key, required this.style, required this.charm});

  final RopeStyle style;
  final Charm charm;

  @override
  State<RopePreview> createState() => _RopePreviewState();
}

class _RopePreviewState extends State<RopePreview>
    with _CharmSpriteLoader<RopePreview> {
  static const Size _area = Size(240, 236);

  final _repaint = ValueNotifier<int>(0);
  late RopeSim _sim = _simFor(widget.style);

  @override
  Charm get charm => widget.charm;

  static RopeSim _simFor(RopeStyle style) =>
      RopeSim(style: style, anchorX: _area.width / 2, anchorY: 6);

  @override
  void didUpdateWidget(RopePreview old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style) _sim = _simFor(widget.style);
  }

  @override
  void dispose() {
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sprite = spriteFor(context);
    return FittedBox(
      child: SizedBox.fromSize(
        size: _area,
        child: CustomPaint(
            painter: CharmPainter(_sim, sprite, repaint: _repaint)),
      ),
    );
  }
}

/// [charm]'s artwork on its own, scaled to fit.
class CharmArt extends StatefulWidget {
  const CharmArt({super.key, required this.charm});

  final Charm charm;

  @override
  State<CharmArt> createState() => _CharmArtState();
}

class _CharmArtState extends State<CharmArt>
    with _CharmSpriteLoader<CharmArt> {
  @override
  Charm get charm => widget.charm;

  @override
  Widget build(BuildContext context) {
    final sprite = spriteFor(context);
    return FittedBox(
      child: RawImage(
        image: sprite.image,
        scale: sprite.devicePixelRatio,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
