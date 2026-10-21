import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The look of the Customize window: quiet frosted panels over a dark,
/// softly lit background, one neon accent, and glassy buttons. Dark only,
/// since glass needs something dark to be seen against.
class Glass {
  const Glass._();

  /// The single neon accent: a cool mint.
  static const neon = Color(0xFF5EF2E0);
  static const neonBright = Color(0xFFA4FFF2);
  static const base = Color(0xFF090B10);

  static const text = Color(0xFFE8EDF3);
  static final muted = text.withValues(alpha: 0.58);
  static final faint = text.withValues(alpha: 0.36);

  static final fill = Colors.white.withValues(alpha: 0.04);
  static final fillStrong = Colors.white.withValues(alpha: 0.07);
  static final line = Colors.white.withValues(alpha: 0.08);
  static final lineStrong = Colors.white.withValues(alpha: 0.14);
  static final neonFill = neon.withValues(alpha: 0.10);
  static final neonLine = neon.withValues(alpha: 0.5);
  static final divider = Colors.white.withValues(alpha: 0.08);

  /// The corner radius of panels, tiles and fields; buttons use a little
  /// less.
  static const radius = 12.0;
  static const buttonRadius = 10.0;

  static const fontFamily = 'Segoe UI Variable Text';
  static const fontFallback = ['Segoe UI', 'Nirmala UI'];

  // ---- The theme ----

  static ThemeData theme() {
    final scheme = const ColorScheme.dark(
      primary: neon,
      onPrimary: Color(0xFF04110F),
      secondary: neonBright,
      onSecondary: Color(0xFF04110F),
      surface: base,
      onSurface: text,
      error: Color(0xFFFF8A8A),
    ).copyWith(
      onSurfaceVariant: muted,
      outline: lineStrong,
      outlineVariant: line,
      surfaceContainerHighest: const Color(0xFF1A2130),
      primaryContainer: const Color(0xFF0E3A38),
      onPrimaryContainer: text,
    );
    final themed = ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: const Color(0xFF121722),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.white.withValues(alpha: 0.04),
    );
    final t = themed.textTheme.apply(bodyColor: text, displayColor: text);
    return themed.copyWith(
      textTheme: t.copyWith(
        headlineSmall: t.headlineSmall?.copyWith(
            fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleLarge:
            t.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium:
            t.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        titleSmall:
            t.titleSmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 15),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
        bodySmall: t.bodySmall?.copyWith(fontSize: 12.5, height: 1.4),
        labelMedium: t.labelMedium?.copyWith(fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle:
            t.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(color: divider, space: 1, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xF4121722),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: lineStrong),
        ),
        titleTextStyle:
            t.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: t.bodyMedium?.copyWith(color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xEE182030),
        contentTextStyle: t.bodyMedium,
        elevation: 0,
        width: 460,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: lineStrong),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFFD5DCE5)),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? neon.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.10)),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? neonLine : lineStrong),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: neon,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.white.withValues(alpha: 0.28),
        thumbColor: Colors.white,
        overlayColor: neon.withValues(alpha: 0.12),
        thumbShape: const _RingThumb(),
        valueIndicatorColor: const Color(0xF2182030),
        valueIndicatorTextStyle: t.bodySmall?.copyWith(color: neon),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _neonButton()),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _neonButton()),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _glassButton()),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neon,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius)),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(neon.withValues(alpha: 0.10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: muted).copyWith(
          overlayColor: WidgetStatePropertyAll(neon.withValues(alpha: 0.10)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? neon : fill),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? const Color(0xFF04110F)
                  : muted),
          side: WidgetStatePropertyAll(BorderSide(color: line)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius))),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          overlayColor: WidgetStatePropertyAll(neon.withValues(alpha: 0.08)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        selectedColor: neonFill,
        side: BorderSide(color: line),
        labelStyle: t.bodyMedium?.copyWith(fontSize: 13),
        checkmarkColor: neon,
        deleteIconColor: muted,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: faint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: neon, width: 1.2),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: neon),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.2)),
        thickness: const WidgetStatePropertyAll(5),
        radius: const Radius.circular(5),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: neon,
        titleTextStyle: t.titleMedium,
        subtitleTextStyle: t.bodySmall?.copyWith(color: muted),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xF2182030),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        textStyle: t.bodySmall,
        waitDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// A glass button: a bright top edge, a hairline border, a soft fill.
  static ButtonStyle _glassButton() => ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        foregroundColor: const WidgetStatePropertyAll(text),
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 9)),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius))),
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundBuilder: (context, states, child) => _GlassFace(
          states: states,
          tint: Colors.white,
          border: lineStrong,
          child: child!,
        ),
      );

  /// The same, lit with the neon accent: for the main action.
  static ButtonStyle _neonButton() => ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? Colors.white30 : neon),
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 9)),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius))),
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundBuilder: (context, states, child) => _GlassFace(
          states: states,
          tint: neon,
          border: neonLine,
          glow: true,
          child: child!,
        ),
      );
}

