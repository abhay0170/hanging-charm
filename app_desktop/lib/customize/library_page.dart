import 'package:flutter/material.dart';

import '../charms/charm.dart';
import '../festivals/festival_calendar.dart';
import '../settings/app_settings.dart';
import 'customize_channel.dart';
import 'glass.dart';
import 'rope_preview.dart';

/// The Library: a search box and filters over a grid of every charm, with
/// the festival that is near and the charm of the day on top.
class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
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
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  /// 'all', or a collection's id.
  String _filter = 'all';
  String _query = '';

  Future<void> _newCharm() async {
    final start = await showDialog<VoidCallback>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text('Make a new charm',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    'What you make stays on this computer.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Glass.muted),
                  ),
                ),
                _MakeOption(
                  icon: Icons.add_photo_alternate_outlined,
                  title: 'From a photo',
                  caption: 'Put someone, or something, in a frame.',
                  onTap: () => Navigator.of(context).pop(widget.onNewFromPhoto),
                ),
                _MakeOption(
                  icon: Icons.text_fields,
                  title: 'From a name',
                  caption: 'A name or word in English, Hindi, Tamil or Malayalam.',
                  onTap: () => Navigator.of(context).pop(widget.onNewFromName),
                ),
                _MakeOption(
                  icon: Icons.favorite_border,
                  title: 'A locket',
                  caption: 'Tap it and it opens to show a photo.',
                  onTap: () => Navigator.of(context).pop(widget.onNewLocket),
                ),
                _MakeOption(
                  icon: Icons.animation,
                  title: 'Animated',
                  caption: 'A GIF or animated WebP that plays while it hangs.',
                  onTap: () => Navigator.of(context).pop(widget.onNewAnimated),
                ),
                _MakeOption(
                  icon: Icons.layers_outlined,
                  title: 'Design your own',
                  caption: 'Photos, words and stickers on a base you choose.',
                  onTap: () => Navigator.of(context).pop(widget.onDesign),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    start?.call();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final catalog = widget.catalog;
    final channel = widget.channel;
    final text = Theme.of(context).textTheme;
    // An unknown saved charm shows as the bead, so mark the bead chosen.
    final chosen = catalog.charmFor(settings.charmId).id;

    // Every charm with the name of the collection it is in; the user's own
    // first.
    final entries = <(Charm, String, String)>[
      for (final c in catalog.collections)
        if (c.id == CharmCatalog.userCollectionId)
          for (final charm in c.charms) (charm, c.id, 'Mine'),
      for (final c in catalog.collections)
        if (c.id != CharmCatalog.userCollectionId)
          for (final charm in c.charms) (charm, c.id, c.name),
    ];
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final e in entries)
        if ((_filter == 'all' || e.$2 == _filter) &&
            (query.isEmpty ||
                e.$1.name.toLowerCase().contains(query) ||
                e.$1.description.toLowerCase().contains(query)))
          e,
    ];

    final hasMine = entries.any((e) => e.$2 == CharmCatalog.userCollectionId);
    final filters = <(String, String)>[
      ('all', 'All'),
      for (final c in catalog.collections)
        if (c.id != CharmCatalog.userCollectionId) (c.id, c.name),
      if (hasMine) (CharmCatalog.userCollectionId, 'Mine'),
    ];
    // If the filter's collection vanished (the last charm of mine was
    // deleted), fall back to everything.
    final filter = filters.any((f) => f.$1 == _filter) ? _filter : 'all';

    final roomOnRope = settings.extraCharmIds.length < AppSettings.maxExtras;

    // ---- The festival that is near, and the charm of the day ----
    final today = DateTime.now();
    final near = widget.festivals.near(today);
    final pool = [
      for (final c in catalog.collections)
        if (c.id != CharmCatalog.userCollectionId) ...c.charms,
    ].where((c) => !c.isBuiltIn).toList();
    final everyday = [
      for (final c in catalog.collections)
        if (c.id != CharmCatalog.userCollectionId && c.id != 'festival')
          ...c.charms,
    ].where((c) => !c.isBuiltIn).toList();
    final pick =
        widget.festivals.charmOfTheDay(today, pool, everyday: everyday);

    Widget banner({
      required Charm charm,
      required String title,
      required String caption,
      required bool lit,
    }) =>
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GlassCard(
            glowing: lit,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(width: 34, height: 34, child: CharmArt(charm: charm)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      const SizedBox(height: 1),
                      Text(caption,
                          style: text.bodySmall?.copyWith(color: Glass.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                lit
                    ? FilledButton(
                        onPressed: () => channel.update({'charm': charm.id}),
                        child: const Text('Hang it'))
                    : OutlinedButton(
                        onPressed: () => channel.update({'charm': charm.id}),
                        child: const Text('Hang it')),
              ],
            ),
          ),
        );

    final banners = <Widget>[
      for (final season in near)
        for (final id in season.festival.charmIds.take(1))
          if (catalog.charmFor(id).id == id)
            banner(
              charm: catalog.charmFor(id),
              title: '${season.festival.name} · ${season.when}',
              caption: season.greetingNow
                  ? '${season.festival.greeting}!'
                  : 'The ${catalog.charmFor(id).name} is ready to hang.',
              lit: true,
            ),
      if (pick != null &&
          !near.any((s) => s.festival.charmIds.contains(pick.id)))
        banner(
          charm: pick,
          title: 'Charm of the day',
          caption: '${pick.name}. A different one every day.',
          lit: false,
        ),
    ];

    // ---- On the rope ----
    Widget onRope() {
      final main = catalog.charmFor(settings.charmId);
      Widget art(Charm c) =>
          SizedBox(width: 22, height: 22, child: CharmArt(charm: c));
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('On your rope', style: text.titleMedium),
              const SizedBox(height: 2),
              Text(
                  'Up to three charms hang from the same ring and knock '
                  'together. Press + on a charm to add it.',
                  style: text.bodySmall?.copyWith(color: Glass.muted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(avatar: art(main), label: Text('${main.name} (main)')),
                  for (var i = 0; i < settings.extraCharmIds.length; i++)
                    InputChip(
                      avatar: art(catalog.charmFor(settings.extraCharmIds[i])),
                      label: Text(
                          catalog.charmFor(settings.extraCharmIds[i]).name),
                      onDeleted: () => channel.update({
                        'extraCharms': [
                          for (var j = 0; j < settings.extraCharmIds.length; j++)
                            if (j != i) settings.extraCharmIds[j],
                        ],
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GlassPage(
      title: 'Library',
      subtitle: 'The charm that hangs on your screen. '
          '${catalog.all.length} to choose from.',
      maxWidth: 820,
      trailing: SizedBox(
        width: 230,
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search charms',
            prefixIcon: Icon(Icons.search, size: 18, color: Glass.faint),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 38, minHeight: 20),
          ),
        ),
      ),
      children: [
        ...banners,
        if (settings.extraCharmIds.isNotEmpty) onRope(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in filters)
              ChoiceChip(
                label: Text(f.$2),
                selected: filter == f.$1,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = f.$1),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: filter == f.$1 ? Glass.neon : Glass.muted,
                ),
                side: BorderSide(
                    color: filter == f.$1 ? Glass.neonLine : Glass.line),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          const gap = 12.0;
          final columns = (box.maxWidth / 136).floor().clamp(2, 6);
          final width = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              if (query.isEmpty && (filter == 'all' || filter == 'mine'))
                SizedBox(
                  width: width,
                  height: 142,
                  child: _NewTile(onTap: _newCharm),
                ),
              for (final e in shown)
                SizedBox(
                  width: width,
                  height: 142,
                  child: _CharmTile(
                    charm: e.$1,
                    group: e.$3,
                    selected: e.$1.id == chosen,
                    onChoose: () => channel.update({'charm': e.$1.id}),
                    onAdd: roomOnRope
                        ? () => channel.update({
                              'extraCharms': [
                                ...settings.extraCharmIds,
                                e.$1.id,
                              ],
                            })
                        : null,
                    onDelete:
                        e.$1.isUser ? () => widget.onDelete(e.$1) : null,
                  ),
                ),
            ],
          );
        }),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No charm matches “${_query.trim()}”.',
                  style: text.bodyMedium?.copyWith(color: Glass.muted)),
            ),
          ),
      ],
    );
  }
}

