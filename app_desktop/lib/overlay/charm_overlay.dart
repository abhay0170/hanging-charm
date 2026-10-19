import 'dart:math' as math;

import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'charm_painter.dart';
import 'overlay_channel.dart';

enum _Drag { none, charm, anchor }

/// The full-width transparent strip: one rope with a charm, driven by
/// [RopeSim], clickable only where something is drawn.
///
/// Nothing here runs while the charm is at rest: the frame loop stops when
/// the rope sleeps, and the native window decides click-through by itself.
class CharmOverlay extends StatefulWidget {
  const CharmOverlay({super.key});

  @override
  State<CharmOverlay> createState() => _CharmOverlayState();
}

class _CharmOverlayState extends State<CharmOverlay>
    with SingleTickerProviderStateMixin {
  /// Extra pixels around the charm and pin that still count as a hit.
  static const double _hitSlop = 6;
  static const double _anchorHitRadius = 12;

  /// A cursor sweeping through the charm faster than this knocks it. Only
  /// actual contact counts, and the knock is a share of the cursor's own
  /// speed, so a gentle pass gives a gentle swing.
  static const double _brushSpeed = 250;
  static const double _brushRadius = charmRadius + 2;
  static const double _brushShare = 0.5;

  static const Size _menuSize = Size(150, 146);

  late final _channel = OverlayChannel(
    onCursorNear: _brush,
    onCursorAway: _closeMenu,
  );
  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_onTick);

  RopeSim? _sim;
  Duration? _lastTick;
  Size _size = Size.zero;

  _Drag _drag = _Drag.none;
  Offset _grabOffset = Offset.zero;

  Offset? _lastCursor;
  DateTime _lastCursorTime = DateTime.now();
  DateTime _lastBrush = DateTime.fromMillisecondsSinceEpoch(0);

  Rect? _menuRect;

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  /// The anchor sits at the window's top centre; dragging it moves the
  /// window, not the anchor within it.
  RopeSim _simFor(Size size) {
    // Starts hanging still: every swing comes from the user.
    return _sim ??= RopeSim(anchorX: size.width / 2, anchorY: 0);
  }

  // ---- Dragging the anchor moves the window. ----

  double? _pendingAnchorX;
  bool _moving = false;

  /// Moves the anchor to [x] (window coordinates) by sliding the window,
  /// coalescing pointer moves that arrive while a slide is in flight.
  Future<void> _moveAnchorTo(double x) async {
    _pendingAnchorX = x;
    if (_moving) return;
    _moving = true;
    while (_pendingAnchorX != null) {
      final sim = _sim;
      final target = _pendingAnchorX!;
      _pendingAnchorX = null;
      if (sim == null) break;
      final dx = target - sim.anchorTargetX;
      if (dx.abs() < 0.5) continue;
      final applied = await _channel.moveBy(dx);
      if (applied == null) {
        // No native window to move: slide the anchor inside the window.
        sim.moveAnchor(
            target.clamp(16.0, math.max(16.0, _size.width - 16)).toDouble(),
            sim.anchorY);
      } else {
        // The window moved by [applied]; keep the rope where it was on
        // screen and bring the anchor back to the window's centre, which
        // to the rope is the anchor moving by [applied].
        sim.shiftFrame(-applied, 0);
        sim.moveAnchor(sim.anchorTargetX + applied, sim.anchorTargetY);
      }
      _wake();
    }
    _moving = false;
  }

  // ---- Frame loop: runs only while the rope is awake. ----

  void _wake() {
    _sim?.wake();
    if (!_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final sim = _sim;
    if (sim == null) return;
    final last = _lastTick;
    _lastTick = elapsed;
    if (last != null) {
      sim.step((elapsed - last).inMicroseconds / 1e6);
    }
    _repaint.value++;
    _syncHitRects();
    if (sim.asleep && _drag == _Drag.none) {
      _ticker.stop();
    }
  }

  // ---- Hit testing ----

  Rect? _charmRect() {
    final sim = _sim;
    if (sim == null) return null;
    return Rect.fromCircle(
        center: charmCenter(sim), radius: charmRadius + _hitSlop);
  }

  Rect? _anchorRect() {
    final sim = _sim;
    if (sim == null) return null;
    return Rect.fromCircle(
        center: Offset(sim.anchorX, sim.anchorY + 3), radius: _anchorHitRadius);
  }

  bool _hitsCharm(Offset p) {
    final sim = _sim;
    if (sim == null) return false;
    return (p - charmCenter(sim)).distance <= charmRadius + _hitSlop;
  }

  bool _hitsAnchor(Offset p) => _anchorRect()?.contains(p) ?? false;

  /// Tells the native window which areas take clicks.
  void _syncHitRects() {
    _channel.setHitRects([
      ?_charmRect(),
      ?_anchorRect(),
      ?_menuRect,
    ]);
  }

  // ---- Cursor near the charm (reported by the native window). ----

  /// The cursor sweeping through the charm knocks it the way the cursor was
  /// going, with half the cursor's speed. Cursor samples arrive ~30 ms apart,
  /// so a fast sweep is checked along the whole path between two samples.
  void _brush(Offset cursor) {
    final sim = _sim;
    if (sim == null) return;
    final now = DateTime.now();
    final last = _lastCursor;
    final seconds = now.difference(_lastCursorTime).inMicroseconds / 1e6;
    _lastCursor = cursor;
    _lastCursorTime = now;
    if (last == null || seconds <= 0 || seconds > 0.1) return;
    if (_drag != _Drag.none || _menuRect != null) return;
    if (now.difference(_lastBrush) < const Duration(milliseconds: 200)) return;
    if (_distanceToSegment(charmCenter(sim), last, cursor) > _brushRadius) {
      return;
    }

    final velocity = (cursor - last) / seconds;
    if (velocity.distance < _brushSpeed) return;
    final push = velocity * _brushShare;
    // The charm hangs from above, so a sideways knock moves it far more than
    // an up or down one.
    sim.nudge(push.dx, push.dy * 0.3);
    _lastBrush = now;
    _wake();
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSq == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSq)
        .clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // ---- Pointer input (only arrives while the window is interactive). ----

  void _onPointerDown(PointerDownEvent e) {
    final sim = _sim;
    if (sim == null) return;
    final p = e.localPosition;

    if (_menuRect != null && !_menuRect!.contains(p)) _closeMenu();
    if (e.buttons == kSecondaryMouseButton && _hitsCharm(p)) {
      _openMenu(p);
      return;
    }
    if (e.buttons != kPrimaryMouseButton) return;

    if (_hitsCharm(p)) {
      _drag = _Drag.charm;
      _grabOffset = Offset(sim.charmX, sim.charmY) - p;
      sim.grab(sim.charmX, sim.charmY);
      _channel.holdInteractive(true);
      _wake();
    } else if (_hitsAnchor(p)) {
      _drag = _Drag.anchor;
      _grabOffset = Offset(sim.anchorX - p.dx, 0);
      _channel.holdInteractive(true);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    final sim = _sim;
    if (sim == null) return;
    switch (_drag) {
      case _Drag.charm:
        final target = e.localPosition + _grabOffset;
        sim.dragTo(target.dx, target.dy);
        _wake();
      case _Drag.anchor:
        _moveAnchorTo(e.localPosition.dx + _grabOffset.dx);
      case _Drag.none:
        break;
    }
  }

  void _onPointerUp(PointerEvent e) {
    if (_drag == _Drag.none) return;
    if (_drag == _Drag.charm) _sim?.release();
    _drag = _Drag.none;
    _channel.holdInteractive(false);
    _wake();
  }

  // ---- Right-click menu ----

  void _openMenu(Offset at) {
    var left = at.dx + 24;
    if (left + _menuSize.width > _size.width) {
      left = at.dx - 24 - _menuSize.width;
    }
    final top = (at.dy - 20)
        .clamp(4.0, math.max(4.0, _size.height - _menuSize.height - 4))
        .toDouble();
    setState(() => _menuRect = Offset(left, top) & _menuSize);
    _syncHitRects();
  }

  void _closeMenu() {
    if (_menuRect == null) return;
    setState(() => _menuRect = null);
    _syncHitRects();
  }

  void _setStyle(RopeStyle style) {
    _sim?.style = style;
    _closeMenu();
    _wake();
  }

  Widget _buildMenu() {
    final rect = _menuRect!;
    final current = _sim?.style.id;
    Widget item(String label, VoidCallback onTap, {bool selected = false}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: selected ? const Color(0x33FFFFFF) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFFF5F5F7))),
        ),
      );
    }

    return Positioned.fromRect(
      rect: rect,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xEE1F1F24),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final style in RopeStyle.all)
              item(style.name, () => _setStyle(style),
                  selected: style.id == current),
            item('Quit', _channel.quit),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = constraints.biggest;
      final sim = _simFor(_size);
      if (!_ticker.isActive && !sim.asleep) _wake();
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: CharmPainter(sim, repaint: _repaint),
              ),
            ),
            if (_menuRect != null) _buildMenu(),
          ],
        ),
      );
    });
  }
}
