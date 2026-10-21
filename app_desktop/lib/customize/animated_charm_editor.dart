import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../charms/charm.dart';
import '../charms/user_charms.dart';

/// Makes a charm from an animated GIF or WebP: shows how it will look,
/// takes a name and a size. Pops with the saved [Charm], or null if
/// cancelled.
class AnimatedCharmEditor extends StatefulWidget {
  const AnimatedCharmEditor({
    super.key,
    required this.userCharms,
    required this.bytes,
    required this.extension,
    required this.frameCount,
    this.suggestedName = '',
  });

  final UserCharms userCharms;
  final Uint8List bytes;

  /// `gif` or `webp`.
  final String extension;
  final int frameCount;
  final String suggestedName;

  @override
  State<AnimatedCharmEditor> createState() => _AnimatedCharmEditorState();
}

class _AnimatedCharmEditorState extends State<AnimatedCharmEditor> {
  late final _name = TextEditingController(text: widget.suggestedName);
  double _size = 48;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _saving = true);
    final charm = widget.userCharms.add(
      name: _name.text,
      bytes: widget.bytes,
      extension: widget.extension,
      description: 'Your animation.',
      size: _size,
    );
    Navigator.of(context).pop<Charm>(charm);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tooMany = widget.frameCount > 120;
    return Scaffold(
      appBar: AppBar(title: const Text('New animated charm')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 300,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    height: 260,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    // Image.memory plays the animation itself.
                    child: Image.memory(
                      widget.bytes,
                      height: _size * 3.5,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.frameCount} frames',
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
                    controller: _name,
                    autofocus: true,
                    maxLength: 30,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  Text('Size', style: text.titleSmall),
                  Slider(
                    value: _size,
                    min: Charm.minSize,
                    max: Charm.maxSize,
                    divisions: 10,
                    label: '${_size.round()}',
                    onChanged: (v) => setState(() => _size = v),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'It plays while it hangs, and stops when the charm is '
                    'hidden. Animations use a little more power than a '
                    'still charm.'
                    '${tooMany ? ' Only the first 120 frames are used.' : ''}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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
                        icon: const Icon(Icons.check),
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
