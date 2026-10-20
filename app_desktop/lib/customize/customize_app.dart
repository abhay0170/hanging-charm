import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/app_settings.dart';
import '../settings/settings_store.dart';
import 'customize_channel.dart';
import 'rope_preview.dart';

const appName = 'Charm';
const appVersion = '0.1.0';

const _gold = Color(0xFFC8962E);

/// The Customize window: Library, Ropes & Layout, Settings and About.
/// Every change applies to the charm straight away; there is no Save.
class CustomizeApp extends StatelessWidget {
  const CustomizeApp({super.key, required this.channel});

  final CustomizeChannel channel;

  ThemeData _theme(Brightness brightness) => ThemeData(
        colorSchemeSeed: _gold,
        brightness: brightness,
        fontFamily: 'Segoe UI',
        visualDensity: VisualDensity.standard,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$appName – Customize',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: _CustomizeHome(channel: channel),
    );
  }
}

class _CustomizeHome extends StatefulWidget {
  const _CustomizeHome({required this.channel});

  final CustomizeChannel channel;

  @override
  State<_CustomizeHome> createState() => _CustomizeHomeState();
}

class _CustomizeHomeState extends State<_CustomizeHome> {
  static const _tabs = [
    (Icons.diamond_outlined, Icons.diamond, 'Library'),
    (Icons.linear_scale, Icons.linear_scale, 'Ropes & Layout'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
    (Icons.info_outline, Icons.info, 'About'),
  ];

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < _tabs.length; i++)
          SingleActivator(LogicalKeyboardKey(0x31 + i), control: true): () =>
              setState(() => _tab = i),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            channel.close,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                labelType: NavigationRailLabelType.all,
                minWidth: 96,
                groupAlignment: -0.9,
                destinations: [
                  for (final (icon, selected, label) in _tabs)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: Text(label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ValueListenableBuilder<AppSettings?>(
                  valueListenable: channel.settings,
                  builder: (context, settings, _) {
                    if (settings == null) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: channel.charmMissing,
                        builder: (context, missing, _) => Center(
                          child: missing
                              ? const Text('Charm isn’t running. Start it, '
                                  'then open Customize from its tray icon.')
                              : const CircularProgressIndicator(),
                        ),
                      );
                    }
                    return switch (_tab) {
                      0 => _LibraryPage(settings: settings),
                      1 => _RopesPage(settings: settings, channel: channel),
                      2 => _SettingsPage(settings: settings, channel: channel),
                      _ => const _AboutPage(),
                    };
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrolling page with a title, a one-line explanation and sections.
class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      children: [
        Text(title, style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle,
            style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// A tappable card with a picture on top and a caption, outlined in the
/// accent colour when chosen.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.picture,
    required this.title,
    required this.caption,
    required this.selected,
    this.onTap,
  });

  final Widget picture;
  final String title;
  final String caption;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 172,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
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
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 150, child: Center(child: picture)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, size: 18, color: scheme.primary),
                  ],
                ),
                const SizedBox(height: 2),
                Text(caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Library ----

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Page(
      title: 'Library',
      subtitle: 'The charm that hangs on your screen.',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ChoiceCard(
              picture: RopePreview(style: settings.ropeStyle),
              title: 'Gold bead',
              caption: 'Polished, weighty and never out of place.',
              selected: true,
            ),
            SizedBox(
              width: 172,
              height: 222,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_outlined,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('More charms are on the way',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---- Ropes & Layout ----

class _RopesPage extends StatelessWidget {
  const _RopesPage({required this.settings, required this.channel});

  final AppSettings settings;
  final CustomizeChannel channel;

  static const _captions = {
    'thread': 'Light gold thread. A long, easy swing.',
    'leather': 'A flat leather braid. Grippy; settles soonest.',
    'gold_chain': 'Heavy gold links. A slower swing that settles sooner.',
    'silver_chain': 'Linked silver. A chain, a touch lighter.',
    'neon': 'A glowing filament. Light and lively.',
    'spider_thread': 'Spun silk, almost weightless. The floatiest swing.',
    'midnight_cord': 'A dark braided cord. Steady and calm.',
    'temple_thread': 'Saffron and vermilion cotton, twisted together.',
    'silver_cord': 'Woven silver cord. Smooth and even.',
  };

  @override
  Widget build(BuildContext context) {
    final following = settings.followWindow;
    final fraction = following
        ? settings.windowAnchorFraction
        : settings.screenAnchorFraction;
    final fractionKey =
        following ? 'windowAnchorFraction' : 'screenAnchorFraction';
    return _Page(
      title: 'Ropes & Layout',
      subtitle: 'What the charm hangs on, and where.',
      children: [
        const _SectionTitle('Rope'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final style in RopeStyle.all)
              _ChoiceCard(
                picture: RopePreview(style: style),
                title: style.name,
                caption: _captions[style.id] ?? '',
                selected: style.id == settings.ropeStyleId,
                onTap: () => channel.update({'ropeStyle': style.id}),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Hang from'),
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
          selected: {following},
          onSelectionChanged: (s) => channel.update({'followWindow': s.first}),
        ),
        const SizedBox(height: 8),
        Text(
          following
              ? 'Moves to whichever window you click. Move that window and the '
                  'charm swings with it. Full-screen video and games hide it.'
              : 'Stays on the top edge of your screen.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Pin position'),
        Row(
          children: [
            const Text('Left'),
            Expanded(
              child: Slider(
                value: fraction.clamp(0.05, 0.95),
                min: 0.05,
                max: 0.95,
                divisions: 90,
                label: '${(fraction * 100).round()}%',
                onChanged: (v) => channel.update({fractionKey: v}),
              ),
            ),
            const Text('Right'),
          ],
        ),
        Text(
          'Where along ${following ? 'the window’s' : 'the screen’s'} '
          'top edge the charm hangs. You can also drag the pin itself.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---- Settings ----

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.settings, required this.channel});

  final AppSettings settings;
  final CustomizeChannel channel;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool? _launchAtLogin;

  @override
  void initState() {
    super.initState();
    widget.channel.getLaunchAtLogin().then((on) {
      if (mounted) setState(() => _launchAtLogin = on);
    });
  }

  Future<void> _setLaunchAtLogin(bool on) async {
    final ok = await widget.channel.setLaunchAtLogin(on);
    final now = await widget.channel.getLaunchAtLogin();
    if (!mounted) return;
    setState(() => _launchAtLogin = now);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Windows didn’t allow changing the startup list.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Page(
      title: 'Settings',
      subtitle: 'How the charm behaves on this computer.',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show charm'),
          subtitle: const Text('Hide it for a while without quitting.'),
          value: widget.settings.charmVisible,
          onChanged: (v) => widget.channel.update({'charmVisible': v}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Launch at login'),
          subtitle: const Text('Start the charm when you sign in to Windows.'),
          value: _launchAtLogin ?? false,
          onChanged: _launchAtLogin == null ? null : _setLaunchAtLogin,
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Privacy'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline, color: scheme.primary),
          title: const Text('Works completely offline'),
          subtitle: const Text('The charm makes no network requests. Nothing '
              'about you, your screen or your files leaves this computer.'),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Saved settings'),
        SelectableText(
          '${SettingsStore.defaultDirectory().path}\\settings.json',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---- About ----

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Page(
      title: 'About',
      subtitle: 'Version $appVersion',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
                width: 90,
                height: 120,
                child: RopePreview(style: RopeStyle.thread)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appName, style: text.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'A small charm that hangs from your screen and swings '
                    'with real physics. Every swing comes from you.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: appName,
                      applicationVersion: appVersion,
                    ),
                    child: const Text('Open-source licences'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const _SectionTitle('Keyboard'),
        Text('Ctrl+1 to Ctrl+4  switch tabs\nCtrl+W  close this window',
            style: text.bodyMedium?.copyWith(height: 1.6)),
      ],
    );
  }
}
