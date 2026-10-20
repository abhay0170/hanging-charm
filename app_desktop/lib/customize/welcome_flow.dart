import 'package:flutter/material.dart';

import '../charms/charm.dart';
import '../settings/app_settings.dart';
import 'customize_channel.dart';
import 'rope_preview.dart';

/// The first-launch welcome, in three steps: pick a charm, choose privacy,
/// and where it hangs. Every choice applies to the charm at once, so the
/// person sees it change on their screen as they go.
class WelcomeFlow extends StatefulWidget {
  const WelcomeFlow({super.key, required this.channel, required this.catalog});

  final CustomizeChannel channel;
  final CharmCatalog catalog;

  @override
  State<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends State<WelcomeFlow> {
  static const _steps = 3;
  int _step = 0;
  bool? _launchAtLogin;

  @override
  void initState() {
    super.initState();
    widget.channel.getLaunchAtLogin().then((on) {
      if (mounted) setState(() => _launchAtLogin = on);
    });
  }

  Future<void> _setLaunchAtLogin(bool on) async {
    await widget.channel.setLaunchAtLogin(on);
    final now = await widget.channel.getLaunchAtLogin();
    if (mounted) setState(() => _launchAtLogin = now);
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    return Scaffold(
      body: ValueListenableBuilder<AppSettings?>(
        valueListenable: channel.settings,
        builder: (context, settings, _) {
          if (settings == null) {
            return ValueListenableBuilder<bool>(
              valueListenable: channel.charmMissing,
              builder: (context, missing, _) => Center(
                child: missing
                    ? const Text('Charm isn’t running. Start it first.')
                    : const CircularProgressIndicator(),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(36, 28, 36, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepDots(step: _step, count: _steps),
                const SizedBox(height: 20),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: switch (_step) {
                        0 => _PickCharm(
                            settings: settings,
                            catalog: widget.catalog,
                            channel: channel),
                        1 => _Privacy(settings: settings, channel: channel),
                        _ => _MakeItYours(
                            settings: settings,
                            channel: channel,
                            launchAtLogin: _launchAtLogin,
                            onLaunchAtLogin: _setLaunchAtLogin),
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _step < _steps - 1
                          ? () => setState(() => _step++)
                          : channel.close,
                      child: Text(_step < _steps - 1 ? 'Next' : 'Done'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text('Step ${step + 1} of $count',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(width: 12),
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 6),
            width: i == step ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= step ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle,
            style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ---- Step 1: pick a charm ----

class _PickCharm extends StatelessWidget {
  const _PickCharm({
    required this.settings,
    required this.catalog,
    required this.channel,
  });

  final AppSettings settings;
  final CharmCatalog catalog;
  final CustomizeChannel channel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chosen = catalog.charmFor(settings.charmId).id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Welcome to Charm',
          'A little charm that hangs on your screen and swings when you move '
              'things. Pick one to start. It’s already hanging up top, '
              'and you can change it any time.',
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final charm in catalog.all)
                  SizedBox(
                    width: 110,
                    child: Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      color: charm.id == chosen
                          ? scheme.primaryContainer.withValues(alpha: 0.5)
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: charm.id == chosen
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: charm.id == chosen ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => channel.update({'charm': charm.id}),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                          child: Column(
                            children: [
                              SizedBox(
                                  height: 56,
                                  child: CharmArt(charm: charm)),
                              const SizedBox(height: 8),
                              Text(charm.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style:
                                      Theme.of(context).textTheme.labelMedium),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Step 2: privacy ----

class _Privacy extends StatelessWidget {
  const _Privacy({required this.settings, required this.channel});

  final AppSettings settings;
  final CustomizeChannel channel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading(
            'Your privacy',
            'Charm needs no account and never looks at your screen, your '
                'files or your other apps. Choose whether to share anything '
                'at all.',
          ),
          _Option(
            icon: Icons.lock_outline,
            title: 'Keep everything on this computer',
            badge: 'Recommended',
            body: 'Charm works completely offline. Nothing about you, your '
                'screen or your files leaves this computer.',
            selected: !settings.shareStats,
            onTap: () => channel.update({'shareStats': false}),
          ),
          const SizedBox(height: 12),
          _Option(
            icon: Icons.insights_outlined,
            title: 'Share anonymous usage stats',
            body: 'A random ID, the app version, that this is Windows, and '
                'which charm, rope and hanging spot you use. Never your name, '
                'location, screen or files.\n\nThis version doesn’t send '
                'anything yet; your choice applies once stats are added.',
            selected: settings.shareStats,
            onTap: () => channel.update({'shareStats': true}),
          ),
          const SizedBox(height: 16),
          Text('You can change this any time in Customize → Settings.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: text.titleSmall),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(badge!,
                                style: text.labelSmall
                                    ?.copyWith(color: scheme.primary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(body,
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Step 3: where it hangs ----

class _MakeItYours extends StatelessWidget {
  const _MakeItYours({
    required this.settings,
    required this.channel,
    required this.launchAtLogin,
    required this.onLaunchAtLogin,
  });

  final AppSettings settings;
  final CustomizeChannel channel;
  final bool? launchAtLogin;
  final ValueChanged<bool> onLaunchAtLogin;

  static const _tips = [
    (Icons.pan_tool_alt_outlined,
        'Drag the charm and let go: it swings back, never further than you moved it.'),
    (Icons.swipe_outlined, 'Sweep the cursor through it to give it a nudge.'),
    (Icons.push_pin_outlined, 'Drag the small pin to move it along the edge.'),
    (Icons.mouse_outlined,
        'Right-click it, or the icon by the clock, for Customize and more.'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('Make it yours',
              'Where it hangs, and a few things to try.'),
          Text('Hang from', style: text.titleSmall),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true,
                  icon: Icon(Icons.web_asset),
                  label: Text('The window you’re using')),
              ButtonSegment(
                  value: false,
                  icon: Icon(Icons.desktop_windows_outlined),
                  label: Text('Top of the screen')),
            ],
            selected: {settings.followWindow},
            onSelectionChanged: (s) =>
                channel.update({'followWindow': s.first}),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start Charm when you sign in'),
            value: launchAtLogin ?? false,
            onChanged: launchAtLogin == null ? null : onLaunchAtLogin,
          ),
          const SizedBox(height: 12),
          Text('Try this', style: text.titleSmall),
          const SizedBox(height: 8),
          for (final (icon, tip) in _tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tip, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
