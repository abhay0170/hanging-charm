import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../charms/charm.dart';
import '../charms/locket.dart';
import '../charms/photo_charm.dart';
import '../charms/user_charms.dart';

/// Opens a picture file for the editor, shrunk to at most [maxSide] pixels
/// on its longer side (plenty for a charm, and quick to work with). Null if
/// the file can't be read as a picture.
Future<ui.Image?> loadPhoto(String path, {int maxSide = 1600}) async {
  try {
    final bytes = await File(path).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longer = descriptor.width > descriptor.height
        ? descriptor.width
        : descriptor.height;
    final shrink = longer > maxSide ? maxSide / longer : 1.0;
    final codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * shrink).round(),
      targetHeight: (descriptor.height * shrink).round(),
    );
    return (await codec.getNextFrame()).image;
  } on Object {
    return null;
  }
}

/// Makes a charm from a photo: frame, finish, zoom and position, and a
/// name. Pops with the saved [Charm], or null if cancelled.
class PhotoCharmEditor extends StatefulWidget {
  const PhotoCharmEditor({
    super.key,
    required this.photo,
    required this.userCharms,
    this.suggestedName = '',
    this.locket = false,
  });

  /// Make a locket (a cover that opens on this photo) instead of a plain
  /// photo charm.
  final bool locket;

  final ui.Image photo;
  final UserCharms userCharms;
  final String suggestedName;

  @override
  State<PhotoCharmEditor> createState() => _PhotoCharmEditorState();
}

class _PhotoCharmEditorState extends State<PhotoCharmEditor> {
  /// The preview's width on screen; its height follows the frame.
  static const double _previewWidth = 280;

  var _design = const PhotoCharmDesign();
  final _engraving = TextEditingController();

  /// A locket's preview: its cover, or its inside.
  bool _showInside = true;
  late final _name = TextEditingController(text: widget.suggestedName);
  bool _saving = false;

  @override
  void dispose() {
    _engraving.dispose();
    _name.dispose();
    super.dispose();
  }

  Size get _previewSize => Size(_previewWidth,
      _previewWidth * _design.artBox.height / _design.artBox.width);

  /// Dragging moves the photo; how far depends on how much of it is spare
  /// beyond the frame at this zoom.
  void _drag(Offset delta) {
    final photo = Size(
        widget.photo.width.toDouble(), widget.photo.height.toDouble());
    final scale = _previewWidth / _design.artBox.width;
    final area = _design.photoArea;
    final frame = Rect.fromLTWH(
        area.left * scale, area.top * scale, area.width * scale,
        area.height * scale);
    final drawn = _design.photoRect(photo, frame);
    final spareX = (drawn.width - frame.width) / 2;
    final spareY = (drawn.height - frame.height) / 2;
    setState(() => _design = _design.copyWith(
          offset: Offset(
            spareX > 0 ? _design.offset.dx - delta.dx / spareX : 0,
            spareY > 0 ? _design.offset.dy - delta.dy / spareY : 0,
          ),
        ));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final inside = await _design.renderPng(widget.photo);
    final cover = widget.locket
        ? await LocketDesign(photo: _design, engraving: _engraving.text)
            .renderCoverPng()
        : null;
    final charm = widget.userCharms.add(
      name: _name.text,
      // A locket hangs by its cover and keeps the photo for when it opens.
      png: cover ?? inside,
      openPng: cover == null ? null : inside,
      description: widget.locket
          ? 'Tap it to open.'
          : 'Made from your photo.',
      size: _design.charmSize,
      mass: 10,
      hang: _design.hang,
    );
    if (mounted) Navigator.of(context).pop<Charm>(charm);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.locket
              ? 'New locket'
              : 'New charm from a photo')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      setState(() => _design = _design.copyWith(
                          zoom: _design.zoom - event.scrollDelta.dy / 400));
                    }
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.move,
                    child: GestureDetector(
                      onPanUpdate: (d) => _drag(d.delta),
                      child: CustomPaint(
                        size: _previewSize,
                        painter: _PreviewPainter(
                            _design,
                            widget.photo,
                            widget.locket && !_showInside
                                ? LocketDesign(
                                    photo: _design,
                                    engraving: _engraving.text)
                                : null),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.locket) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Cover')),
                      ButtonSegment(value: true, label: Text('Inside')),
                    ],
                    selected: {_showInside},
                    onSelectionChanged: (v) =>
                        setState(() => _showInside = v.first),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                    widget.locket && !_showInside
                        ? 'This is how it hangs. Tap it to see inside.'
                        : 'Drag the photo to place it. Scroll to zoom.',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(width: 40),
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: _name,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Who or what is it?',
                    ),
                  ),
                  if (widget.locket) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _engraving,
                      maxLength: LocketDesign.maxEngraving,
                      onChanged: (_) => setState(() => _showInside = false),
                      style: const TextStyle(
                          fontFamilyFallback: ['Nirmala UI', 'Segoe UI']),
                      decoration: const InputDecoration(
                        labelText: 'Engraving on the cover',
                        hintText: 'An initial, or leave empty',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Frame', style: text.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final shape in FrameShape.values)
                        ChoiceChip(
                          label: Text(shape.label),
                          selected: _design.shape == shape,
                          onSelected: (_) => setState(() =>
                              _design = _design.copyWith(shape: shape)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Finish', style: text.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final finish in FrameFinish.values)
                        ChoiceChip(
                          avatar: CircleAvatar(backgroundColor: finish.middle),
                          label: Text(finish.label),
                          selected: _design.finish == finish,
                          onSelected: (_) => setState(() =>
                              _design = _design.copyWith(finish: finish)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Zoom', style: text.titleSmall),
                  Slider(
                    value: _design.zoom,
                    min: PhotoCharmDesign.minZoom,
                    max: PhotoCharmDesign.maxZoom,
                    onChanged: (v) =>
                        setState(() => _design = _design.copyWith(zoom: v)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your photo stays on this computer. The charm is saved '
                    'in your charms folder and can be deleted from the '
                    'Library.',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: const Text('Save and hang'),
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.design, this.photo, this.cover);

  final PhotoCharmDesign design;
  final ui.Image photo;

  /// Set to show a locket's cover instead of the photo.
  final LocketDesign? cover;

  @override
  void paint(Canvas canvas, Size size) => cover != null
      ? cover!.paintCover(canvas, size)
      : design.paint(canvas, size, photo);

  @override
  bool shouldRepaint(_PreviewPainter old) => true;
}