/// The face of a glass button: a gradient fill that brightens under the
/// cursor, a border, and a faint glow for the neon kind.
class _GlassFace extends StatelessWidget {
  const _GlassFace({
    required this.states,
    required this.tint,
    required this.border,
    required this.child,
    this.glow = false,
  });

  final Set<WidgetState> states;
  final Color tint;
  final Color border;
  final bool glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disabled = states.contains(WidgetState.disabled);
    final lit = states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.pressed) ||
        states.contains(WidgetState.focused);
    final top = (glow ? 0.20 : 0.11) + (lit ? 0.07 : 0);
    final bottom = (glow ? 0.06 : 0.04) + (lit ? 0.04 : 0);
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Glass.buttonRadius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tint.withValues(alpha: top),
              tint.withValues(alpha: bottom),
            ],
          ),
          border: Border.all(color: border),
          boxShadow: [
            if (glow && !disabled)
              BoxShadow(
                color: Glass.neon.withValues(alpha: lit ? 0.22 : 0.12),
                blurRadius: lit ? 20 : 14,
              ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// A slider handle: white, with a soft neon ring.
class _RingThumb extends SliderComponentShape {
  const _RingThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(10);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
        center, 10, Paint()..color = Glass.neon.withValues(alpha: 0.28));
    canvas.drawCircle(
      center.translate(0, 1),
      7,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
  }
}

/// A small switch: a glass pill, lit mint when on.
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({super.key, required this.value, required this.onChanged});

  final bool value;

  /// Null makes it unusable and dim.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    void toggle() => onChanged?.call(!value);
    return Semantics(
      toggled: value,
      enabled: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            toggle();
            return null;
          }),
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        child: GestureDetector(
          onTap: enabled ? toggle : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 40,
              height: 22,
              padding: const EdgeInsets.all(2),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: value
                    ? Glass.neon.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.10),
                border: Border.all(
                    color: value ? Glass.neonLine : Glass.lineStrong),
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? Colors.white : const Color(0xFFD5DCE5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The light behind everything: the base colour with two soft washes, so
/// the glass has something to frost.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Glass.base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _Glows())),
          child,
        ],
      ),
    );
  }
}

class _Glows extends StatelessWidget {
  const _Glows();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GlowPainter(), size: Size.infinite);
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void light(Offset at, double radius, Color color) {
      final rect = Rect.fromCircle(center: at, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [
            color,
            color.withValues(alpha: 0),
          ]).createShader(rect),
      );
    }

    light(Offset(size.width * 0.05, size.height * -0.02), size.height * 0.62,
        const Color(0xFF28969F).withValues(alpha: 0.22));
    light(Offset(size.width * 1.0, size.height * 0.3), size.height * 0.6,
        const Color(0xFF5A3CAA).withValues(alpha: 0.16));
  }

  @override
  bool shouldRepaint(_GlowPainter old) => false;
}

/// A panel of glass.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = Glass.radius,
    this.padding = EdgeInsets.zero,
    this.glowing = false,
    this.frosted = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Lit with the neon accent, as the chosen tile is.
  final bool glowing;

  /// Blur what is behind it. Off for small tiles drawn in dozens, where it
  /// would cost more than it shows.
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final face = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: glowing ? Glass.neonFill : Glass.fill,
        border: Border.all(color: glowing ? Glass.neonLine : Glass.line),
      ),
      child: Padding(padding: padding, child: child),
    );
    return ClipRRect(
      borderRadius: shape,
      child: frosted
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: face)
          : face,
    );
  }
}

/// A card of rows, divided by hairlines.
class GlassGroup extends StatelessWidget {
  const GlassGroup({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(color: Glass.divider, height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One setting: a title and a quieter explanation on the left, its control
/// on the right.
class GlassRow extends StatelessWidget {
  const GlassRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.wide = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  /// The control is wide (a slider, a row of buttons), so in a narrow window
  /// it goes under the words instead of squeezing them.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: text.bodySmall?.copyWith(color: Glass.muted)),
        ],
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: LayoutBuilder(
          builder: (context, box) {
            // Too narrow for the control beside the words: put it underneath.
            final stacked = wide && trailing != null && box.maxWidth < 600;
            return stacked
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: 14)
                          ],
                          Expanded(child: words),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerRight, child: trailing!),
                    ],
                  )
                : Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 14)
                      ],
                      Expanded(child: words),
                      if (trailing != null) ...[
                        const SizedBox(width: 24),
                        trailing!,
                      ],
                    ],
                  );
          },
        ),
      ),
    );
  }
}

/// A section heading: small, plain, a little quieter than the page.
class GlassLabel extends StatelessWidget {
  const GlassLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Glass.muted,
          ),
        ),
      );
}

/// A page: a title and one line under it on the left (and anything you
/// like on the right), then the content, in a column that stops growing on
/// a wide window.
class GlassPage extends StatelessWidget {
  const GlassPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
    this.maxWidth = 760,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth < 640 ? 22.0 : 40.0;
      return ListView(
        padding: EdgeInsets.fromLTRB(side, 26, side, 28),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: text.headlineSmall),
                            const SizedBox(height: 3),
                            Text(subtitle,
                                style: text.bodySmall?.copyWith(
                                    color: Glass.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 16),
                        trailing!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
