import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/canvas_item.dart';
import '../../../providers/board_provider.dart';
import '../../../services/clipboard_service.dart';

class CardBody extends StatefulWidget {
  final CanvasNote note;

  const CardBody({super.key, required this.note});

  @override
  State<CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends State<CardBody> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.note.textContent);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pasteIntoNote() async {
    final pasted = await ClipboardService.processClipboard(
      targetX: widget.note.x,
      targetY: widget.note.y,
    );

    if (pasted == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty or unsupported.')),
        );
      }
      return;
    }

    final hasExistingContent =
        widget.note.contentType == NoteContentType.IMAGE
            ? widget.note.imageUrl.isNotEmpty
            : widget.note.textContent.isNotEmpty &&
                widget.note.textContent != 'Click to edit note content...';

    if (hasExistingContent) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF252526),
          title: const Text(
            'Overwrite Note Content?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This note already contains content. Replace it with the clipboard content?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Overwrite',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() {
      widget.note.contentType = pasted.contentType;
      widget.note.textContent = pasted.textContent;
      widget.note.imageUrl = pasted.imageUrl;
      if (pasted.contentType == NoteContentType.TEXT) {
        _textController.text = pasted.textContent;
      }
    });
  }

  Future<void> _showCustomHighlightPicker() async {
    final existing = widget.note.highlightColor ?? Colors.white;
    final existingHsv = HSVColor.fromColor(existing);
    var hue = existingHsv.hue;
    var saturation = existingHsv.saturation;
    var value = existingHsv.value;

    final selected = await showDialog<Color?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final color = HSVColor.fromAHSV(1, hue, saturation, value).toColor();

          return AlertDialog(
            backgroundColor: const Color(0xFF252526),
            title: const Text('Choose Note Color', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 64,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _colorSlider(
                    label: 'Hue',
                    value: hue,
                    min: 0,
                    max: 360,
                    onChanged: (v) => setDialogState(() => hue = v),
                  ),
                  _colorSlider(
                    label: 'Saturation',
                    value: saturation,
                    min: 0,
                    max: 1,
                    onChanged: (v) => setDialogState(() => saturation = v),
                  ),
                  _colorSlider(
                    label: 'Brightness',
                    value: value,
                    min: 0,
                    max: 1,
                    onChanged: (v) => setDialogState(() => value = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, color),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );

    if (selected != null && mounted) {
      context.read<BoardProvider>().setNoteHighlight(widget.note.id, selected.value);
    }
  }

  Widget _colorSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _clearHighlight() {
    context.read<BoardProvider>().setNoteHighlight(widget.note.id, null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildContentWidget(),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notes, size: 15),
                color: widget.note.contentType == NoteContentType.TEXT ? Colors.blueAccent : Colors.grey,
                tooltip: 'Text Note',
                onPressed: () => setState(() => widget.note.contentType = NoteContentType.TEXT),
              ),
              IconButton(
                icon: const Icon(Icons.grid_on, size: 15),
                color: widget.note.contentType == NoteContentType.TABLE ? Colors.greenAccent : Colors.grey,
                tooltip: 'Spreadsheet Table',
                onPressed: () => setState(() => widget.note.contentType = NoteContentType.TABLE),
              ),
              IconButton(
                icon: const Icon(Icons.image_outlined, size: 15),
                color: widget.note.contentType == NoteContentType.IMAGE ? Colors.amberAccent : Colors.grey,
                tooltip: 'Image Link',
                onPressed: () => setState(() => widget.note.contentType = NoteContentType.IMAGE),
              ),
              const VerticalDivider(color: Colors.white24, width: 12),
              IconButton(
                icon: const Icon(Icons.content_paste_go, size: 15, color: Colors.orangeAccent),
                tooltip: 'Paste Clipboard into Note',
                onPressed: _pasteIntoNote,
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.palette_outlined,
                  size: 15,
                  color: widget.note.highlightColor != null ? Colors.amber : Colors.grey,
                ),
                tooltip: 'Highlight Note',
                onSelected: (value) {
                  switch (value) {
                    case 'RED':
                      context.read<BoardProvider>().setNoteHighlight(widget.note.id, Colors.red.shade700.value);
                      break;
                    case 'GREEN':
                      context.read<BoardProvider>().setNoteHighlight(widget.note.id, Colors.green.shade700.value);
                      break;
                    case 'CUSTOM':
                      _showCustomHighlightPicker();
                      break;
                    case 'CLEAR':
                      _clearHighlight();
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'RED', child: Text('Red')),
                  PopupMenuItem(value: 'GREEN', child: Text('Green')),
                  PopupMenuItem(value: 'CUSTOM', child: Text('Custom...')),
                  PopupMenuItem(value: 'CLEAR', child: Text('Clear Highlight')),
                ],
              ),
              // Status Emoji Picker with Instant Board Provider Dispatch
              PopupMenuButton<String>(
                icon: Icon(Icons.add_reaction_outlined, size: 15, color: widget.note.statusBadge != null ? Colors.amber : Colors.grey),
                tooltip: 'Set Status Badge',
                onSelected: (emoji) {
                  final newBadge = emoji == 'CLEAR' ? null : emoji;
                  context.read<BoardProvider>().setNoteBadge(widget.note.id, newBadge);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '✅', child: Text('✅ Done')),
                  const PopupMenuItem(value: '❌', child: Text('❌ Rejected')),
                  const PopupMenuItem(value: '⏳', child: Text('⏳ Pending')),
                  const PopupMenuItem(value: '⚠️', child: Text('⚠️ Warning')),
                  const PopupMenuItem(value: '💡', child: Text('💡 Idea')),
                  const PopupMenuItem(value: 'CLEAR', child: Text('🚫 Clear Badge', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentWidget() {
    switch (widget.note.contentType) {
      case NoteContentType.TEXT:
      // Monospace font styling preserves spaces, tabs, and ASCII diagrams
        return TextField(
          controller: _textController,
          maxLines: null,
          expands: true,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.3,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Type text here...',
            hintStyle: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
          ),
          onChanged: (val) => widget.note.textContent = val,
        );

      case NoteContentType.TABLE:
        return _buildGoogleSheetsTable();

      case NoteContentType.IMAGE:
        return _buildImageWidget();
    }
  }

  Widget _buildImageWidget() {
    String url = widget.note.imageUrl.trim();

    if (url.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E1E)),
          icon: const Icon(Icons.link, size: 14),
          label: const Text('Enter Image Link', style: TextStyle(fontSize: 11)),
          onPressed: () async {
            final newUrl = await _showUrlDialog();
            if (newUrl != null && newUrl.isNotEmpty) {
              setState(() => widget.note.imageUrl = newUrl);
            }
          },
        ),
      );
    }

    if (url.startsWith('data:image/')) {
      try {
        final base64Str = url.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: widget.note.fitAsBoxFit);
      } catch (_) {
        return const Center(child: Text('Invalid image data', style: TextStyle(color: Colors.redAccent)));
      }
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Fit: ', style: TextStyle(color: Colors.grey, fontSize: 10)),
            DropdownButton<ImageFitMode>(
              value: widget.note.imageFit,
              dropdownColor: const Color(0xFF252526),
              isDense: true,
              style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
              items: ImageFitMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => widget.note.imageFit = val);
              },
            ),
          ],
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              url,
              fit: widget.note.fitAsBoxFit,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                final proxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
                return Image.network(
                  proxyUrl,
                  fit: widget.note.fitAsBoxFit,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image, color: Colors.redAccent, size: 24),
                        const SizedBox(height: 4),
                        const Text('Failed to load image', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                        TextButton(
                          onPressed: () async {
                            final newUrl = await _showUrlDialog();
                            if (newUrl != null && newUrl.isNotEmpty) {
                              setState(() => widget.note.imageUrl = newUrl);
                            }
                          },
                          child: const Text('Change Link', style: TextStyle(fontSize: 10)),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleSheetsTable() {
    int rows = widget.note.tableData.length;
    int cols = widget.note.tableData.isNotEmpty ? widget.note.tableData[0].length : 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  const Text('Rows: ', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  _spinnerBtn(Icons.remove, () {
                    if (rows > 1) {
                      setState(() => widget.note.tableData.removeLast());
                    }
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('$rows', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  _spinnerBtn(Icons.add, () {
                    setState(() {
                      widget.note.tableData.add(List.generate(cols > 0 ? cols : 1, (i) => 'Cell'));
                    });
                  }),
                ],
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  const Text('Cols: ', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  _spinnerBtn(Icons.remove, () {
                    if (cols > 1) {
                      setState(() {
                        for (var row in widget.note.tableData) {
                          if (row.isNotEmpty) row.removeLast();
                        }
                      });
                    }
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('$cols', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  _spinnerBtn(Icons.add, () {
                    setState(() {
                      for (var row in widget.note.tableData) {
                        row.add('Cell');
                      }
                    });
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(90.0),
                border: TableBorder.all(color: Colors.white24, width: 1),
                children: widget.note.tableData.asMap().entries.map((rowEntry) {
                  final rowIndex = rowEntry.key;
                  final row = rowEntry.value;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: rowIndex == 0 ? const Color(0xFF1E1E1E) : Colors.transparent,
                    ),
                    children: row.asMap().entries.map((colEntry) {
                      final colIndex = colEntry.key;
                      final cellText = colEntry.value;
                      return Container(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          initialValue: cellText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: rowIndex == 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          onChanged: (val) => widget.note.tableData[rowIndex][colIndex] = val,
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _spinnerBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 12, color: Colors.white),
      ),
    );
  }

  Future<String?> _showUrlDialog() {
    final controller = TextEditingController(text: widget.note.imageUrl);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252526),
        title: const Text('Image URL', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'https://example.com/image.png', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Load Image'),
          ),
        ],
      ),
    );
  }
}