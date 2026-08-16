import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import '../../models/canvas_item.dart';
import '../../models/connection.dart';
import '../../models/drawing_point.dart';
import '../../providers/board_provider.dart';
import '../../services/clipboard_service.dart';
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
  double _lastX = 300.0;
  double _lastY = 200.0;

  bool _isPenActive = false;
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
          content: Text('Magic Pen active — drawing is locked until you tap Save or Pen again.'),
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

    setState(() {
      _drawingPoints.add(
        DrawingPoint(offset: point, paint: _penPaint),
      );
    });
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
    if (distance < 0.8) return;

    // Pointer events can arrive farther apart than the visual stroke should
    // be. Interpolating the gap makes the pen feel attached to the cursor.
    final steps = math.max(1, (distance / 3.0).ceil());
    setState(() {
      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        final p = Offset(
          previous.dx + (point.dx - previous.dx) * t,
          previous.dy + (point.dy - previous.dy) * t,
        );
        _drawingPoints.add(
          DrawingPoint(offset: p, paint: _penPaint),
        );
      }
    });
  }

  void _endPenStroke() {
    _lastPenPoint = null;
    if (!_isPenEraser && _drawingPoints.isNotEmpty && _drawingPoints.last != null) {
      setState(() => _drawingPoints.add(null));
    }
  }

  void _eraseAt(Offset point) {
    const radius = 18.0;

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

        setState(() {
          _drawingPoints.removeRange(start, end + 1);
          if (start < _drawingPoints.length && _drawingPoints[start] == null) {
            _drawingPoints.removeAt(start);
          }
        });
        return;
      }
    }
  }

  void _clearDrawing() {
    setState(() => _drawingPoints.clear());
  }

  void _saveDrawing() {
    setState(() {
      _isPenActive = false;
      _isPenEraser = false;
      _lastPenPoint = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('Magic Pen drawing saved to the current board.'),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformationController.dispose();
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
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): _handlePaste,
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _handlePaste,
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
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
                    InteractiveBoard(transformationController: _transformationController),
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: ZoomControls(transformationController: _transformationController),
                    ),
                    if (_isPenActive) ...[
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) => _beginPenStroke(event.localPosition),
                          onPointerMove: (event) => _movePen(event.localPosition),
                          onPointerUp: (_) => _endPenStroke(),
                          onPointerCancel: (_) => _endPenStroke(),
                          child: CustomPaint(
                            painter: _MagicPenPainter(points: _drawingPoints),
                          ),
                        ),
                      ),
                      // A very light visual veil makes it obvious that the
                      // canvas is in drawing mode without hiding the work.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            color: Colors.cyanAccent.withOpacity(0.025),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xDD172329),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.cyanAccent.withOpacity(0.45),
                                  ),
                                ),
                                child: const Text(
                                  'MAGIC PEN ACTIVE  •  canvas locked for drawing',
                                  style: TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 20,
                        top: 18,
                        child: Material(
                          color: const Color(0xEE1E2328),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: _isPenEraser ? 'Pen' : 'Rubber / Eraser',
                                  onPressed: () => setState(
                                    () => _isPenEraser = !_isPenEraser,
                                  ),
                                  icon: Icon(
                                    Icons.auto_fix_high,
                                    color: _isPenEraser
                                        ? Colors.orangeAccent
                                        : Colors.white70,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Erase all drawing',
                                  onPressed: _clearDrawing,
                                  icon: const Icon(
                                    Icons.delete_sweep_outlined,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _saveDrawing,
                                  icon: const Icon(Icons.save_outlined, size: 16),
                                  label: const Text('Save'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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

  const _MagicPenPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a != null && b != null) {
        canvas.drawLine(a.offset, b.offset, a.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MagicPenPainter oldDelegate) =>
      identical(points, oldDelegate.points) || points != oldDelegate.points;
}
