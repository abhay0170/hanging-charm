import 'dart:convert';
import 'dart:io';

import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../charms/charm.dart';
import '../charms/user_charms.dart';
import '../privacy/usage_stats.dart';
import '../settings/app_settings.dart';
import '../settings/settings_store.dart';
import 'customize_channel.dart';
import 'charm_designer.dart';
import 'name_charm_editor.dart';
import 'photo_charm_editor.dart';
import 'rope_preview.dart';
import 'welcome_flow.dart';

const appName = 'Charm';
const appVersion = '0.1.0';

const _gold = Color(0xFFC8962E);

/// The Customize window: Library, Ropes & Layout, Settings and About.
/// Every change applies to the charm straight away; there is no Save.
class CustomizeApp extends StatelessWidget {
  const CustomizeApp({
    super.key,
    required this.channel,
    required this.catalog,
    this.welcome = false,
  });

  final CustomizeChannel channel;
  final CharmCatalog catalog;

  /// Show the first-launch welcome instead of the tabs.
  final bool welcome;

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
      home: welcome
          ? WelcomeFlow(channel: channel, catalog: catalog)
          : _CustomizeHome(channel: channel, catalog: catalog),
    );
  }
}

class _CustomizeHome extends StatefulWidget {
  const _CustomizeHome({required this.channel, required this.catalog});

  final CustomizeChannel channel;
  final CharmCatalog catalog;

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

  final _userCharms = UserCharms.standard();

  /// The built-in charms plus the user's own, refreshed after they make or
  /// delete one.
  late CharmCatalog _catalog =
      widget.catalog.withUserCharms(_userCharms.load());

  void _refreshCatalog() => setState(
      () => _catalog = widget.catalog.withUserCharms(_userCharms.load()));

