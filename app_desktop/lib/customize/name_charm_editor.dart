import 'package:flutter/material.dart';

import '../charms/charm.dart';
import '../charms/photo_charm.dart' show FrameFinish;
import '../charms/text_charm.dart';
import '../charms/user_charms.dart';

/// Makes a charm from a name or short word, in English, Hindi, Tamil or Malayalam.
/// Pops with the saved [Charm], or null if cancelled.
class NameCharmEditor extends StatefulWidget {
  const NameCharmEditor({super.key, required this.userCharms});

  final UserCharms userCharms;

  @override
  State<NameCharmEditor> createState() => _NameCharmEditorState();
}

class _NameCharmEditorState extends State<NameCharmEditor> {
  static const double _previewWidth = 300;

  var _design = const NameCharmDesign();
  final _text = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(
      () => setState(() => _design = _design.copyWith(text: _text.text)),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final png = await _design.renderPng();
    final charm = widget.userCharms.add(
      name: _design.displayText,
      png: png,
      description: 'Your words, in ${_design.finish.label.toLowerCase()}.',
      size: _design.charmSize,
      // Letters and bars are slim and light; tags a little heavier.
      mass: _design.shape == NameShape.letters ? 8 : 10,
      hang: _design.hang,
    );
    if (mounted) Navigator.of(context).pop<Charm>(charm);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final indic = switch (NameCharmDesign.scriptOf(_design.displayText)) {
      NameScript.devanagari || NameScript.tamil || NameScript.malayalam => true,
      _ => false,
    };
    final empty = _design.displayText.isEmpty;

    Widget chips<T>(
      List<T> values,
      T selected,
      String Function(T) label,
      void Function(T) pick, {
      bool enabled = true,
    }) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: enabled ? (_) => pick(v) : null,
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('New charm from a name')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _previewWidth,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  CustomPaint(
                    size: Size(
                      _previewWidth,
                      _previewWidth *
                          _design.artBox.height /
                          _design.artBox.width,
                    ),
                    painter: _PreviewPainter(_design),
                  ),
                  const SizedBox(height: 16),
                  if (empty)
                    Text(
                      'Type a name to see it here.',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: _text,
                    autofocus: true,
                    maxLength: NameCharmDesign.maxLength,
                    style: const TextStyle(
                      fontFamilyFallback: ['Nirmala UI', 'Segoe UI'],
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Name or word',
                      hintText: 'English, हिन्दी, தமிழ் or മലയാളം',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Shape', style: text.titleSmall),
                  const SizedBox(height: 8),
                  chips(
                    NameShape.values,
                    _design.shape,
                    (s) => s.label,
                    (s) => setState(() => _design = _design.copyWith(shape: s)),
                  ),
                  const SizedBox(height: 20),
                  Text('Finish', style: text.titleSmall),
                  const SizedBox(height: 8),
                  chips(
                    FrameFinish.values,
                    _design.finish,
                    (f) => f.label,
                    (f) =>
                        setState(() => _design = _design.copyWith(finish: f)),
                  ),
                  const SizedBox(height: 20),
                  Text('Lettering', style: text.titleSmall),
                  const SizedBox(height: 8),
                  chips(
                    NameFont.values,
                    _design.font,
                    (f) => f.label,
                    (f) => setState(() => _design = _design.copyWith(font: f)),
                    enabled: !indic,
                  ),
                  if (indic)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Hindi, Tamil and Malayalam are set in Nirmala UI, which '
                        'shapes their letters properly.',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
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
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Save and hang'),
                        onPressed: _saving || empty ? null : _save,
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
  _PreviewPainter(this.design);

  final NameCharmDesign design;

  @override
  void paint(Canvas canvas, Size size) {
    if (design.displayText.isEmpty) return;
    design.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.design != design;
}
