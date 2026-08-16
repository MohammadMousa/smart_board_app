import 'package:flutter/material.dart';

import '../../../models/board_link.dart';

class TopToolbar extends StatelessWidget {
  final LinkType selectedLinkType;
  final ValueChanged<LinkType> onLinkTypeChanged;
  final VoidCallback onPasteClipboard;
  final VoidCallback onAddNote;
  final VoidCallback onDeleteAll;
  final bool isPenActive;
  final VoidCallback onTogglePen;

  const TopToolbar({
    super.key,
    required this.selectedLinkType,
    required this.onLinkTypeChanged,
    required this.onPasteClipboard,
    required this.onAddNote,
    required this.onDeleteAll,
    required this.isPenActive,
    required this.onTogglePen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF141720),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_customize, color: Colors.blueAccent),
          const SizedBox(width: 10),
          const Text(
            'SmartBoard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),

          // --- Link Type Selector ---
          SegmentedButton<LinkType>(
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                    ? Colors.blueAccent
                    : const Color(0xFF1E212B),
              ),
            ),
            segments: const [
              ButtonSegment(value: LinkType.line, label: Text('— Line')),
              ButtonSegment(value: LinkType.singleArrow, label: Text('→ Arrow')),
              ButtonSegment(value: LinkType.doubleArrow, label: Text('↔ Bi-Arrow')),
            ],
            selected: {selectedLinkType},
            onSelectionChanged: (Set<LinkType> selection) {
              onLinkTypeChanged(selection.first);
            },
          ),
          const SizedBox(width: 12),

          // --- Magic Pen Button ---
          Container(
            decoration: BoxDecoration(
              color: isPenActive ? Colors.blueAccent : const Color(0xFF1E212B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.gesture, color: isPenActive ? Colors.white : Colors.white70, size: 20),
              tooltip: 'Toggle Freehand Magic Pen',
              onPressed: onTogglePen,
            ),
          ),
          const SizedBox(width: 12),

          // --- Paste Clipboard Button ---
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E212B),
              foregroundColor: Colors.amberAccent,
            ),
            onPressed: onPasteClipboard,
            icon: const Icon(Icons.paste, size: 16),
            label: const Text('Paste Clipboard'),
          ),
          const SizedBox(width: 12),

          // --- Add Note Button ---
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: onAddNote,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Note'),
          ),
          const SizedBox(width: 8),

          // --- Clear All Button ---
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: onDeleteAll,
            tooltip: 'Clear Canvas',
          ),
        ],
      ),
    );
  }
}