import 'dart:typed_data';

import 'dart:convert';

import 'package:flutter/services.dart';
import 'power_state.dart';

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
  OverlayChannel({
    this.onCursorNear,
    this.onCursorAway,
    this.onAnchorMoved,
    this.onTrayCommand,
    this.onCustomizeMessage,
    this.onVisibility,
    this.onCursorMoved,
  }) {
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

  /// Something was picked from the tray menu: `toggleVisible`,
  /// `toggleFollow` or `quit`. (Launch at login is handled natively.)
  final void Function(String command)? onTrayCommand;

  /// A message from the Customize window (see `customize/protocol.dart`).
  final void Function(Map<String, Object?> message)? onCustomizeMessage;

  /// The charm's window was shown or hidden (by the user, or because a
  /// full-screen window is in front).
  final void Function(bool visible)? onVisibility;

  /// The cursor moved to this point in the charm window's coordinates (it
  /// may be outside the window). Only sent after [setCursorStream] is on.
  final void Function(Offset cursor)? onCursorMoved;

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

  /// Starts or stops the stream of cursor positions ([onCursorMoved]).
  Future<void> setCursorStream(bool on) => _call('setCursorStream', on);

  /// Battery and motion settings of the computer.
  Future<PowerState> getPowerState() async =>
      PowerState.fromChannel(await _call('getPowerState'));

  /// Shows or hides the charm (a full-screen app hides it regardless).
  Future<void> setCharmVisible(bool visible) =>
      _call('setCharmVisible', visible);

  /// Where along a window's and the screen's top edge the pin sits (0..1).
  Future<(double, double)?> getAnchorFractions() async {
    final values = await _call('getAnchorFractions');
    if (values is! List || values.length != 2) return null;
    return (
      (values[0] as num).toDouble(),
      (values[1] as num).toDouble(),
    );
  }

  Future<void> setAnchorFractions(double window, double screen) =>
      _call('setAnchorFractions', Float64List.fromList([window, screen]));

  /// Opens the Customize window, or brings it to the front.
  Future<void> openCustomize() => _call('openCustomize');

  /// Opens the first-launch welcome (the Customize window in welcome mode).
  Future<void> openWelcome() => _call('openWelcome');

  /// Sends [message] to the Customize window, if it is open. It runs in a
  /// separate process, so messages travel as JSON.
  Future<void> toCustomize(Map<String, Object?> message) =>
      _call('toCustomize', jsonEncode(message));

  /// Whether the app starts when the user signs in.
  Future<bool> getLaunchAtLogin() async =>
      await _call('getLaunchAtLogin') == true;

  /// Returns false if the system refused.
  Future<bool> setLaunchAtLogin(bool enabled) async =>
      await _call('setLaunchAtLogin', enabled) == true;

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
      case 'trayCommand':
        onTrayCommand?.call(call.arguments as String);
      case 'fromCustomize':
        final json = call.arguments;
        if (json is! String) return null;
        final message = jsonDecode(json);
        if (message is Map) {
          onCustomizeMessage?.call(message.cast<String, Object?>());
        }
      case 'cursorMoved':
        final point = call.arguments as List<Object?>;
        onCursorMoved?.call(Offset(
            (point[0]! as num).toDouble(), (point[1]! as num).toDouble()));
      case 'visibility':
        onVisibility?.call(call.arguments as bool);
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
