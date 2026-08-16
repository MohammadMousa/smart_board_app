import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/canvas_item.dart';
import '../../models/connection.dart';
import '../../providers/board_provider.dart';
import 'cards/card_body.dart';
import 'widgets/canvas_painter.dart';
import 'widgets/link_remove_button.dart';

final GlobalKey _viewportKey = GlobalKey();

class InteractiveBoard extends StatelessWidget {
  final TransformationController transformationController;

  const InteractiveBoard({super.key, required this.transformationController});

  Offset _getScenePosition(Offset globalPos) {
    final renderBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return globalPos;
    final localViewportPos = renderBox.globalToLocal(globalPos);
    return transformationController.toScene(localViewportPos);
  }

  String? _findWireAtPosition(Offset scenePos, BoardProvider provider) {
    for (var conn in provider.connections) {
      final source = provider.notes.firstWhere((n) => n.id == conn.sourceNodeId, orElse: () => CanvasNote(id: '', x: 0, y: 0));
      final target = provider.notes.firstWhere((n) => n.id == conn.targetNodeId, orElse: () => CanvasNote(id: '', x: 0, y: 0));

      if (source.id.isNotEmpty && target.id.isNotEmpty) {
        final start = Offset(source.x + source.width + 20, source.y + (source.height / 2));
        final end = Offset(target.x - 20, target.y + (target.height / 2));

        if (_isPointNearBezier(scenePos, start, end, 16.0)) {
          return conn.id;
        }
      }
    }
    return null;
  }

  bool _isPointNearBezier(Offset p, Offset start, Offset end, double maxDist) {
    final controlX = (start.dx + end.dx) / 2;
    final p1 = Offset(controlX, start.dy);
    final p2 = Offset(controlX, end.dy);

    for (int i = 0; i <= 20; i++) {
      double t = i / 20.0;
      double u = 1 - t;
      double tt = t * t;
      double uu = u * u;
      double uuu = uu * u;
      double ttt = tt * t;

      double x = uuu * start.dx + 3 * uu * t * p1.dx + 3 * u * tt * p2.dx + ttt * end.dx;
      double y = uuu * start.dy + 3 * uu * t * p1.dy + 3 * u * tt * p2.dy + ttt * end.dy;

      if ((p - Offset(x, y)).distance <= maxDist) {
        return true;
      }
    }
    return false;
  }

  List<Widget> _buildRemoveButton(BoardProvider provider) {
    final connection = provider.connections.firstWhere(
      (c) => c.id == provider.hoveredConnectionId,
      orElse: () => NodeConnection(
        id: '',
        sourceNodeId: '',
        targetNodeId: '',
      ),
    );

    if (connection.id.isEmpty) return const [];

    final source = provider.notes.firstWhere(
      (n) => n.id == connection.sourceNodeId,
      orElse: () => CanvasNote(id: '', x: 0, y: 0),
    );
    final target = provider.notes.firstWhere(
      (n) => n.id == connection.targetNodeId,
      orElse: () => CanvasNote(id: '', x: 0, y: 0),
    );

    if (source.id.isEmpty || target.id.isEmpty) return const [];

    final start = Offset(
      source.x + source.width + 20,
      source.y + source.height / 2,
    );
    final end = Offset(
      target.x - 20,
      target.y + target.height / 2,
    );

    final midpoint = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );

