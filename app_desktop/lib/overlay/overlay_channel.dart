import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Talks to the native overlay window (windows/runner/flutter_window.cpp).
///
/// Dart tells the window where the clickable parts are ([setHitRects]); the
/// native side makes everything else click-through on its own and reports
/// the cursor only while it is near one of them ([onCursorNear]), so a
/// resting charm costs Dart nothing.
///
/// Only Windows implements it so far. Elsewhere every call is a no-op and
/// the app runs without click-through.
class OverlayChannel {
  OverlayChannel({this.onCursorNear, this.onCursorAway, this.onAnchorMoved}) {
    _channel.setMethodCallHandler(_handle);
  }

  static const _channel = MethodChannel('charm/overlay');

  /// The cursor moved within reach of a hit rect, in logical pixels.
  final void Function(Offset cursor)? onCursorNear;

  /// The cursor left the area around every hit rect.
  final void Function()? onCursorAway;

  /// The window the charm hangs from moved, and the overlay moved with it by
  /// this many logical pixels. The rope should swing.
  final void Function(Offset delta)? onAnchorMoved;

  bool _supported = true;
  List<Rect> _sentRects = const [];
  bool _holding = false;

  /// Sets the only areas that take clicks. Skips the call when nothing has
  /// moved by half a pixel or more.
  Future<void> setHitRects(List<Rect> rects) async {
    if (_sameRects(rects, _sentRects)) return;
    _sentRects = rects;
    final flat = Float64List(rects.length * 4);
    for (var i = 0; i < rects.length; i++) {
      flat
        ..[i * 4] = rects[i].left
        ..[i * 4 + 1] = rects[i].top
        ..[i * 4 + 2] = rects[i].right
        ..[i * 4 + 3] = rects[i].bottom;
    }
    await _call('setHitRects', flat);
  }

  /// Keeps the window taking clicks (during a drag) even off the hit rects.
  Future<void> holdInteractive(bool hold) async {
    if (hold == _holding) return;
    _holding = hold;
    await _call('holdInteractive', hold);
  }

  /// Slides the window sideways by [dx] logical pixels. Returns how far it
  /// actually moved (less at a screen edge), or null when the platform
  /// cannot move it.
  Future<double?> moveBy(double dx) async {
    final applied = await _call('moveBy', dx);
    return applied is num ? applied.toDouble() : null;
  }

  /// Hang from the active window (true) or the top of the screen (false).
  Future<void> setFollowActive(bool follow) => _call('setFollowActive', follow);

  Future<void> quit() async {
    await _call('quit');
    if (!_supported) SystemNavigator.pop();
  }

  Future<Object?> _handle(MethodCall call) async {
    switch (call.method) {
      case 'cursorNear':
        final point = call.arguments as List<Object?>;
        onCursorNear?.call(Offset(
            (point[0]! as num).toDouble(), (point[1]! as num).toDouble()));
      case 'cursorAway':
        onCursorAway?.call();
      case 'anchorMoved':
        final delta = call.arguments as List<Object?>;
        onAnchorMoved?.call(Offset(
            (delta[0]! as num).toDouble(), (delta[1]! as num).toDouble()));
    }
    return null;
  }

  Future<Object?> _call(String method, [Object? args]) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      _supported = false;
      return null;
    }
  }

  static bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].left - b[i].left).abs() >= 0.5 ||
          (a[i].top - b[i].top).abs() >= 0.5 ||
          (a[i].right - b[i].right).abs() >= 0.5 ||
          (a[i].bottom - b[i].bottom).abs() >= 0.5) {
        return false;
      }
    }
    return true;
  }
}
