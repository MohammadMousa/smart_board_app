import 'package:flutter/material.dart';
import '../../../models/canvas_item.dart';

class CanvasNoteWidget extends StatelessWidget {
  final CanvasNote note;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPasteImage;
  final Function(String noteId, bool isOutput) onStartLink;
  final Function(DragUpdateDetails details) onDragUpdate;

  const CanvasNoteWidget({
    super.key,
    required this.note,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onPasteImage,
    required this.onStartLink,
    required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    // Guaranteed serial title fallback: Note 1, Note 2, ..., Note N
    final String displayTitle = note.title.trim().isNotEmpty
        ? note.title
        : 'Note ${index + 1}';

    return Positioned(
      left: note.x,
      top: note.y,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onPanUpdate: onDragUpdate,
            child: Container(
              width: note.width,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E212B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3B4254), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Header Row with Explicit Serial Title ---
                  Row(
                    children: [
                      if (note.statusBadge != null && note.statusBadge!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Text(note.statusBadge!, style: const TextStyle(fontSize: 14)),
                        )
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.edit, size: 15, color: Colors.white54),
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, size: 15, color: Colors.white54),
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 16),

                  // --- Content Body ---
                  if (note.contentType == NoteContentType.IMAGE && note.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        note.imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: note.fitAsBoxFit,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 100,
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white38),
                          ),
                        ),
                      ),
                    )
                  else if (note.contentType == NoteContentType.TABLE)
                    Table(
                      border: TableBorder.all(color: Colors.white24),
                      children: note.tableData.map((row) {
                        return TableRow(
                          children: row.map((cell) {
                            return Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                cell,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        note.textContent,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // --- Footer Action Bar ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141720),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Icon(Icons.notes, size: 16, color: Colors.white38),
                        const Icon(Icons.grid_view, size: 16, color: Colors.white38),
                        const Icon(Icons.image_outlined, size: 16, color: Colors.white38),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.content_paste, size: 16, color: Colors.amberAccent),
                          tooltip: 'Paste image from clipboard',
                          onPressed: onPasteImage,
                        ),
                        const Icon(Icons.sentiment_satisfied, size: 16, color: Colors.white38),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Input Link Node (Left) ---
          Positioned(
            left: -12,
            top: 60,
            child: GestureDetector(
              onTap: () => onStartLink(note.id, false),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent, width: 2.5),
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ),

          // --- Output Link Node (Right) ---
          Positioned(
            right: -12,
            top: 60,
            child: GestureDetector(
              onTap: () => onStartLink(note.id, true),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.greenAccent, width: 2.5),
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}