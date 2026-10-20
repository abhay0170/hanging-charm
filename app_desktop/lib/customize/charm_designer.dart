import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../charms/charm.dart';
import '../charms/charm_design.dart';
import '../charms/photo_charm.dart' show FrameFinish;
import '../charms/text_charm.dart' show NameFont;
import '../charms/user_charms.dart';
import 'photo_charm_editor.dart' show loadPhoto;

/// Builds a charm from layers (photos, words, stickers) on a base with a
/// border. Pops with the saved [Charm], or null if cancelled.
class CharmDesigner extends StatefulWidget {
  const CharmDesigner({
    super.key,
    required this.userCharms,
    required this.pickImage,
  });

  final UserCharms userCharms;

  /// Shows the picture picker; null if cancelled.
  final Future<String?> Function() pickImage;

  @override
  State<CharmDesigner> createState() => _CharmDesignerState();
}

class _CharmDesignerState extends State<CharmDesigner> {
  static const double _previewWidth = 300;

  var _design = const CharmDesign(layers: [
    StickerLayer(Icons.star_rounded, center: Offset(0.5, 0.5), scale: 0.55),
  ]);
  int? _selected = 0;
  final _name = TextEditingController(text: 'My design');
  final _words = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _words.dispose();
    super.dispose();
  }

  Size get _previewSize => Size(_previewWidth,
      _previewWidth * _design.artBox.height / _design.artBox.width);

  /// From a point on the preview to art-box units.
  Offset _toArt(Offset p) => p * (_design.artBox.width / _previewWidth);

  DesignLayer? get _layer =>
      _selected == null ? null : _design.layers[_selected!];

  void _replace(int index, DesignLayer layer) {
    final layers = [..._design.layers]..[index] = layer;
    setState(() => _design = _design.copyWith(layers: layers));
  }

  void _add(DesignLayer layer) {
    setState(() {
      _design = _design.copyWith(layers: [..._design.layers, layer]);
      _selected = _design.layers.length - 1;
    });
    _syncWords();
  }

  void _select(int? index) {
    setState(() => _selected = index);
    _syncWords();
  }

  /// Keeps the words box showing the selected words layer's text.
  void _syncWords() {
    final layer = _layer;
    if (layer is TextLayer && _words.text != layer.text) {
      _words.text = layer.text;
    }
  }

  Future<void> _addPhoto() async {
    final path = await widget.pickImage();
    if (path == null || !mounted) return;
    final image = await loadPhoto(path, maxSide: 800);
    if (!mounted) return;
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That picture couldn’t be opened.')));
      return;
    }
    _add(PhotoLayer(image, scale: 1));
  }

  void _move(int delta) {
    final i = _selected;
    if (i == null) return;
    final j = (i + delta).clamp(0, _design.layers.length - 1);
    if (i == j) return;
    final layers = [..._design.layers];
    final layer = layers.removeAt(i);
    layers.insert(j, layer);
    setState(() {
      _design = _design.copyWith(layers: layers);
      _selected = j;
    });
  }

  void _deleteLayer() {
    final i = _selected;
    if (i == null) return;
    setState(() {
      _design = _design.copyWith(layers: [..._design.layers]..removeAt(i));
      _selected = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final png = await _design.renderPng();
    final charm = widget.userCharms.add(
      name: _name.text,
      png: png,
      description: 'Your own design.',
      size: _design.charmSize,
      mass: _design.base == DesignBase.none ? 8 : 11,
      hang: _design.hang,
    );
    if (mounted) Navigator.of(context).pop<Charm>(charm);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget heading(String s) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(s, style: text.titleSmall));

    Widget chips<T>(List<T> values, T selected, String Function(T) label,
            void Function(T) pick,
            {Widget? Function(T)? avatar}) =>
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in values)
            ChoiceChip(
              avatar: avatar?.call(v),
              label: Text(label(v)),
              selected: v == selected,
              onSelected: (_) => pick(v),
            ),
        ]);

    final layer = _layer;

    return Scaffold(
      appBar: AppBar(title: const Text('Design your own charm')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- The charm ----
            SizedBox(
              width: _previewWidth,
              child: Column(children: [
                const SizedBox(height: 16),
                Listener(
                  onPointerSignal: (event) {
                    final i = _selected;
                    if (event is PointerScrollEvent && i != null) {
                      final l = _design.layers[i];
                      _replace(i,
                          l.placed(scale: l.scale - event.scrollDelta.dy / 800));
                    }
                  },
                  child: GestureDetector(
                    onTapDown: (d) =>
                        _select(_design.layerAt(_toArt(d.localPosition))),
                    onPanStart: (d) {
                      final hit = _design.layerAt(_toArt(d.localPosition));
                      if (hit != null) _select(hit);
                    },
                    onPanUpdate: (d) {
                      final i = _selected;
                      if (i == null) return;
                      final delta = _toArt(d.delta);
                      final c = _design.contentRect;
                      final l = _design.layers[i];
                      _replace(
                          i,
                          l.placed(
                              center: l.center +
                                  Offset(delta.dx / c.width, delta.dy / c.height)));
                    },
                    child: CustomPaint(
                      size: _previewSize,
                      painter: _DesignPainter(_design, _selected, scheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Click a layer to select it. Drag to move it, scroll to '
                    'resize it.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: 32),
            // ---- The controls ----
            Expanded(
              child: ListView(children: [
                heading('Add'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Photo'),
                      onPressed: _addPhoto),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.text_fields),
                      label: const Text('Words'),
                      onPressed: () => _add(const TextLayer('Love'))),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  for (final icon in stickers)
                    IconButton.outlined(
                      tooltip: 'Add sticker',
                      icon: Icon(icon, size: 20),
                      onPressed: () => _add(StickerLayer(icon)),
                    ),
                ]),
                if (layer != null) ...[
                  heading(switch (layer) {
                    PhotoLayer() => 'Selected: photo',
                    TextLayer() => 'Selected: words',
                    StickerLayer() => 'Selected: sticker',
                  }),
                  if (layer is TextLayer) ...[
                    TextField(
                      controller: _words,
                      maxLength: 14,
                      style: const TextStyle(
                          fontFamilyFallback: ['Nirmala UI', 'Segoe UI']),
                      decoration: const InputDecoration(
                          labelText: 'Words',
                          hintText: 'English, हिन्दी or தமிழ்'),
                      onChanged: (v) =>
                          _replace(_selected!, layer.withStyle(text: v)),
                    ),
                    chips(NameFont.values, layer.font, (f) => f.label,
                        (f) => _replace(_selected!, layer.withStyle(font: f))),
                    const SizedBox(height: 8),
                  ],
                  if (layer is TextLayer || layer is StickerLayer)
                    chips(
                      LayerInk.values,
                      switch (layer) {
                        TextLayer(:final ink) => ink,
                        StickerLayer(:final ink) => ink,
                        _ => LayerInk.metal,
                      },
                      (i) => i.label,
                      (i) => _replace(
                          _selected!,
                          switch (layer) {
                            TextLayer() => layer.withStyle(ink: i),
                            StickerLayer() => layer.withInk(i),
                            _ => layer,
                          }),
                      avatar: (i) => CircleAvatar(
                          backgroundColor:
                              i.color ?? _design.finish.middle),
                    ),
                  Row(children: [
                    const SizedBox(width: 48, child: Text('Size')),
                    Expanded(
                      child: Slider(
                        value: layer.scale,
                        min: DesignLayer.minScale,
                        max: DesignLayer.maxScale,
                        onChanged: (v) =>
                            _replace(_selected!, layer.placed(scale: v)),
                      ),
                    ),
                  ]),
                  Row(children: [
                    const SizedBox(width: 48, child: Text('Turn')),
                    Expanded(
                      child: Slider(
                        value: layer.rotation.clamp(-math.pi, math.pi),
                        min: -math.pi,
                        max: math.pi,
                        onChanged: (v) =>
                            _replace(_selected!, layer.placed(rotation: v)),
                      ),
                    ),
                  ]),
                  Wrap(spacing: 8, children: [
                    TextButton.icon(
                        icon: const Icon(Icons.flip_to_front),
                        label: const Text('Forward'),
                        onPressed: () => _move(1)),
                    TextButton.icon(
                        icon: const Icon(Icons.flip_to_back),
                        label: const Text('Back'),
                        onPressed: () => _move(-1)),
                    TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                        onPressed: _deleteLayer),
                  ]),
                ],
                heading('Base'),
                chips(DesignBase.values, _design.base, (b) => b.label,
                    (b) => setState(() => _design = _design.copyWith(base: b))),
                if (_design.base != DesignBase.none) ...[
                  heading('Fill'),
                  chips(
                    BaseFill.values,
                    _design.fill,
                    (f) => f.label,
                    (f) => setState(() => _design = _design.copyWith(fill: f)),
                    avatar: (f) => CircleAvatar(
                        backgroundColor: f.enamel ?? f.metal!.middle),
                  ),
                  heading('Border'),
                  chips(DesignBorder.values, _design.border, (b) => b.label,
                      (b) =>
                          setState(() => _design = _design.copyWith(border: b))),
                ],
                heading('Metal'),
                chips(
                  FrameFinish.values,
                  _design.finish,
                  (f) => f.label,
                  (f) => setState(() => _design = _design.copyWith(finish: f)),
                  avatar: (f) => CircleAvatar(backgroundColor: f.middle),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _name,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: const Text('Save and hang'),
                    onPressed:
                        _saving || _design.layers.isEmpty && _design.base == DesignBase.none
                            ? null
                            : _save,
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignPainter extends CustomPainter {
  _DesignPainter(this.design, this.selected, this.highlight);

  final CharmDesign design;
  final int? selected;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    design.paint(canvas, size);
    if (selected != null) {
      design.paintSelection(canvas, size, selected!, highlight);
    }
  }

  @override
  bool shouldRepaint(_DesignPainter old) =>
      old.design != design || old.selected != selected;
}
