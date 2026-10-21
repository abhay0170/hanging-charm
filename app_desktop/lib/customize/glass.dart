import 'dart:ui';

import 'package:flutter/material.dart';

/// The look of the Customize window: frosted glass over a soft glow, one
/// neon accent, and glassy buttons. Dark only, since glass needs something
/// dark and glowing behind it to be seen.
class Glass {
  const Glass._();

  /// The single neon accent: a cool mint.
  static const neon = Color(0xFF5EF2E0);
  static const neonBright = Color(0xFFA4FFF2);
  static const base = Color(0xFF07080D);

  static const text = Color(0xFFEEF2F7);
  static final muted = text.withValues(alpha: 0.58);
  static final faint = text.withValues(alpha: 0.34);

  static final fill = Colors.white.withValues(alpha: 0.055);
  static final fillStrong = Colors.white.withValues(alpha: 0.09);
  static final line = Colors.white.withValues(alpha: 0.13);
  static final neonLine = neon.withValues(alpha: 0.55);
  static final divider = Colors.white.withValues(alpha: 0.07);

  static const radius = 22.0;

  // ---- The theme ----

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      primary: neon,
      onPrimary: Color(0xFF04110F),
      secondary: neonBright,
      onSecondary: Color(0xFF04110F),
      surface: base,
      onSurface: text,
      error: Color(0xFFFF8A8A),
    );
    final scheme2 = scheme.copyWith(
      onSurfaceVariant: muted,
      outline: Colors.white.withValues(alpha: 0.22),
      outlineVariant: line,
      surfaceContainerHighest: const Color(0xFF1E2736),
      primaryContainer: const Color(0xFF0E3A38),
      onPrimaryContainer: text,
    );
    final base0 = ThemeData(
      colorScheme: scheme2,
      brightness: Brightness.dark,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: const Color(0xFF121722),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.white.withValues(alpha: 0.04),
    );
    final t = base0.textTheme.apply(bodyColor: text, displayColor: text);
    return base0.copyWith(
      textTheme: t.copyWith(
        headlineSmall: t.headlineSmall?.copyWith(
            fontSize: 40, fontWeight: FontWeight.w300, letterSpacing: -0.5),
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w400),
        titleMedium: t.titleMedium
            ?.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
        titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
        bodySmall: t.bodySmall?.copyWith(fontSize: 13.5, height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: t.titleLarge?.copyWith(fontWeight: FontWeight.w300),
      ),
      dividerTheme: DividerThemeData(color: divider, space: 1, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xF2121722),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: line),
        ),
        titleTextStyle: t.headlineSmall
            ?.copyWith(fontSize: 26, fontWeight: FontWeight.w300),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xEE182030),
        contentTextStyle: t.bodyMedium,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled)
                ? Colors.white30
                : (s.contains(WidgetState.selected)
                    ? Colors.white
                    : const Color(0xFFD5DCE5))),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? neon.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.09)),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? neonLine : line),
        trackOutlineWidth: const WidgetStatePropertyAll(1),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: neon,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.white.withValues(alpha: 0.28),
        thumbColor: neonBright,
        overlayColor: neon.withValues(alpha: 0.14),
        thumbShape: const _GlowThumb(),
        valueIndicatorColor: const Color(0xF2182030),
        valueIndicatorTextStyle: t.bodySmall?.copyWith(color: neon),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _neonButton()),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _neonButton()),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _glassButton()),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neon,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? neon : fill),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? const Color(0xFF04110F)
                  : muted),
          side: WidgetStatePropertyAll(BorderSide(color: line)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          overlayColor: WidgetStatePropertyAll(neon.withValues(alpha: 0.08)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        selectedColor: neon.withValues(alpha: 0.22),
        side: BorderSide(color: line),
        labelStyle: t.bodyMedium,
        checkmarkColor: neon,
        deleteIconColor: muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: faint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: neon, width: 1.4),
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
        titleTextStyle: t.titleMedium?.copyWith(fontSize: 17),
        subtitleTextStyle: t.bodySmall?.copyWith(color: muted),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xF2182030),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: line),
        ),
        textStyle: t.bodySmall,
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
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundBuilder: (context, states, child) => _GlassFace(
          states: states,
          tint: Colors.white,
          border: Colors.white.withValues(alpha: 0.2),
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
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
/// cursor, a border, a faint glow for the neon kind.
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
    final top = (glow ? 0.20 : 0.14) + (lit ? 0.08 : 0);
    final bottom = (glow ? 0.06 : 0.05) + (lit ? 0.05 : 0);
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
                color: Glass.neon.withValues(alpha: lit ? 0.32 : 0.2),
                blurRadius: lit ? 26 : 20,
              ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// A slider handle that glows.
class _GlowThumb extends SliderComponentShape {
  const _GlowThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(12);

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
      center,
      15,
      Paint()
        ..color = Glass.neon.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(
      center,
      9.5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Colors.white, Color(0xFFBFFAF3), Glass.neon],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: center, radius: 9.5)),
    );
  }
}

/// The glow behind everything: the base colour with a few soft lights, so
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

    light(Offset(size.width * 0.02, size.height * 0.02), size.height * 0.62,
        const Color(0xFF1C6B7A).withValues(alpha: 0.55));
    light(Offset(size.width * 0.98, size.height * 0.35), size.height * 0.55,
        const Color(0xFF4A2D8F).withValues(alpha: 0.5));
    light(Offset(size.width * 0.45, size.height * 1.02), size.height * 0.55,
        const Color(0xFF0F5A58).withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(_GlowPainter old) => false;
}

/// A panel of frosted glass.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = Glass.radius,
    this.padding = EdgeInsets.zero,
    this.glowing = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Lit with the neon accent, as a chosen card is.
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: glowing
                ? Glass.neon.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.28),
            blurRadius: glowing ? 24 : 34,
            offset: glowing ? Offset.zero : const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              color: glowing ? Glass.neon.withValues(alpha: 0.09) : Glass.fill,
              border: Border.all(color: glowing ? Glass.neonLine : Glass.line),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(color: Glass.divider, height: 1, indent: 10, endIndent: 10),
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

  /// The control is wide (a slider, a row of buttons), so in a narrow window
  /// it goes under the words instead of squeezing them.
  final bool wide;

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: text.bodySmall?.copyWith(color: Glass.muted)),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: LayoutBuilder(
        builder: (context, box) {
          // Too narrow for the control beside the words: put it underneath.
          final stacked = wide && trailing != null && box.maxWidth < 760;
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
                    if (leading != null) ...[leading!, const SizedBox(width: 14)],
                    Expanded(child: words),
                    if (trailing != null) ...[
                      const SizedBox(width: 22),
                      trailing!,
                    ],
                  ],
                );
        },
      ),
    );
  }
}

/// A section heading: small neon capitals and a hairline that fades out.
class GlassLabel extends StatelessWidget {
  const GlassLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
        child: Row(
          children: [
            Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 12.5,
                letterSpacing: 2.2,
                color: Glass.neon.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Glass.neon.withValues(alpha: 0.35),
                    Glass.neon.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ],
        ),
      );
}