    return [
      Positioned(
        left: midpoint.dx - 12,
        top: midpoint.dy - 12,
        child: LinkRemoveButton(
          onTap: () => provider.removeConnection(connection.id),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BoardProvider>();

    return MouseRegion(
      onHover: (event) {
        final scenePos = _getScenePosition(event.position);
        if (boardProvider.activeSourceNoteId != null) {
          boardProvider.updateCursorHover(scenePos);
        } else {
          final wireId = _findWireAtPosition(scenePos, boardProvider);
          boardProvider.setHoveredConnection(wireId);
        }
      },
      child: InteractiveViewer(
        key: _viewportKey,
        transformationController: transformationController,
        boundaryMargin: const EdgeInsets.all(5000),
        minScale: 0.2,
        maxScale: 2.5,
        constrained: false,
        child: SizedBox(
          width: 10000,
          height: 10000,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final scenePos = _getScenePosition(details.globalPosition);
                    final wireId = _findWireAtPosition(scenePos, boardProvider);
                    if (wireId != null) {
                      boardProvider.removeConnection(wireId);
                      return;
                    }
                    if (boardProvider.activeSourceNoteId != null) {
                      boardProvider.cancelConnection();
                    }
                  },
                  child: CustomPaint(
                    painter: CanvasPainter(
                      notes: boardProvider.notes,
                      connections: boardProvider.connections,
                      activeSourceNoteId: boardProvider.activeSourceNoteId,
                      hoveredConnectionId: boardProvider.hoveredConnectionId,
                      hoverCursorPos: boardProvider.hoverCursorPos,
                      activeWireStyle: boardProvider.activeWireStyle,
                    ),
                  ),
                ),
              ),
              ...boardProvider.notes.map((note) {
                return Positioned(
                  left: note.x,
                  top: note.y,
                  child: _NoteCard(
                    note: note,
                    transformationController: transformationController,
                  ),
                );
              }),

              // Real interactive remove control. It is positioned from the
              // same curve geometry used by the painter, so it stays attached
              // to the wire while notes move.
              if (boardProvider.hoveredConnectionId != null)
                ..._buildRemoveButton(boardProvider),

            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  final CanvasNote note;
  final TransformationController transformationController;

  const _NoteCard({
    required this.note,
    required this.transformationController,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _isEditingTitle = false;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveTitle() {
    if (_titleController.text.trim().isNotEmpty) {
      context.read<BoardProvider>().updateNoteTitle(widget.note.id, _titleController.text.trim());
    }
    setState(() => _isEditingTitle = false);
  }

  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BoardProvider>();
    final currentScale = widget.transformationController.value.getMaxScaleOnAxis();
    final isActiveSource = boardProvider.activeSourceNoteId == widget.note.id;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onPanUpdate: (details) {
            boardProvider.updateNotePosition(widget.note.id, details.delta.dx, details.delta.dy, currentScale);
          },
          child: Container(
            width: widget.note.width,
            height: widget.note.height,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF252526),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActiveSource ? Colors.amberAccent : Colors.blueAccent.withOpacity(0.6),
                width: isActiveSource ? 2.5 : 1.5,
              ),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.note.statusBadge != null) ...[
                      Text(widget.note.statusBadge!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ],
                    const Icon(Icons.circle, size: 8, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _isEditingTitle
                          ? TextField(
                        controller: _titleController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero),
                        onSubmitted: (_) => _saveTitle(),
                      )
                          : GestureDetector(
                        onDoubleTap: () => setState(() => _isEditingTitle = true),
                        child: Text(
                          widget.note.title,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isEditingTitle ? Icons.check : Icons.edit, size: 13, color: Colors.grey),
                      onPressed: () {
                        if (_isEditingTitle) _saveTitle();
                        else setState(() => _isEditingTitle = true);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                      onPressed: () => boardProvider.removeNote(widget.note.id),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 10),
                Expanded(child: CardBody(note: widget.note)),
              ],
            ),
          ),
        ),

        // Resize Handle
        Positioned(
          right: -4,
          bottom: -4,
          child: GestureDetector(
            onPanUpdate: (details) {
              boardProvider.updateNoteSize(widget.note.id, details.delta.dx, details.delta.dy, currentScale);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeDownRight,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                child: const Icon(Icons.south_east, size: 12, color: Colors.white),
              ),
            ),
          ),
        ),

        // Left Input Port (Expanded 44x44 Click Target)
        Positioned(
          left: -22,
          top: (widget.note.height / 2) - 22,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => boardProvider.handleInputPortClick(widget.note.id),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 44,
                height: 44,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent, width: 2),
                    ),
                    child: const Center(child: CircleAvatar(radius: 4, backgroundColor: Colors.blueAccent)),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Right Output Port (Expanded 44x44 Click Target)
        Positioned(
          right: -22,
          top: (widget.note.height / 2) - 22,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final portPos = Offset(widget.note.x + widget.note.width + 20, widget.note.y + (widget.note.height / 2));
              boardProvider.handleOutputPortClick(widget.note.id, portPos);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 44,
                height: 44,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isActiveSource ? Colors.amber : const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      border: Border.all(color: isActiveSource ? Colors.amberAccent : Colors.greenAccent, width: 2),
                    ),
                    child: Center(
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: isActiveSource ? Colors.black : Colors.greenAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}