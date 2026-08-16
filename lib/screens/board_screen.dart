import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/board_link.dart';
import '../models/canvas_item.dart';
import '../models/drawing_point.dart';
import '../views/canvas/widgets/canvas_note_widget.dart';
import '../views/canvas/widgets/top_toolbar.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<CanvasNote> _notes = [];
  final List<BoardLink> _links = [];
  final List<DrawingPoint?> _drawingPoints = [];

  LinkType _selectedLinkType = LinkType.singleArrow;
  String? _selectedLinkStartNoteId;
  String? _selectedLinkId;
  bool _isPenActive = false;

  @override
  void initState() {
    super.initState();
    _notes.addAll([
      CanvasNote(id: '1', x: 80, y: 150, textContent: 'Click to edit note content...'),
      CanvasNote(id: '2', x: 450, y: 80, textContent: 'Click to edit note content...'),
      CanvasNote(id: '3', x: 450, y: 320, textContent: 'Click to edit note content...'),
      CanvasNote(id: '4', x: 820, y: 180, textContent: 'Click to edit note content...'),
    ]);
  }

  // Robust paste handler checking binary clipboard items and clipboard text
  Future<void> _pasteFromClipboard({double? x, double? y, String? noteId}) async {
    String? imageUrl;

    try {
      final clipboard = html.window.navigator.clipboard;
      if (clipboard != null) {
        // 1. Try reading text clipboard for direct image URLs or Data URLs
        try {
          final text = await clipboard.readText();
          if (text != null && (text.startsWith('data:image') || text.startsWith('http://') || text.startsWith('https://'))) {
            imageUrl = text.trim();
          }
        } catch (_) {}

        // 2. Try reading binary blobs from clipboard items
        if (imageUrl == null) {
          final dynamic items = await clipboard.read();
          final int count = items.length ?? 0;
          for (int i = 0; i < count; i++) {
            final item = items[i];
            final List<dynamic> types = List<dynamic>.from(item.types ?? []);
            for (final type in types) {
              if (type.toString().startsWith('image/')) {
                final blob = await item.getType(type.toString());
                final reader = html.FileReader();
                reader.readAsDataUrl(blob);
                await reader.onLoadEnd.first;
                imageUrl = reader.result as String;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Clipboard read error: $e');
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      setState(() {
        if (noteId != null) {
          final note = _notes.firstWhere((n) => n.id == noteId);
          note.contentType = NoteContentType.IMAGE;
          note.imageUrl = imageUrl!;
        } else {
          _notes.add(
            CanvasNote(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              x: x ?? 300.0,
              y: y ?? 200.0,
              contentType: NoteContentType.IMAGE,
              imageUrl: imageUrl!,
            ),
          );
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image data found in clipboard. Copy an image or image URL first.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleLinkCreation(String noteId, bool isOutput) {
    if (_selectedLinkStartNoteId == null) {
      setState(() => _selectedLinkStartNoteId = noteId);
    } else {
      if (_selectedLinkStartNoteId != noteId) {
        setState(() {
          _links.add(
            BoardLink(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              startNoteId: _selectedLinkStartNoteId!,
              endNoteId: noteId,
              type: _selectedLinkType,
            ),
          );
          _selectedLinkStartNoteId = null;
        });
      } else {
        setState(() => _selectedLinkStartNoteId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Column(
        children: [
          TopToolbar(
            selectedLinkType: _selectedLinkType,
            onLinkTypeChanged: (type) => setState(() => _selectedLinkType = type),
            onPasteClipboard: () => _pasteFromClipboard(),
            onAddNote: () {
              setState(() {
                _notes.add(
                  CanvasNote(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    x: 150.0 + (_notes.length * 20),
                    y: 150.0 + (_notes.length * 20),
                  ),
                );
              });
            },
            onDeleteAll: () {
              setState(() {
                _notes.clear();
                _links.clear();
                _drawingPoints.clear();
              });
            },
            isPenActive: _isPenActive,
            onTogglePen: () => setState(() => _isPenActive = !_isPenActive),
          ),
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey,
              child: Stack(
                children: [
                  // 1. Links Layer
                  CustomPaint(
                    size: Size.infinite,
                    painter: MasterLinkPainter(
                      notes: _notes,
                      links: _links,
                      selectedLinkId: _selectedLinkId,
                    ),
                  ),

                  // 2. Redesigned Link Removal Action Overlay
                  ..._links.map((link) {
                    final startNote = _notes.firstWhere(
                          (n) => n.id == link.startNoteId,
                      orElse: () => CanvasNote(id: '', x: 0, y: 0),
                    );
                    final endNote = _notes.firstWhere(
                          (n) => n.id == link.endNoteId,
                      orElse: () => CanvasNote(id: '', x: 0, y: 0),
                    );

                    final startX = startNote.x + startNote.width;
                    final startY = startNote.y + 60;
                    final endX = endNote.x;
                    final endY = endNote.y + 60;

                    // Compute midpoint along bezier curve path
                    final midX = (startX + endX) / 2;
                    final midY = (startY + endY) / 2;

                    return Positioned(
                      left: midX - 12,
                      top: midY - 12,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _links.removeWhere((l) => l.id == link.id)),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1518),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.redAccent, width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                          ),
                        ),
                      ),
                    );
                  }),

                  // 3. Notes Layer
                  ..._notes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final note = entry.value;

                    return CanvasNoteWidget(
                      key: ValueKey(note.id),
                      note: note,
                      index: index,
                      onEdit: () {},
                      onDelete: () {
                        setState(() {
                          _notes.removeWhere((n) => n.id == note.id);
                          _links.removeWhere((l) => l.startNoteId == note.id || l.endNoteId == note.id);
                        });
                      },
                      onPasteImage: () => _pasteFromClipboard(noteId: note.id),
                      onStartLink: (id, isOutput) => _handleLinkCreation(id, isOutput),
                      onDragUpdate: (details) {
                        setState(() {
                          note.x += details.delta.dx;
                          note.y += details.delta.dy;
                        });
                      },
                    );
                  }),

                  // 4. Magic Pen Active Layer
                  if (_isPenActive)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque, // Fixes magic pen touch absorption
                        onPanStart: (details) {
                          setState(() {
                            _drawingPoints.add(
                              DrawingPoint(
                                offset: details.localPosition,
                                paint: Paint()
                                  ..color = Colors.cyanAccent
                                  ..strokeCap = StrokeCap.round
                                  ..strokeWidth = 4.0,
                              ),
                            );
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _drawingPoints.add(
                              DrawingPoint(
                                offset: details.localPosition,
                                paint: Paint()
                                  ..color = Colors.cyanAccent
                                  ..strokeCap = StrokeCap.round
                                  ..strokeWidth = 4.0,
                              ),
                            );
                          });
                        },
                        onPanEnd: (_) => setState(() => _drawingPoints.add(null)),
                        child: CustomPaint(
                          painter: MagicPenPainter(points: _drawingPoints),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MasterLinkPainter extends CustomPainter {
  final List<CanvasNote> notes;
  final List<BoardLink> links;
  final String? selectedLinkId;

  MasterLinkPainter({required this.notes, required this.links, this.selectedLinkId});

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final startNote = notes.firstWhere((n) => n.id == link.startNoteId, orElse: () => CanvasNote(id: '', x: 0, y: 0));
      final endNote = notes.firstWhere((n) => n.id == link.endNoteId, orElse: () => CanvasNote(id: '', x: 0, y: 0));

      if (startNote.id.isEmpty || endNote.id.isEmpty) continue;

      final start = Offset(startNote.x + startNote.width, startNote.y + 60);
      final end = Offset(endNote.x, endNote.y + 60);

      final paint = Paint()
        ..color = (link.id == selectedLinkId) ? Colors.redAccent : Colors.blueAccent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final dx = (end.dx - start.dx).abs() * 0.5;
      final control1 = Offset(start.dx + math.max(dx, 40), start.dy);
      final control2 = Offset(end.dx - math.max(dx, 40), end.dy);

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, end.dx, end.dy);

      canvas.drawPath(path, paint);

      // Render arrowhead at end note for singleArrow & doubleArrow
      if (link.type == LinkType.singleArrow || link.type == LinkType.doubleArrow) {
        final endAngle = math.atan2(end.dy - control2.dy, end.dx - control2.dx);
        _drawArrowHead(canvas, end, endAngle, paint.color);
      }

      // Render arrowhead at start note for doubleArrow
      if (link.type == LinkType.doubleArrow) {
        final startAngle = math.atan2(start.dy - control1.dy, start.dx - control1.dx);
        _drawArrowHead(canvas, start, startAngle, paint.color);
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset point, double angle, Color color) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const arrowSize = 10.0;
    final arrowPath = Path()
      ..moveTo(
        point.dx - arrowSize * math.cos(angle - math.pi / 6),
        point.dy - arrowSize * math.sin(angle - math.pi / 6),
      )
      ..lineTo(point.dx, point.dy)
      ..lineTo(
        point.dx - arrowSize * math.cos(angle + math.pi / 6),
        point.dy - arrowSize * math.sin(angle + math.pi / 6),
      )
      ..close();

    canvas.drawPath(arrowPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant MasterLinkPainter oldDelegate) => true;
}

class MagicPenPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  MagicPenPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant MagicPenPainter oldDelegate) => true;
}