/// One option in the "Make a new charm" dialog.
class _MakeOption extends StatelessWidget {
  const _MakeOption({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Glass.buttonRadius),
      hoverColor: Glass.neon.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Glass.neon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  Text(caption,
                      style: text.bodySmall?.copyWith(color: Glass.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The first tile: make a charm of your own.
class _NewTile extends StatelessWidget {
  const _NewTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'New charm',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Glass.radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Glass.radius),
            border: Border.all(color: Glass.lineStrong),
            color: Glass.fill,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 26, color: Glass.neon),
              const SizedBox(height: 6),
              Text('New charm', style: text.titleSmall),
              const SizedBox(height: 2),
              Text('Photo, name, locket…',
                  style: text.bodySmall
                      ?.copyWith(color: Glass.faint, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A charm in the grid: its picture, name and collection. Hover shows
/// "add to rope" and, for the user's own, delete.
class _CharmTile extends StatefulWidget {
  const _CharmTile({
    required this.charm,
    required this.group,
    required this.selected,
    required this.onChoose,
    required this.onAdd,
    required this.onDelete,
  });

  final Charm charm;
  final String group;
  final bool selected;
  final VoidCallback onChoose;
  final VoidCallback? onAdd;
  final VoidCallback? onDelete;

  @override
  State<_CharmTile> createState() => _CharmTileState();
}

class _CharmTileState extends State<_CharmTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${widget.charm.name}, ${widget.group}',
        child: InkWell(
          onTap: widget.onChoose,
          borderRadius: BorderRadius.circular(Glass.radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Glass.radius),
              color: selected
                  ? Glass.neonFill
                  : (_hover ? Glass.fillStrong : Glass.fill),
              border: Border.all(
                  color: selected
                      ? Glass.neonLine
                      : (_hover ? Glass.lineStrong : Glass.line)),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                  child: Column(
                    children: [
                      Expanded(child: Center(child: CharmArt(charm: widget.charm))),
                      const SizedBox(height: 8),
                      Text(widget.charm.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall),
                      const SizedBox(height: 1),
                      Text(widget.group,
                          style: text.bodySmall
                              ?.copyWith(color: Glass.faint, fontSize: 11.5)),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Glass.neon),
                      child: const Icon(Icons.check,
                          size: 12, color: Color(0xFF04110F)),
                    ),
                  ),
                if (_hover && widget.onAdd != null)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: IconButton(
                      tooltip: 'Also hang it on the rope',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: widget.onAdd,
                    ),
                  ),
                if (_hover && widget.onDelete != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: widget.onDelete,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
