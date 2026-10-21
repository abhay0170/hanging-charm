import 'dart:async';
import 'dart:math' as math;

import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../charms/charm.dart';
import '../charms/charm_sprite.dart';
import '../charms/user_charms.dart';
import '../customize/protocol.dart';
import '../privacy/usage_stats.dart';
import '../settings/app_settings.dart';
import '../support/app_log.dart';
import 'chime.dart';
import 'cluster_layout.dart';
import 'power_state.dart';
import 'wiggle_detector.dart';
import '../settings/settings_store.dart';
import 'charm_painter.dart';
import 'overlay_channel.dart';

enum _Drag { none, charm, anchor }

/// The full-width transparent strip: one rope with a charm, driven by
/// [RopeSim], clickable only where something is drawn.
///
/// Nothing here runs while the charm is at rest: the frame loop stops when
/// the rope sleeps, and the native window decides click-through by itself.
class CharmOverlay extends StatefulWidget {
  const CharmOverlay({
    super.key,
    required this.settings,
    required this.catalog,
  });

  /// What the user chose last time; changes made here are saved back.
  final SettingsStore settings;

  /// Every charm on offer.
  final CharmCatalog catalog;

  @override
  State<CharmOverlay> createState() => _CharmOverlayState();
}

class _CharmOverlayState extends State<CharmOverlay> {
  /// Extra pixels around the charm and pin that still count as a hit.
  static const double _hitSlop = 6;
  static const double _anchorHitRadius = 12;

  /// A cursor sweeping through the charm faster than this knocks it. Only
  /// actual contact counts, and the knock is a share of the cursor's own
  /// speed, so a gentle pass gives a gentle swing.
  static const double _brushSpeed = 250;
  static const double _brushShare = 0.5;

  /// How far from its centre the current charm can be grabbed.
  double get _hitRadius => _sprite?.hitRadius ?? 22;

  /// Customize…, Hang from window, Quit. Ropes are chosen in Customize.
  static const Size _menuSize = Size(160, 106);

  late final _channel = OverlayChannel(
    onCursorNear: _brush,
    onCursorAway: _closeMenu,
    onAnchorMoved: _onAnchorMoved,
    onTrayCommand: _onTrayCommand,
    onCustomizeMessage: _onCustomizeMessage,
    onCursorMoved: _onCursorMoved,
    onVisibility: (visible) {
      _onScreen = visible;
      _animate();
      _applyBreeze();
    },
  );

  /// Benchmark builds (`--dart-define=BENCH_SWING=true`) start the charm
  /// swinging from 35 degrees at the top of the screen, so CPU measurements
  /// see the same swing every run. Normal builds start still.
  static const _benchSwing = bool.fromEnvironment('BENCH_SWING');

  SettingsStore get _settings => widget.settings;

  /// The settings as last applied to the charm and the native window.
  late AppSettings _applied;

  @override
  void initState() {
    super.initState();
    // Put everything back the way the user left it.
    _applied = _settings.value;
    _apply(null, _applied);
    _settings.addListener(_onSettingsChanged);
    _checkPower();
    _powerTimer = Timer.periodic(_powerCheckEvery, (_) => _checkPower());

    // First launch: show the welcome once. It counts as shown from the
    // moment it opens, so closing it early doesn't bring it back each time.
    if (!_settings.value.welcomeCompleted && !_benchSwing) {
      _settings.update((s) => s.copyWith(welcomeCompleted: true));
      _channel.openWelcome();
    }
  }

  /// Every change, whoever made it (tray, charm menu, Customize, dragging the
  /// pin), lands in the store first and is applied here, so they can never
  /// disagree.
  void _onSettingsChanged() {
    final next = _settings.value;
    _apply(_applied, next);
    _applied = next;
    _sendStateToCustomize();
  }

