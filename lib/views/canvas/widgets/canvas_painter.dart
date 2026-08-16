import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/canvas_item.dart';
import '../../../models/connection.dart';

class CanvasPainter extends CustomPainter {
  final List<CanvasNote> notes;
  final List<NodeConnection> connections;
  final String? activeSourceNoteId;
  final String? hoveredConnectionId;
  final Offset? hoverCursorPos;
  final ConnectionStyle activeWireStyle;

  CanvasPainter({
    required this.notes,
    required this.connections,
    this.activeSourceNoteId,
    this.hoveredConnectionId,
    this.hoverCursorPos,
    this.activeWireStyle = ConnectionStyle.arrow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wirePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final hoverWirePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final activeWirePaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (var conn in connections) {
      final source = notes.firstWhere((n) => n.id == conn.sourceNodeId, orElse: () => CanvasNote(id: '', x: 0, y: 0));
      final target = notes.firstWhere((n) => n.id == conn.targetNodeId, orElse: () => CanvasNote(id: '', x: 0, y: 0));

      if (source.id.isNotEmpty && target.id.isNotEmpty) {
        final start = Offset(source.x + source.width + 20, source.y + (source.height / 2));
        final end = Offset(target.x - 20, target.y + (target.height / 2));
        final isHovered = conn.id == hoveredConnectionId;

        _drawBezierCurve(canvas, start, end, isHovered ? hoverWirePaint : wirePaint, conn.style);

      }
    }

    if (activeSourceNoteId != null && hoverCursorPos != null) {
      final source = notes.firstWhere((n) => n.id == activeSourceNoteId, orElse: () => CanvasNote(id: '', x: 0, y: 0));
      if (source.id.isNotEmpty) {
        final start = Offset(source.x + source.width + 20, source.y + (source.height / 2));
        _drawBezierCurve(canvas, start, hoverCursorPos!, activeWirePaint, activeWireStyle);
      }
    }
  }

  void _drawBezierCurve(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    ConnectionStyle style,
  ) {
    final controlX = (start.dx + end.dx) / 2;
    final control1 = Offset(controlX, start.dy);
    final control2 = Offset(controlX, end.dy);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );

    canvas.drawPath(path, paint);

    if (style == ConnectionStyle.arrow ||
        style == ConnectionStyle.bidirectional) {
      _drawArrowHead(
        canvas,
        end,
        (end - control2).direction,
        paint.color,
      );
    }

    if (style == ConnectionStyle.bidirectional) {
      // At the source end the arrow must point back along the curve.
      _drawArrowHead(
        canvas,
        start,
        (control1 - start).direction + pi,
        paint.color,
      );
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset point,
    double angle,
    Color color,
  ) {
    const arrowSize = 11.0;
    const halfAngle = pi / 6;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final arrowPath = Path()
      ..moveTo(point.dx, point.dy)
      ..lineTo(
        point.dx - arrowSize * cos(angle - halfAngle),
        point.dy - arrowSize * sin(angle - halfAngle),
      )
      ..lineTo(
        point.dx - arrowSize * cos(angle + halfAngle),
        point.dy - arrowSize * sin(angle + halfAngle),
      )
      ..close();

    canvas.drawPath(arrowPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}