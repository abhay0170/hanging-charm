import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:charm_physics/charm_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../charms/charm.dart';
import '../charms/user_charms.dart';
import '../festivals/festival_calendar.dart';
import '../privacy/usage_stats.dart';
import '../settings/app_settings.dart';
import '../settings/settings_store.dart';
import 'customize_channel.dart';
import 'glass.dart';
import 'animated_charm_editor.dart';
import 'charm_designer.dart';
import 'name_charm_editor.dart';
import 'photo_charm_editor.dart';
import 'rope_preview.dart';
import 'welcome_flow.dart';

const appName = 'Charm';
const appVersion = '0.1.0';


/// The Customize window: Library, Ropes & Layout, Settings and About.
/// Every change applies to the charm straight away; there is no Save.
class CustomizeApp extends StatelessWidget {
  const CustomizeApp({
    super.key,
    required this.channel,
    required this.catalog,
    this.festivals = FestivalCalendar.empty,
    this.welcome = false,
  });

  final CustomizeChannel channel;
  final CharmCatalog catalog;
  final FestivalCalendar festivals;

  /// Show the first-launch welcome instead of the tabs.
  final bool welcome;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$appName – Customize',
      debugShowCheckedModeBanner: false,
      theme: Glass.theme(),
      darkTheme: Glass.theme(),
      themeMode: ThemeMode.dark,
      builder: (context, child) => GlassBackground(child: child!),
      home: welcome
          ? WelcomeFlow(channel: channel, catalog: catalog)
          : _CustomizeHome(
              channel: channel, catalog: catalog, festivals: festivals),
    );
  }
}

class _CustomizeHome extends StatefulWidget {
  const _CustomizeHome(
      {required this.channel, required this.catalog, required this.festivals});

  final CustomizeChannel channel;
  final CharmCatalog catalog;
  final FestivalCalendar festivals;

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
  Future<void> _newFromPhoto({bool locket = false}) async {
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
            PhotoCharmEditor(
                photo: photo, userCharms: _userCharms, locket: locket)));
    photo.dispose();
    if (charm == null || !mounted) return;
    _refreshCatalog();
    widget.channel.update({'charm': charm.id});
  }

  /// Pick a GIF or animated WebP, check it moves, name it, save it, hang it.
  Future<void> _newAnimated() async {
    void say(String message) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    final path = await widget.channel.pickImage();
    if (path == null || !mounted) return;
    final lower = path.toLowerCase();
    final extension = lower.endsWith('.gif')
        ? 'gif'
        : lower.endsWith('.webp')
            ? 'webp'
            : null;
    if (extension == null) {
      say('Pick a GIF or an animated WebP.');
      return;
    }
    final file = File(path);
    if (await file.length() > _maxAnimationBytes) {
      say('That file is over 8 MB. Try a smaller or shorter one.');
      return;
    }
    final bytes = await file.readAsBytes();
    int frames;
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32);
      frames = codec.frameCount;
      codec.dispose();
    } on Object {
      frames = 0;
    }
    if (!mounted) return;
    if (frames < 2) {
      say(frames == 0
          ? 'That file couldn’t be opened.'
          : 'That picture doesn’t move. Use “New from a photo” instead.');
      return;
    }
    final name = path.split(RegExp(r'[\\/]')).last;
    final charm = await Navigator.of(context).push<Charm>(MaterialPageRoute(
        builder: (_) => AnimatedCharmEditor(
              userCharms: _userCharms,
              bytes: bytes,
              extension: extension,
              frameCount: frames,
              suggestedName: name.contains('.')
                  ? name.substring(0, name.lastIndexOf('.'))
                  : name,
            )));
    if (charm == null || !mounted) return;
    _refreshCatalog();
    widget.channel.update({'charm': charm.id});
  }

  static const int _maxAnimationBytes = 8 * 1024 * 1024;

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
              _GlassSidebar(
                tabs: _tabs,
                selected: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
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
                          festivals: widget.festivals,
                          channel: channel,
                          onNewFromPhoto: _newFromPhoto,
                          onNewAnimated: _newAnimated,
                          onNewLocket: () => _newFromPhoto(locket: true),
                          onNewFromName: _newFromName,
                          onDesign: _designYourOwn,
                          onDelete: _delete),
                      1 => _RopesPage(
                          settings: settings,
                          catalog: _catalog,
                          channel: channel),
                      2 => _SettingsPage(settings: settings, channel: channel),
                      _ => _AboutPage(
                          channel: channel, onReset: _refreshCatalog),
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

