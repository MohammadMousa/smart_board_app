import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/canvas_item.dart';
import '../../models/connection.dart';
import '../../models/drawing_point.dart';
import '../../providers/board_provider.dart';
import '../../services/clipboard_service.dart';
import '../../services/board_export_service.dart';
import '../auth/auth_dialog.dart';
import 'interactive_board.dart';
import 'widgets/zoom_controls.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final FocusNode _focusNode = FocusNode();
  final TransformationController _transformationController = TransformationController();
  final _uuid = const Uuid();
  final GlobalKey _boardExportKey = GlobalKey();
  final ValueNotifier<int> _drawingRevision = ValueNotifier<int>(0);
  double _lastX = 300.0;
  double _lastY = 200.0;

  bool _isPenActive = false;
  bool _isExporting = false;
  bool _isPenEraser = false;
  final List<DrawingPoint?> _drawingPoints = [];
  Offset? _lastPenPoint;

  Paint get _penPaint => Paint()
    ..color = Colors.cyanAccent.withOpacity(0.92)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 4.5;

  void _toggleMagicPen() {
    setState(() {
      _isPenActive = !_isPenActive;
      _isPenEraser = false;
      _lastPenPoint = null;
    });

    if (_isPenActive && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('Magic Pen active — canvas locked for drawing. Save exports a PNG and keeps Pen mode active.'),
        ),
      );
    }
  }

  void _beginPenStroke(Offset point) {
    _lastPenPoint = point;

    if (_isPenEraser) {
      _eraseAt(point);
      return;
    }

    _drawingPoints.add(DrawingPoint(offset: point, paint: _penPaint));
    _drawingRevision.value++;
  }

  void _movePen(Offset point) {
    final previous = _lastPenPoint;
    _lastPenPoint = point;

    if (_isPenEraser) {
      _eraseAt(point);
      return;
    }

    if (previous == null) {
      _beginPenStroke(point);
      return;
    }

    final distance = (point - previous).distance;
    if (distance < 0.5) return;

    // Store enough points to keep fast mouse movements attached to the
    // cursor. The painter draws a continuous smoothed path, while the list
    // itself is mutated without rebuilding the entire canvas on every event.
    final steps = mathMax(1, distance.ceil());
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      _drawingPoints.add(
        DrawingPoint(
          offset: Offset(
            previous.dx + (point.dx - previous.dx) * t,
            previous.dy + (point.dy - previous.dy) * t,
          ),
          paint: _penPaint,
        ),
      );
    }
    _drawingRevision.value++;
  }

  void _endPenStroke() {
    _lastPenPoint = null;
    if (!_isPenEraser && _drawingPoints.isNotEmpty && _drawingPoints.last != null) {
      _drawingPoints.add(null);
      _drawingRevision.value++;
    }
  }

  void _eraseAt(Offset point) {
    const radius = 20.0;

    for (var i = 0; i < _drawingPoints.length; i++) {
      final current = _drawingPoints[i];
      if (current == null) continue;

      if ((current.offset - point).distance <= radius) {
        var start = i;
        while (start > 0 && _drawingPoints[start - 1] != null) {
          start--;
        }

        var end = i;
        while (end + 1 < _drawingPoints.length && _drawingPoints[end + 1] != null) {
          end++;
        }

        _drawingPoints.removeRange(start, end + 1);
        if (start < _drawingPoints.length && _drawingPoints[start] == null) {
          _drawingPoints.removeAt(start);
        }
        _drawingRevision.value++;
        return;
      }
    }
  }

  void _clearDrawing() {
    _drawingPoints.clear();
    _drawingRevision.value++;
  }

  Future<void> _saveDrawing() async {
    if (_drawingPoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to export yet.')),
        );
      }
      return;
    }

    final boardProvider = context.read<BoardProvider>();
    final bounds = _calculateExportBounds(boardProvider);
    if (bounds == null) return;

    final previousTransform = Matrix4.copy(_transformationController.value);
    setState(() => _isExporting = true);

    try {
      await BoardExportService.exportToImage(
        _boardExportKey,
        transformationController: _transformationController,
        contentBounds: bounds,
        fileName: 'smart_board_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Whole board exported as PNG. Magic Pen remains active.'),
        ),
      );
    } finally {
      _transformationController.value = previousTransform;
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Rect? _calculateExportBounds(BoardProvider boardProvider) {
    Rect? bounds;

    for (final note in boardProvider.notes) {
      final rect = Rect.fromLTWH(note.x, note.y, note.width, note.renderHeight);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }

    for (final point in _drawingPoints) {
      if (point == null) continue;
      final radius = point.paint.strokeWidth / 2 + 6;
      final rect = Rect.fromCircle(center: point.offset, radius: radius);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }

    if (bounds == null) return null;
    return bounds.inflate(50);
  }

  int mathMax(int a, int b) => a > b ? a : b;

  @override
  void dispose() {
    _focusNode.dispose();
    _transformationController.dispose();
    _drawingRevision.dispose();
    super.dispose();
  }

  void _addNewNote() {
    final boardProvider = context.read<BoardProvider>();
    final note = CanvasNote(
      id: _uuid.v7(),
      x: _lastX,
      y: _lastY,
    );
    boardProvider.addNote(note);
    setState(() {
      _lastX += 30.0;
      _lastY += 30.0;
    });
  }

  Future<void> _handlePaste() async {
    final boardProvider = context.read<BoardProvider>();
    final newItem = await ClipboardService.processClipboard(targetX: _lastX, targetY: _lastY);

    if (newItem != null) {
      boardProvider.addNote(newItem);
      setState(() {
        _lastX += 30.0;
        _lastY += 30.0;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty or unsupported data format.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<BoardProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.keyV &&
              (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed)) {
            // Never steal Ctrl/Cmd+V from a focused TextField. Native text
            // editing, including title/body paste, must remain untouched.
            if (FocusManager.instance.primaryFocus != _focusNode) {
              return KeyEventResult.ignored;
            }
            _handlePaste();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Column(
            children: [
              // Top Bar Toolkit
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: const Color(0xFF1F1F1F),
                child: Row(
                  children: [
                    const Icon(Icons.note_alt_outlined, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    const Text('SmartBoard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 16),

                    GestureDetector(
                      onTap: () {
                        if (!board.isAuthenticated) {
                          showDialog(context: context, builder: (_) => const AuthDialog());
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: board.isAuthenticated ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: board.isAuthenticated ? Colors.greenAccent : Colors.amber),
                        ),
                        child: Text(
                          board.isAuthenticated ? (board.userDisplayName ?? board.userEmail!) : 'Guest',
                          style: TextStyle(color: board.isAuthenticated ? Colors.greenAccent : Colors.amber, fontSize: 11),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Wire Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => board.setWireStyle(ConnectionStyle.line),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: board.activeWireStyle == ConnectionStyle.line ? Colors.blueAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.horizontal_rule, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Line', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: () => board.setWireStyle(ConnectionStyle.arrow),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: board.activeWireStyle == ConnectionStyle.arrow ? Colors.blueAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.east, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Arrow', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: () => board.setWireStyle(ConnectionStyle.bidirectional),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: board.activeWireStyle == ConnectionStyle.bidirectional
                                    ? Colors.blueAccent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.compare_arrows, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Bi-Arrow', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: _isPenActive ? Colors.blueAccent : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        onPressed: _toggleMagicPen,
                        icon: Icon(
                          Icons.gesture,
                          size: 16,
                          color: _isPenActive ? Colors.white : Colors.cyanAccent,
                        ),
                        label: Text(
                          _isPenActive ? 'Pen ON' : 'Magic Pen',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    if (_isPenActive) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF172329),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.45)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gesture, size: 14, color: Colors.cyanAccent),
                            SizedBox(width: 6),
                            Text(
                              'Magic Pen Active · canvas locked',
                              style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: _isPenEraser ? 'Switch to pen' : 'Rubber / eraser',
                        onPressed: () => setState(() => _isPenEraser = !_isPenEraser),
                        icon: Icon(
                          Icons.auto_fix_high,
                          size: 17,
                          color: _isPenEraser ? Colors.orangeAccent : Colors.white70,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Clear drawing',
                        onPressed: _clearDrawing,
                        icon: const Icon(Icons.delete_sweep_outlined, size: 17, color: Colors.redAccent),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: _saveDrawing,
                        icon: const Icon(Icons.save_outlined, size: 15),
                        label: const Text('Save PNG', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    const SizedBox(width: 8),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A2A2A)),
                      onPressed: _handlePaste,
                      icon: const Icon(Icons.content_paste, size: 16, color: Colors.amberAccent),
                      label: const Text('Paste Clipboard', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: _addNewNote,
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: const Text('Add Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),

                    IconButton(
                      tooltip: 'Clear Current Board',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: board.clearBoard,
                    ),
                  ],
                ),
              ),

              // Board Tabs Header
              Container(
                height: 38,
                color: const Color(0xFF181818),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: board.tabs.length,
                        itemBuilder: (context, index) {
                          final tab = board.tabs[index];
                          final isActive = index == board.activeTabIndex;

                          return Padding(
                            padding: const EdgeInsets.only(right: 6, top: 4),
                            child: InkWell(
                              onTap: () => board.switchTab(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFF252526) : const Color(0xFF1E1E1E),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                  border: Border.all(
                                    color: isActive ? Colors.blueAccent.withOpacity(0.5) : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _EditableTabTitle(
                                      title: tab.title,
                                      isActive: isActive,
                                      onSubmitted: (newTitle) => board.updateTabTitle(index, newTitle),
                                    ),
                                    if (board.tabs.length > 1) ...[
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => board.removeTab(index),
                                        child: const Icon(Icons.close, size: 12, color: Colors.white54),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_box_outlined, color: Colors.blueAccent, size: 20),
                      tooltip: 'New Board Tab',
                      onPressed: board.addTab,
                    ),
                  ],
                ),
              ),

              // Active Board Canvas
              Expanded(
                child: Stack(
                  children: [
                    // Export only the actual board layers. Pen controls and
                    // zoom controls intentionally stay outside this boundary.
                    RepaintBoundary(
                      key: _boardExportKey,
                      child: Stack(
                        children: [
                          InteractiveBoard(
                            transformationController: _transformationController,
                            interactionLocked: _isPenActive,
                            overlay: Stack(
                              children: [
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _MagicPenPainter(
                                        points: _drawingPoints,
                                        repaint: _drawingRevision,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_isPenActive)
                                  Positioned.fill(
                                    child: Listener(
                                      behavior: HitTestBehavior.opaque,
                                      onPointerDown: (event) => _beginPenStroke(event.localPosition),
                                      onPointerMove: (event) => _movePen(event.localPosition),
                                      onPointerUp: (_) => _endPenStroke(),
                                      onPointerCancel: (_) => _endPenStroke(),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isExporting)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF252526),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.45)),
                                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  ),
                                  SizedBox(width: 14),
                                  Text(
                                    'Preparing whole-board PNG…',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: ZoomControls(
                        transformationController: _transformationController,
                      ),
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

class _EditableTabTitle extends StatefulWidget {
  final String title;
  final bool isActive;
  final ValueChanged<String> onSubmitted;

  const _EditableTabTitle({
    required this.title,
    required this.isActive,
    required this.onSubmitted,
  });

  @override
  State<_EditableTabTitle> createState() => _EditableTabTitleState();
}

class _EditableTabTitleState extends State<_EditableTabTitle> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.title);
  }

  @override
  void didUpdateWidget(covariant _EditableTabTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _controller.text = widget.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return SizedBox(
        width: 80,
        child: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
          onSubmitted: (val) {
            widget.onSubmitted(val);
            setState(() => _isEditing = false);
          },
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: () => setState(() => _isEditing = true),
      child: Text(
        widget.title,
        style: TextStyle(
          color: widget.isActive ? Colors.white : Colors.grey,
          fontSize: 12,
          fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _MagicPenPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  const _MagicPenPainter({required this.points, Listenable? repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = <DrawingPoint>[];

    void drawStroke() {
      if (stroke.isEmpty) return;

      final paint = Paint()
        ..color = stroke.first.paint.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.first.paint.strokeWidth
        ..style = PaintingStyle.stroke;

      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first.offset,
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        return;
      }

      final path = Path()..moveTo(stroke.first.offset.dx, stroke.first.offset.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].offset.dx, stroke[i].offset.dy);
      }
      canvas.drawPath(path, paint);
      stroke.clear();
    }

    for (final point in points) {
      if (point == null) {
        drawStroke();
      } else {
        stroke.add(point);
      }
    }
    drawStroke();
  }

  @override
  bool shouldRepaint(covariant _MagicPenPainter oldDelegate) => false;
}