  void _apply(AppSettings? old, AppSettings next) {
    if (old != null && old.charmId != next.charmId) _showCharm(next.charmId);
    if (old?.ropeStyleId != next.ropeStyleId) {
      final sim = _sim;
      if (sim != null) {
        sim.style = next.ropeStyle;
        _wake();
      }
    }
    if (old?.followWindow != next.followWindow) {
      _channel.setFollowActive(!_benchSwing && next.followWindow);
    }
    if (old != null &&
        old.soundVolume != next.soundVolume &&
        next.soundVolume > 0) {
      _lastChimeAt = const Duration(seconds: -10);
      _chime(800); // So you hear how loud it is.
    }
    if (old?.breeze != next.breeze) _applyBreeze();
    if (old == null
        ? next.extraCharmIds.isNotEmpty
        : !listEquals(old.extraCharmIds, next.extraCharmIds)) {
      _showExtras(next.extraCharmIds);
    }
    if (old?.reactToWiggle != next.reactToWiggle) {
      _wiggle = WiggleDetector();
      _channel.setCursorStream(next.reactToWiggle && !_power.reduceMotion);
    }
    if (old?.animateCharms != next.animateCharms ||
        old?.savePower != next.savePower) {
      _animate();
      setState(() {}); // The painter shows one frame or all of them.
    }
    if (old?.charmVisible != next.charmVisible) {
      _channel.setCharmVisible(next.charmVisible);
    }
    if (old?.windowAnchorFraction != next.windowAnchorFraction ||
        old?.screenAnchorFraction != next.screenAnchorFraction ||
        old?.sideAnchorFraction != next.sideAnchorFraction) {
      _channel.setAnchorFractions(next.windowAnchorFraction,
          next.screenAnchorFraction, next.sideAnchorFraction);
    }
    if (old?.screenEdge != next.screenEdge) {
      _channel.setScreenEdge(next.screenEdge.index);
    }
    if (old?.screenEdge != next.screenEdge ||
        old?.followWindow != next.followWindow) {
      _applyWalls();
    }
  }

  /// The built-in charms plus the user's own (made in Customize).
  late CharmCatalog _catalog =
      widget.catalog.withUserCharms(UserCharms.standard().load());

  /// The charm with [id]. One not seen before was probably just made in
  /// Customize, so the user's charms are read again before giving up.
  Charm _charmFor(String id) {
    if (_catalog.charmFor(id).id != id) {
      _catalog = widget.catalog.withUserCharms(UserCharms.standard().load());
    }
    return _catalog.charmFor(id);
  }

  /// The charm the user last asked for; a slower earlier load must not
  /// replace it when it finishes.
  String? _wantedCharm;
  double? _dpr;

  /// Hangs the charm with [id]: its artwork and its weight. The old charm
  /// stays up until the new artwork is ready, so nothing flickers.
  Future<void> _showCharm(String id) async {
    final charm = _charmFor(id);
    _wantedCharm = charm.id;
    final dpr = _dpr;
    if (dpr == null) return; // Before the first build; build asks again.
    final sprite = await CharmSprite.load(charm, dpr);
    if (!mounted || _wantedCharm != charm.id) return;
    _resetLocket();
    setState(() => _sprite = sprite);
    _sim?.charmMass = charm.mass;
    if (_extraSprites.isNotEmpty) _applyExtras();
    _applyWalls();
    _wake();
    _animate();
  }

  // ---- Chime ----
  //
  // A soft bell when the charm is struck: swept by the cursor, let go of with
  // some speed, or a locket opened. Off until a volume is chosen. A strike
  // is louder the harder it is, a heavy charm rings an octave lower, and
  // there is never more than one every quarter of a second.

  static const Duration _chimeGap = Duration(milliseconds: 250);
  Duration _lastChimeAt = const Duration(seconds: -10);
  final _chimeRandom = math.Random();