/// The tabs, on a pane of glass down the left.
class _GlassSidebar extends StatelessWidget {
  const _GlassSidebar({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<(IconData, IconData, String)> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      child: SizedBox(
        width: 176,
        height: double.infinity,
        child: GlassCard(
          radius: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
          child: Column(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                _SideTab(
                  icon: i == selected ? tabs[i].$2 : tabs[i].$1,
                  label: tabs[i].$3,
                  selected: i == selected,
                  onTap: () => onSelect(i),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SideTab extends StatelessWidget {
  const _SideTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Glass.neon.withValues(alpha: 0.14),
                      Glass.neon.withValues(alpha: 0.05),
                    ],
                  )
                : null,
            border: Border.all(
                color: selected ? Glass.neonLine : Colors.transparent),
            boxShadow: [
              if (selected)
                BoxShadow(
                    color: Glass.neon.withValues(alpha: 0.18), blurRadius: 20),
            ],
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 26, color: selected ? Glass.neon : Glass.muted),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? Glass.text : Glass.muted,
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
      padding: const EdgeInsets.fromLTRB(26, 22, 30, 32),
      children: [
        Text(title, style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle,
            style: text.bodyMedium?.copyWith(
                color: Glass.muted, fontSize: 16)),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => GlassLabel(text);
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
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 172,
      child: GlassCard(
        radius: 20,
        glowing: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 150, child: Center(child: picture)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text(title, style: text.titleSmall)),
                    if (selected)
                      const Icon(Icons.check_circle,
                          size: 18, color: Glass.neon),
                  ],
                ),
                const SizedBox(height: 2),
                Text(caption,
                    style: text.bodySmall?.copyWith(color: Glass.muted)),
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
    required this.festivals,
    required this.channel,
    required this.onNewFromPhoto,
    required this.onNewAnimated,
    required this.onNewLocket,
    required this.onNewFromName,
    required this.onDesign,
    required this.onDelete,
  });

  final AppSettings settings;
  final CharmCatalog catalog;
  final FestivalCalendar festivals;
  final CustomizeChannel channel;
  final VoidCallback onNewFromPhoto;
  final VoidCallback onNewAnimated;
  final VoidCallback onNewLocket;
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

    final roomOnRope = settings.extraCharmIds.length < AppSettings.maxExtras;

    Widget card(Charm charm) => Stack(
          children: [
            _ChoiceCard(
              picture: Padding(
                padding: const EdgeInsets.all(18),
                child: CharmArt(charm: charm),
              ),
              title: charm.name,
              caption: charm.description,
              selected: charm.id == chosen,
              onTap: () => channel.update({'charm': charm.id}),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: IconButton(
                tooltip: roomOnRope
                    ? 'Also hang it on the rope'
                    : 'The rope is full (${AppSettings.maxExtras + 1} charms)',
                icon: const Icon(Icons.add_circle_outline, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: roomOnRope
                    ? () => channel.update({
                          'extraCharms': [...settings.extraCharmIds, charm.id],
                        })
                    : null,
              ),
            ),
          ],
        );

    // The festivals near today, and a charm for the day.
    List<Widget> thisSeason() {
      final today = DateTime.now();
      final near = festivals.near(today);
      final pool = [
        for (final c in catalog.collections)
          if (c.id != CharmCatalog.userCollectionId) ...c.charms,
      ].where((c) => !c.isBuiltIn).toList();
      // An ordinary day picks from the everyday charms; the festival charms
      // come up on their own days.
      final everyday = [
        for (final c in catalog.collections)
          if (c.id != CharmCatalog.userCollectionId && c.id != 'festival')
            ...c.charms,
      ].where((c) => !c.isBuiltIn).toList();
      final pick = festivals.charmOfTheDay(today, pool, everyday: everyday);
      return [
        for (final season in near)
          section(
            '${season.festival.name} · ${season.when}',
            season.greetingNow
                ? '${season.festival.greeting}!'
                : 'Charms for the season. Press one to hang it.',
            [
              for (final id in season.festival.charmIds)
                if (catalog.charmFor(id).id == id) card(catalog.charmFor(id)),
            ],
          ),
        if (pick != null && !near.any((s) => s.festival.charmIds.contains(pick.id)))
          section(
            'Charm of the day',
            'A different one every day. Today: ${pick.name}.',
            [card(pick)],
          ),
      ];
    }

    Widget onRope() {
      final main = catalog.charmFor(settings.charmId);
      Widget art(Charm c) => SizedBox(width: 28, height: 28, child: CharmArt(charm: c));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('On your rope'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
                'Your main charm, and up to ${AppSettings.maxExtras} more '
                '(three in all) hanging from the same ring, one a little '
                'lower than the next. They swing, knock together and can each '
                'be picked up. Press + on a charm below to add it.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(avatar: art(main), label: Text('${main.name} (main)')),
              for (var i = 0; i < settings.extraCharmIds.length; i++)
                InputChip(
                  avatar: art(catalog.charmFor(settings.extraCharmIds[i])),
                  label: Text(catalog.charmFor(settings.extraCharmIds[i]).name),
                  onDeleted: () => channel.update({
                    'extraCharms': [
                      for (var j = 0; j < settings.extraCharmIds.length; j++)
                        if (j != i) settings.extraCharmIds[j],
                    ],
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return _Page(
      title: 'Library',
      subtitle: 'The charm that hangs on your screen. '
          '${catalog.all.length} to choose from.',
      children: [
        ...thisSeason(),
        if (settings.extraCharmIds.isNotEmpty) onRope(),
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
              caption: 'A name or word, in English, Hindi, Tamil or Malayalam.',
              onTap: onNewFromName,
            ),
            _NewCharmCard(
              icon: Icons.favorite_border,
              title: 'New locket',
              caption: 'Tap it and it opens to show a photo.',
              onTap: onNewLocket,
            ),
            _NewCharmCard(
              icon: Icons.animation,
              title: 'New animated',
              caption: 'A GIF or animated WebP that plays while it hangs.',
              onTap: onNewAnimated,
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
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 172,
      height: 222,
      child: GlassCard(
        radius: 20,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Glass.neon),
              const SizedBox(height: 10),
              Text(title, style: text.titleSmall),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(caption,
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: Glass.muted)),
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

  /// The chime volume while the slider is being dragged; the setting itself
  /// changes when it is let go (and the charm rings once at that volume).
  double? _draggedVolume;
  double? _draggedBreeze;
  static const _breezeNames = ['off', 'light', 'breezy', 'windy'];

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
    final s = widget.settings;
    final volume = _draggedVolume ?? s.soundVolume;
    final percent = (volume * 100).round();
    final breeze = _draggedBreeze ?? s.breeze;
    final text = Theme.of(context).textTheme;

    Widget toggle(String title, String subtitle, bool value,
            ValueChanged<bool>? onChanged) =>
        GlassRow(
          title: title,
          subtitle: subtitle,
          trailing: Switch(value: value, onChanged: onChanged),
        );

    Widget valueText(String shown) => SizedBox(
          width: 62,
          child: Text(shown,
              textAlign: TextAlign.right,
              style: text.bodyMedium?.copyWith(
                  color: Glass.neon,
                  shadows: [Shadow(color: Glass.neon, blurRadius: 10)])),
        );

    return _Page(
      title: 'Settings',
      subtitle: 'How the charm behaves on this computer.',
      children: [
        const _SectionTitle('Placement'),
        GlassGroup(rows: [
          GlassRow(
            wide: true,
            title: 'Where it hangs',
            subtitle: 'From the window you are using, from the top of the '
                'screen, or beside the left or right edge (where it stops at '
                'the screen’s edge). Drag the pin to slide it.',
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'window', label: Text('Window')),
                ButtonSegment(value: 'top', label: Text('Top')),
                ButtonSegment(value: 'left', label: Text('Left')),
                ButtonSegment(value: 'right', label: Text('Right')),
              ],
              selected: {s.followWindow ? 'window' : s.screenEdge.name},
              onSelectionChanged: (v) {
                final pick = v.first;
                widget.channel.update(pick == 'window'
                    ? {'followWindow': true}
                    : {'followWindow': false, 'screenEdge': pick});
              },
            ),
          ),
          toggle('Show charm', 'Hide it for a while without quitting.',
              s.charmVisible, (v) => widget.channel.update({'charmVisible': v})),
        ]),
        const _SectionTitle('Motion & sound'),
        GlassGroup(rows: [
          toggle(
              'Animate charms',
              'GIF charms play while they hang. Turn off to save power: they '
                  'show one still frame.',
              s.animateCharms,
              (v) => widget.channel.update({'animateCharms': v})),
          GlassRow(
            wide: true,
            title: 'Chime volume',
            subtitle: 'A soft bell when the charm is knocked, thrown or a '
                'locket opens. Off until you choose a volume. The sound is '
                'made on this computer; nothing is downloaded.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                valueText(percent == 0 ? 'Off' : '$percent%'),
                SizedBox(
                  width: 260,
                  child: Slider(
                    value: volume,
                    divisions: 10,
                    label: 'Volume',
                    onChanged: (v) => setState(() => _draggedVolume = v),
                    onChangeEnd: (v) {
                      setState(() => _draggedVolume = null);
                      widget.channel.update({'soundVolume': v});
                    },
                  ),
                ),
              ],
            ),
          ),
          GlassRow(
            wide: true,
            title: 'Breeze',
            subtitle: 'A gentle breeze sways the charm now and then. It is '
                'made on this computer: no weather, no internet, no '
                'location. Off until you choose. It keeps the charm moving, '
                'so it uses a little power (and pauses on battery).',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                valueText(_breezeNames[(breeze * 3).round()]),
                SizedBox(
                  width: 260,
                  child: Slider(
                    value: breeze,
                    divisions: 3,
                    onChanged: (v) => setState(() => _draggedBreeze = v),
                    onChangeEnd: (v) {
                      setState(() => _draggedBreeze = null);
                      widget.channel.update({'breeze': v});
                    },
                  ),
                ),
              ],
            ),
          ),
          toggle(
              'Sway when I shake the mouse',
              'Shake the mouse and the charm gives a small sway. Off unless '
                  'you turn it on, because it watches where the cursor goes '
                  '(nothing is kept or sent).',
              s.reactToWiggle,
              (v) => widget.channel.update({'reactToWiggle': v})),
        ]),
        const _SectionTitle('System'),
        GlassGroup(rows: [
          toggle(
              'Save power on battery',
              'On battery or in Battery Saver, the charm draws fewer frames '
                  'and animated charms hold still. If Windows’ “Show '
                  'animations” is off, animations always hold still.',
              s.savePower,
              (v) => widget.channel.update({'savePower': v})),
          toggle(
              'Launch at login',
              'Start the charm when you sign in to Windows.',
              _launchAtLogin ?? false,
              _launchAtLogin == null ? null : _setLaunchAtLogin),
        ]),
        const _SectionTitle('Privacy'),
        GlassGroup(rows: [
          const GlassRow(
            leading: Icon(Icons.lock_outline, color: Glass.neon),
            title: 'Works completely offline',
            subtitle: 'The charm makes no network requests. Nothing about '
                'you, your screen or your files leaves this computer.',
          ),
          GlassRow(
            wide: true,
            title: 'Share anonymous usage stats',
            subtitle: 'Off unless you turn it on. This version doesn’t send '
                'anything yet; your choice applies once stats are added. '
                'Turning it off deletes the random ID.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => _showWhatWouldBeShared(context),
                  child: const Text('See what would be shared'),
                ),
                const SizedBox(width: 14),
                Switch(
                  value: s.shareStats,
                  onChanged: (v) => widget.channel.update({'shareStats': v}),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 18),
        SelectableText(
          'Saved in ${SettingsStore.defaultDirectory().path}\\settings.json',
          style: text.bodySmall?.copyWith(color: Glass.faint),
        ),
      ],
    );
  }
}

// ---- About ----

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.channel, required this.onReset});

  final CustomizeChannel channel;

  /// Called after everything is deleted, so the Library forgets the charms.
  final VoidCallback onReset;

  static const _privacyPoints = [
    'Charm never connects to the internet. It has no code for it. Nothing '
        'about you, your screen or your files leaves this computer.',
    'It looks at where the mouse is (to know when you touch the charm) and, '
        'if you hang it from your active window, where that window is. It '
        'never reads what is in your windows, and never watches the keyboard.',
    'Photos you use for a charm are not copied or changed. The charm keeps '
        'its own small picture.',
    'Usage stats are off. This version does not send anything even if you '
        'turn them on in Settings.',
  ];

  Future<void> _openFolder(BuildContext context) async {
    final directory = SettingsStore.defaultDirectory();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!directory.existsSync()) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Nothing is saved yet, so there is no folder.')));
        return;
      }
      await Process.run('explorer.exe', [directory.path]);
    } on Object {
      messenger.showSnackBar(
          const SnackBar(content: Text('The folder could not be opened.')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all my data?'),
        content: const Text(
          'This puts every setting back to how it was when you first '
          'installed Charm, deletes the charms you made, deletes the error '
          'log, and stops Charm starting with Windows.\n\n'
          'Photos you used for charms are not touched. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await channel.resetAll();
    onReset();
    messenger.showSnackBar(
        const SnackBar(content: Text('Everything was deleted.')));
  }

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
        const _SectionTitle('Your privacy'),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Column(
            children: [
              for (final point in _privacyPoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3, right: 12),
                        child: Icon(Icons.check_circle_outline,
                            size: 18, color: Glass.neon),
                      ),
                      Expanded(child: Text(point, style: text.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Your data'),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Everything Charm saves is in one folder on this computer: '
                'your settings, the charms you made, and a small log of '
                'errors.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 4),
              SelectableText(SettingsStore.defaultDirectory().path,
                  style: text.bodySmall?.copyWith(color: Glass.muted)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Open the folder'),
                    onPressed: () => _openFolder(context),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete all my data…'),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const _SectionTitle('Keyboard'),
        Text('Ctrl+1 to Ctrl+4  switch tabs\nCtrl+W  close this window',
            style: text.bodyMedium?.copyWith(height: 1.6)),
      ],
    );
  }
}