  /// Pick a photo, design the charm, save it, and hang it.
  Future<void> _newFromPhoto() async {
    final path = await widget.channel.pickImage();
    if (path == null || !mounted) return;
    final photo = await loadPhoto(path);
    if (!mounted) return;
    if (photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That picture couldn’t be opened. '
              'Try a PNG, JPEG, WebP or BMP.')));
      return;
    }
    final charm = await Navigator.of(context).push<Charm>(MaterialPageRoute(
        builder: (_) =>
            PhotoCharmEditor(photo: photo, userCharms: _userCharms)));
    photo.dispose();
    if (charm == null || !mounted) return;
    _refreshCatalog();
    widget.channel.update({'charm': charm.id});
  }

  /// Type a name, choose its look, save it, and hang it.
  Future<void> _newFromName() async {
    final charm = await Navigator.of(context).push<Charm>(MaterialPageRoute(
        builder: (_) => NameCharmEditor(userCharms: _userCharms)));
    if (charm == null || !mounted) return;
    _refreshCatalog();
    widget.channel.update({'charm': charm.id});
  }

  /// Build one from layers, save it, and hang it.
  Future<void> _designYourOwn() async {
    final charm = await Navigator.of(context).push<Charm>(MaterialPageRoute(
        builder: (_) => CharmDesigner(
            userCharms: _userCharms, pickImage: widget.channel.pickImage)));
    if (charm == null || !mounted) return;
    _refreshCatalog();
    widget.channel.update({'charm': charm.id});
  }

  Future<void> _delete(Charm charm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${charm.name}”?'),
        content: const Text('It will be removed from your charms. Any photo '
            'you used for it isn’t touched.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    // Take it down first if it is the one hanging.
    if (widget.channel.settings.value?.charmId == charm.id) {
      await widget.channel.update({'charm': Charm.goldBead.id});
    }
    _userCharms.delete(charm.id);
    _refreshCatalog();
  }

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
                      0 => _LibraryPage(
                          settings: settings,
                          catalog: _catalog,
                          channel: channel,
                          onNewFromPhoto: _newFromPhoto,
                          onNewFromName: _newFromName,
                          onDesign: _designYourOwn,
                          onDelete: _delete),
                      1 => _RopesPage(
                          settings: settings,
                          catalog: _catalog,
                          channel: channel),
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
  const _LibraryPage({
    required this.settings,
    required this.catalog,
    required this.channel,
    required this.onNewFromPhoto,
    required this.onNewFromName,
    required this.onDesign,
    required this.onDelete,
  });

  final AppSettings settings;
  final CharmCatalog catalog;
  final CustomizeChannel channel;
  final VoidCallback onNewFromPhoto;
  final VoidCallback onNewFromName;
  final VoidCallback onDesign;
  final ValueChanged<Charm> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // An unknown saved charm shows as the bead, so mark the bead chosen.
    final chosen = catalog.charmFor(settings.charmId).id;
    final mine = [
      for (final c in catalog.collections)
        if (c.id == CharmCatalog.userCollectionId) ...c.charms,
    ];

    Widget section(String name, String description, List<Widget> cards) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(name),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            Wrap(spacing: 12, runSpacing: 12, children: cards),
            const SizedBox(height: 24),
          ],
        );

    Widget card(Charm charm) => _ChoiceCard(
          picture: Padding(
            padding: const EdgeInsets.all(18),
            child: CharmArt(charm: charm),
          ),
          title: charm.name,
          caption: charm.description,
          selected: charm.id == chosen,
          onTap: () => channel.update({'charm': charm.id}),
        );

    return _Page(
      title: 'Library',
      subtitle: 'The charm that hangs on your screen. '
          '${catalog.all.length} to choose from.',
      children: [
        section(
          'My charms',
          'Made by you, from your photos and words. They stay on this '
              'computer.',
          [
            _NewCharmCard(
              icon: Icons.add_photo_alternate_outlined,
              title: 'New from a photo',
              caption: 'Put someone, or something, in a frame.',
              onTap: onNewFromPhoto,
            ),
            _NewCharmCard(
              icon: Icons.text_fields,
              title: 'New from a name',
              caption: 'A name or word, in English, Hindi or Tamil.',
              onTap: onNewFromName,
            ),
            _NewCharmCard(
              icon: Icons.layers_outlined,
              title: 'Design your own',
              caption: 'Photos, words and stickers on a base you choose.',
              onTap: onDesign,
            ),
            for (final charm in mine)
              Stack(
                children: [
                  card(charm),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => onDelete(charm),
                    ),
                  ),
                ],
              ),
          ],
        ),
        for (final collection in catalog.collections)
          if (collection.id != CharmCatalog.userCollectionId)
            section(collection.name, collection.description,
                [for (final charm in collection.charms) card(charm)]),
      ],
    );
  }
}

/// A card that starts making a new charm.
class _NewCharmCard extends StatelessWidget {
  const _NewCharmCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 172,
      height: 222,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: scheme.primary),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(caption,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Ropes & Layout ----

class _RopesPage extends StatelessWidget {
  const _RopesPage({
    required this.settings,
    required this.catalog,
    required this.channel,
  });

  final AppSettings settings;
  final CharmCatalog catalog;
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
                picture: RopePreview(
                    style: style, charm: catalog.charmFor(settings.charmId)),
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

  /// Shows, word for word, what the stats would contain right now.
  void _showWhatWouldBeShared(BuildContext context) {
    final payload = UsageStats.payload(widget.settings,
        appVersion: appVersion, os: Platform.operatingSystem);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What would be shared'),
        content: SizedBox(
          width: 420,
          child: payload == null
              ? const Text('Nothing. Sharing is off, and no ID exists.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Exactly this, and nothing else:'),
                    const SizedBox(height: 12),
                    SelectableText(
                      const JsonEncoder.withIndent('  ').convert(payload),
                      style: const TextStyle(
                          fontFamily: 'Consolas', fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Text('This version doesn’t send it anywhere.'),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share anonymous usage stats'),
          subtitle: const Text('Off unless you turn it on. This version '
              'doesn’t send anything yet; your choice applies once '
              'stats are added. Turning it off deletes the random ID.'),
          value: widget.settings.shareStats,
          onChanged: (v) => widget.channel.update({'shareStats': v}),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('See what would be shared'),
            onPressed: () => _showWhatWouldBeShared(context),
          ),
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
                child: RopePreview(
                    style: RopeStyle.thread, charm: Charm.goldBead)),
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