  void _chime(double speed, {double? mass}) {
    final volume = _settings.value.soundVolume;
    if (volume <= 0) return;
    final now = _clock.elapsed;
    if (now - _lastChimeAt < _chimeGap) return;
    _lastChimeAt = now;
    final note = Chime.pitch(mass ?? _sprite?.charm.mass ?? 12, _chimeRandom.nextInt(Chime.notes.length));
    _channel
        .playSound(Chime.wav(note, volume * Chime.strength(speed)))
        .then((played) {
      if (!played) {
        AppLog.error('Could not play the chime', 'playSound returned false',
            StackTrace.current);
      }
    });
  }

  // ---- More charms on the rope ----
  //
  // Up to two more charms (three in all) hang from the same ring on cords
  // of different lengths, out to either side and each a little lower. They knock together (and chime) and swing apart
  // again, and any of them can be picked up and carried.

  List<CharmSprite> _extraSprites = const [];
  List<String> _extraIds = const [];
  bool _extrasPending = false;

  Future<void> _showExtras(List<String> ids) async {
    _extraIds = ids;
    final dpr = _dpr;
    if (dpr == null) return; // Before the first build; build asks again.
    final sprites = await Future.wait([
      for (final id in ids) CharmSprite.load(_charmFor(id), dpr),
    ]);
    if (!mounted || _extraIds != ids) return;
    setState(() => _extraSprites = sprites);
    _applyExtras();
    _wake();
    _animate();
  }

  /// Gives the simulation the extras' weights, sizes and cord lengths.
  void _applyExtras() {
    final sim = _sim;
    if (sim == null) {
      _extrasPending = true;
      return;
    }
    final main = _sprite;
    final mainHang = (main?.hangOffset.distance ?? 22) + ringRadius;
    // Nearly the artwork's size: the corners of most charms are empty, but
    // the charms themselves must not sit on top of each other.
    final mainRadius = _hitRadius * 0.95;
    final radii = [for (final s in _extraSprites) s.hitRadius * 0.95];
    // Out to alternate sides, each a little lower than the last.
    final reaches = ClusterLayout.reaches(
        mainHang: mainHang, mainRadius: mainRadius, radii: radii);
    sim.setExtras(
      [
        for (var k = 0; k < _extraSprites.length; k++)
          ExtraCharm(
            mass: _extraSprites[k].charm.mass,
            radius: radii[k],
            reach: reaches[k],
          ),
      ],
      primaryRadius: mainRadius,
      primaryHangDistance: mainHang,
    );
  }

  // ---- Breeze ----
  //
  // A slow breeze from the local clock (no weather, no internet, no
  // location) sways the rope both ways, at most about 10 degrees at full
  // strength. Off until chosen, and still while saving power, with Windows
  // animations off, or while the charm is hidden.

  static const double _breezeDegrees = 10;
  static const Duration _breezeDelay = Duration(milliseconds: 50);

  bool get _breezeOn =>
      _settings.value.breeze > 0 &&
      !_saving &&
      !_power.reduceMotion &&
      _onScreen;

  void _syncBreeze(RopeSim sim) {
    final angle =
        _breezeOn ? _settings.value.breeze * _breezeDegrees * math.pi / 180 : 0.0;
    sim.windAngle = angle;
  }

  void _applyBreeze() {
    final sim = _sim;
    if (sim == null) return;
    _syncBreeze(sim);
    if (sim.windAngle > 0) _wake();
  }

  // ---- Power and motion ----
  //
  // On battery (or in Battery Saver) the charm draws about 30 frames a
  // second at most, and animated charms hold still. With Windows'
  // "Show animations" off, animations hold still too, a locket flips at
  // once, and the mouse wiggle is not listened for. Touching the charm
  // always works in full: direct manipulation isn't decoration.

  /// Benchmark builds (`--dart-define=FORCE_POWER_SAVER=true`) behave as if
  /// on battery, so CPU can be measured on a desktop.
  static const _forceSaver = bool.fromEnvironment('FORCE_POWER_SAVER');

  static const Duration _powerCheckEvery = Duration(seconds: 20);

  PowerState _power = const PowerState();
  Timer? _powerTimer;

  bool get _saving =>
      _settings.value.savePower && (_power.lowPower || _forceSaver);

  /// Animated charms play, unless power or motion settings say to hold still.
  bool get _playAnimations =>
      _settings.value.animateCharms && !_saving && !_power.reduceMotion;

  Future<void> _checkPower() async {
    final next = await _channel.getPowerState();
    if (!mounted || next == _power) return;
    final before = (_saving, _power.reduceMotion);
    _power = next;
    _applyMotion(before);
  }

  /// Re-applies whatever depends on the power and motion settings, after
  /// they or the user's own switches changed.
  void _applyMotion((bool saving, bool reduceMotion) before) {
    if (before == (_saving, _power.reduceMotion)) return;
    _animate();
    _applyBreeze();
    _channel.setCursorStream(
        _settings.value.reactToWiggle && !_power.reduceMotion);
    setState(() {});
  }

  // ---- Mouse wiggle ----
  //
  // Shake the mouse and the charm gives a small sway, away from the cursor
  // as if stirred by the air. It is a nudge of at most about 140 px/s, a
  // swing of 8 degrees at most however hard you shake. Only the cursor's
  // sideways position is looked at, and only while this is switched on.

  var _wiggle = WiggleDetector();
  static const double _wiggleSpeed = 60;
  static const double _wiggleExtra = 80;

  void _onCursorMoved(Offset cursor) {
    final sim = _sim;
    if (sim == null) return;
    if (_power.reduceMotion) return;
    final strength = _wiggle.add(_clock.elapsed, cursor.dx);
    if (strength == null) return;
    final away = charmCenter(sim).dx >= cursor.dx ? 1.0 : -1.0;
    sim.nudge(away * (_wiggleSpeed + _wiggleExtra * strength), 0);
    _chime(300 * strength);
    _wake();
  }

  // ---- Lockets ----
  //
  // Tapping a locket turns it over to show the photo inside; tapping again
  // turns it back. It closes by itself after a while, so a photo is never
  // left up on the screen.

  static const Duration _locketTurn = Duration(milliseconds: 260);
  static const Duration _locketStaysOpen = Duration(seconds: 8);

  Offset _downAt = Offset.zero;
  int _dragCharm = 0;
  Duration _downTime = Duration.zero;
  double _travel = 0;

  bool _locketWantsOpen = false;
  double _locketProgress = 0;
  Timer? _locketTimer;
  Timer? _locketCloser;
  Duration _locketLast = Duration.zero;

  void _toggleLocket() {
    if (_sprite?.isLocket != true) return;
    _turnLocket(!_locketWantsOpen);
  }

  void _turnLocket(bool open) {
    if (open) _chime(350);
    _locketWantsOpen = open;
    if (_power.reduceMotion) {
      _locketProgress = open ? 1 : 0;
      _repaint.value++;
    }
    _locketCloser?.cancel();
    _locketCloser = open
        ? Timer(_locketStaysOpen, () => _turnLocket(false))
        : null;
    if (_locketTimer != null || _power.reduceMotion) return;
    _locketLast = _clock.elapsed;
    _locketTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _clock.elapsed;
      final step = (now - _locketLast).inMicroseconds / _locketTurn.inMicroseconds;
      _locketLast = now;
      _locketProgress = (_locketProgress + (_locketWantsOpen ? step : -step))
          .clamp(0.0, 1.0)
          .toDouble();
      _repaint.value++;
      if (_locketProgress == (_locketWantsOpen ? 1 : 0)) {
        _locketTimer?.cancel();
        _locketTimer = null;
      }
    });
  }

  /// A new charm starts closed.
  void _resetLocket() {
    _locketCloser?.cancel();
    _locketCloser = null;
    _locketTimer?.cancel();
    _locketTimer = null;
    _locketWantsOpen = false;
    _locketProgress = 0;
  }

  // ---- Animated charms ----
  //
  // A GIF charm needs a repaint whenever its frame changes, even while the
  // rope sleeps. A timer asks for just those, and only while the charm is
  // on screen; a still charm never starts it.

  bool _onScreen = true;
  Timer? _animationTimer;

  void _animate() {
    _animationTimer?.cancel();
    _animationTimer = null;
    if (!_onScreen || !_playAnimations || !mounted) return;
    // Wake for whichever animated charm changes frame first.
    Duration? soonest;
    for (final s in [?_sprite, ..._extraSprites]) {
      if (!s.isAnimated) continue;
      final next = s.untilNextFrame(CharmSprite.clock.elapsed);
      if (soonest == null || next < soonest) soonest = next;
    }
    if (soonest == null) return;
    _animationTimer = Timer(soonest, () {
      _repaint.value++;
      _animate();
    });
  }

  void _onTrayCommand(String command) {
    switch (command) {
      case 'toggleVisible':
        _settings.update((s) => s.copyWith(charmVisible: !s.charmVisible));
      case 'toggleFollow':
        _settings.update((s) => s.copyWith(followWindow: !s.followWindow));
      case 'quit':
        _quit();
    }
  }

  void _onCustomizeMessage(Map<String, Object?> message) {
    switch (message[CustomizeProtocol.type]) {
      case CustomizeProtocol.hello:
        _sendStateToCustomize();
      case CustomizeProtocol.update:
        final changes = message[CustomizeProtocol.changes];
        if (changes is! Map) return;
        // Through fromJson, so Customize gets the same checks as the file,
        // and the stats id follows consent (made on opt-in, deleted on
        // opt-out). Customize can't set the id itself.
        final incoming = {...changes.cast<String, Object?>()}
          ..remove('statsId');
        _settings.update((s) => UsageStats.withConsentApplied(
            AppSettings.fromJson({...s.toJson(), ...incoming})));
    }
  }

  void _sendStateToCustomize() {
    _channel.toCustomize({
      CustomizeProtocol.type: CustomizeProtocol.state,
      CustomizeProtocol.settings: _settings.value.toJson(),
    });
  }

  /// Saves anything still waiting to be written, then closes the app.
  Future<void> _quit() async {
    await _settings.save();
    await _channel.quit();
  }

  /// Remembers where the pin was left, after dragging it.
  Future<void> _savePinPosition() async {
    final fractions = await _channel.getAnchorFractions();
    if (fractions == null) return;
    _settings.update((s) => s.copyWith(
        windowAnchorFraction: fractions.$1,
        screenAnchorFraction: fractions.$2,
        sideAnchorFraction: fractions.$3));
  }

  /// The window the charm hangs from moved, and this overlay moved with it.
  /// Keep the rope where it was on screen and move the anchor by the same
  /// amount, so the charm swings exactly as much as the window moved.
  void _onAnchorMoved(Offset delta) {
    final sim = _sim;
    if (sim == null) return;
    sim.shiftFrame(-delta.dx, -delta.dy);
    sim.moveAnchor(
        sim.anchorTargetX + delta.dx, sim.anchorTargetY + delta.dy);
    _wake();
  }

  void _setFollowWindow(bool follow) {
    _settings.update((s) => s.copyWith(followWindow: follow));
    _closeMenu();
  }

  void _openCustomize() {
    _closeMenu();
    _channel.openCustomize();
  }

  final _repaint = ValueNotifier<int>(0);
  CharmSprite? _sprite;

  RopeSim? _sim;
  Size _size = Size.zero;

  _Drag _drag = _Drag.none;
  Offset _grabOffset = Offset.zero;

  Offset? _lastCursor;
  DateTime _lastCursorTime = DateTime.now();
  DateTime _lastBrush = DateTime.fromMillisecondsSinceEpoch(0);

  Rect? _menuRect;

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _gentleTimer?.cancel();
    _powerTimer?.cancel();
    _animationTimer?.cancel();
    _locketTimer?.cancel();
    _locketCloser?.cancel();
    final frame = _frameCallbackId;
    if (frame != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(frame);
    }
    _repaint.dispose();
    super.dispose();
  }

  /// The anchor sits at the window's top centre; dragging it moves the
  /// window, not the anchor within it.
  RopeSim _simFor(Size size) {
    // Starts hanging still: every swing comes from the user.
    return _sim ??= RopeSim(
      style: _settings.value.ropeStyle,
      charmMass: _charmFor(_settings.value.charmId).mass,
      anchorX: size.width / 2,
      anchorY: 0,
      startAngle: _benchSwing ? 35 * math.pi / 180 : 0,
    );
  }

  // ---- Hanging beside a screen edge ----
  //
  // Hung from the left or right edge, the pin sits 40 px in from it and
  // slides up and down; the charm and rope stop at the edge of the screen
  // rather than swinging out of sight.

  static const double _sideInset = 40;

  /// Hanging beside an edge (and not from a window).
  bool get _beside =>
      _settings.value.screenEdge != ScreenEdge.top &&
      !_settings.value.followWindow;

  void _applyWalls() {
    final sim = _sim;
    if (sim == null) return;
    if (!_beside) {
      sim.setWalls();
      return;
    }
    final centre = _size.width / 2;
    final left = _settings.value.screenEdge == ScreenEdge.left;
    sim.setWalls(
      left: left ? centre - _sideInset : null,
      right: left ? null : centre + _sideInset,
      charmRadius: _hitRadius * 0.85,
    );
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
      final beside = _beside;
      final dx = target - (beside ? sim.anchorTargetY : sim.anchorTargetX);
      if (dx.abs() < 0.5) continue;
      final applied = await _channel.moveBy(dx);
      if (applied != null && beside) {
        // The window moved down or up by [applied]; the rope stays where it
        // was on screen and the anchor glides back to the window's top.
        sim.shiftFrame(0, -applied);
        sim.moveAnchor(sim.anchorTargetX, sim.anchorTargetY + applied);
      } else if (applied == null) {
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
  //
  // Every frame costs Flutter a few milliseconds whatever is drawn, so the
  // loop asks for frames itself: every display refresh while the charm
  // moves briskly or is being handled, about 30 a second once it has been
  // only gently swaying for a full swing, and none at all once it sleeps.

  /// Below this charm speed (logical px/s) the sway counts as gentle: about
  /// a 10 degree swing.
  static const double _gentleSpeed = 160;

  /// The sway must stay gentle this long (about one full swing) before the
  /// frame rate drops, so the slow ends of a big swing don't count.
  static const Duration _gentleAfter = Duration(milliseconds: 1300);

  /// Wait before asking for the next frame while gentle. The frame then
  /// lands on the following display refresh: about 30 fps on a 60 Hz screen.
  static const Duration _gentleDelay = Duration(milliseconds: 25);

  final _clock = Stopwatch()..start();
  Duration _lastStep = Duration.zero;
  Duration _lastBrisk = Duration.zero;
  bool _running = false;
  int? _frameCallbackId;
  Timer? _gentleTimer;

  /// A wake-up that came before the rope existed (the charm's artwork can
  /// finish loading before the first layout); it is carried out as soon as
  /// the rope is made, rather than starting a loop with nothing to run.
  bool _wakeWhenReady = false;
  bool _wallsSet = false;

  void _wake() {
    if (_sim == null) {
      _wakeWhenReady = true;
      return;
    }
    _sim?.wake();
    if (_running) {
      _brisk();
      return;
    }
    _running = true;
    _lastStep = _clock.elapsed;
    _lastBrisk = _clock.elapsed;
    _scheduleFrame();
  }

  void _scheduleFrame() {
    if (_frameCallbackId != null || _gentleTimer != null) return;
    _frameCallbackId =
        SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration _) {
    _frameCallbackId = null;
    final sim = _sim;
    if (sim == null || !mounted) return;

    final now = _clock.elapsed;
    sim.step((now - _lastStep).inMicroseconds / 1e6);
    _lastStep = now;
    for (final knock in sim.takeCollisions()) {
      _chime(knock.speed,
          mass: knock.b <= _extraSprites.length
              ? _extraSprites[knock.b - 1].charm.mass
              : null);
    }
    _repaint.value++;
    _syncHitRects();

    final handled = _drag != _Drag.none || sim.anchorMoving;
    if (sim.asleep && !handled) {
      _running = false;
      return;
    }
    if (handled || sim.charmSpeed > _gentleSpeed) _lastBrisk = now;
    // Saving power: 30 frames a second from the start, except while the
    // charm is being handled, which stays smooth.
    if (!_saving && now - _lastBrisk < _gentleAfter || handled) {
      _scheduleFrame();
    } else {
      final calmBreeze = sim.windAngle > 0 && sim.charmSpeed < 90;
      _gentleTimer = Timer(calmBreeze ? _breezeDelay : _gentleDelay, () {
        _gentleTimer = null;
        _scheduleFrame();
      });
    }
  }

  /// Something new happened (a touch, the window moved): go straight back to
  /// full frame rate.
  void _brisk() {
    _lastBrisk = _clock.elapsed;
    final timer = _gentleTimer;
    if (timer != null) {
      timer.cancel();
      _gentleTimer = null;
      _scheduleFrame();
    }
  }

  // ---- Hit testing ----

  /// How many charms hang on the rope: the main one, then the extras.
  int get _charmCount =>
      1 + math.min(_sim?.extraCount ?? 0, _extraSprites.length);

  Offset _centerOf(int i) {
    final sim = _sim!;
    return i == 0
        ? charmCenter(sim)
        : Offset(sim.extraX(i - 1), sim.extraY(i - 1));
  }

  double _radiusOf(int i) =>
      i == 0 ? _hitRadius : _extraSprites[i - 1].hitRadius;

  /// The charm under [p] (0 is the main one), or -1. When several are close,
  /// the one [p] is deepest inside.
  int _charmAt(Offset p) {
    if (_sim == null) return -1;
    var best = -1;
    var bestFit = double.infinity;
    for (var i = 0; i < _charmCount; i++) {
      final reach = _radiusOf(i) + _hitSlop;
      final fit = (p - _centerOf(i)).distance / reach;
      if (fit <= 1 && fit < bestFit) {
        best = i;
        bestFit = fit;
      }
    }
    return best;
  }

  List<Rect> _charmRects() => [
        if (_sim != null)
          for (var i = 0; i < _charmCount; i++)
            Rect.fromCircle(
                center: _centerOf(i), radius: _radiusOf(i) + _hitSlop),
      ];

  Rect? _anchorRect() {
    final sim = _sim;
    if (sim == null) return null;
    return Rect.fromCircle(
        center: Offset(sim.anchorX, sim.anchorY + 3), radius: _anchorHitRadius);
  }

  bool _hitsCharm(Offset p) => _charmAt(p) >= 0;

  bool _hitsAnchor(Offset p) => _anchorRect()?.contains(p) ?? false;

  /// Tells the native window which areas take clicks.
  void _syncHitRects() {
    _channel.setHitRects([
      ..._charmRects(),
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
    var struck = -1;
    var closest = double.infinity;
    for (var i = 0; i < _charmCount; i++) {
      final gap = _distanceToSegment(_centerOf(i), last, cursor);
      if (gap <= _radiusOf(i) + 2 && gap < closest) {
        struck = i;
        closest = gap;
      }
    }
    if (struck < 0) return;

    final velocity = (cursor - last) / seconds;
    if (velocity.distance < _brushSpeed) return;
    final push = velocity * _brushShare;
    // The charm hangs from above, so a sideways knock moves it far more than
    // an up or down one.
    sim.nudge(push.dx, push.dy * 0.3, charm: struck);
    _chime(velocity.distance,
        mass: struck == 0 ? null : _extraSprites[struck - 1].charm.mass);
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
    _downAt = p;
    _downTime = _clock.elapsed;
    _travel = 0;

    if (_menuRect != null && !_menuRect!.contains(p)) _closeMenu();
    if (e.buttons == kSecondaryMouseButton && _hitsCharm(p)) {
      _openMenu(p);
      return;
    }
    if (e.buttons != kPrimaryMouseButton) return;

    final hit = _charmAt(p);
    if (hit >= 0) {
      _drag = _Drag.charm;
      _dragCharm = hit;
      final held = _centerOf(hit);
      _grabOffset = held - p;
      sim.grab(held.dx, held.dy, charm: hit);
      _channel.holdInteractive(true);
      _wake();
    } else if (_hitsAnchor(p)) {
      _drag = _Drag.anchor;
      // On a side edge the pin slides up and down.
      _grabOffset = _beside
          ? Offset(0, sim.anchorY - p.dy)
          : Offset(sim.anchorX - p.dx, 0);
      _channel.holdInteractive(true);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    final sim = _sim;
    if (sim == null) return;
    switch (_drag) {
      case _Drag.charm:
        _travel = math.max(_travel, (e.localPosition - _downAt).distance);
        final target = e.localPosition + _grabOffset;
        sim.dragTo(target.dx, target.dy);
        _wake();
      case _Drag.anchor:
        _moveAnchorTo(_beside
            ? e.localPosition.dy + _grabOffset.dy
            : e.localPosition.dx + _grabOffset.dx);
      case _Drag.none:
        break;
    }
  }

  void _onPointerUp(PointerEvent e) {
    if (_drag == _Drag.none) return;
    if (_drag == _Drag.charm) {
      _sim?.release();
      if (_dragCharm == 0 && (_sim?.charmSpeed ?? 0) > 150) {
        _chime(_sim!.charmSpeed);
      }
      // A quick press that hardly moved is a tap (on the main charm: a
      // locket opens).
      if (_dragCharm == 0 &&
          e is PointerUpEvent &&
          _travel < 6 &&
          _clock.elapsed - _downTime < const Duration(milliseconds: 500)) {
        _toggleLocket();
      }
    }
    if (_drag == _Drag.anchor) _savePinPosition();
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

  Widget _buildMenu() {
    final rect = _menuRect!;
    final following = _settings.value.followWindow;
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
            item('Customize…', _openCustomize),
            item('Hang from window', () => _setFollowWindow(!following),
                selected: following),
            item('Quit', _quit),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dpr = View.of(context).devicePixelRatio;
    if (_dpr != dpr) {
      // First build, or the screen's scale changed: (re)load the charm at
      // the new density, showing the bead until it is ready.
      _dpr = dpr;
      _sprite ??= CharmSprite.goldBead(dpr);
      _showCharm(_settings.value.charmId);
      _showExtras(_settings.value.extraCharmIds);
    }
    final sprite = _sprite!;
    return LayoutBuilder(builder: (context, constraints) {
      _size = constraints.biggest;
      final sim = _simFor(_size);
      if (_extrasPending) {
        _extrasPending = false;
        _applyExtras();
      }
      _syncBreeze(sim);
      if (!_wallsSet) {
        _wallsSet = true;
        _applyWalls();
      }
      if (_wakeWhenReady || (!_running && !sim.asleep)) {
        _wakeWhenReady = false;
        _wake();
      }
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: CharmPainter(sim, sprite,
                      repaint: _repaint,
                      animate: _playAnimations,
                      extras: _extraSprites,
                      locketOpen: () => _locketProgress),
                ),
              ),
            ),
            if (_menuRect != null) _buildMenu(),
          ],
        ),
      );
    });
  }
}
