import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../models/board_link.dart';

class LinkPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final LinkType type;
  final bool isSelected;

  LinkPainter({
    required this.start,
    required this.end,
    required this.type,
    this.isSelected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isSelected ? Colors.redAccent : Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Cubic Bézier Control Points
    final dx = (end.dx - start.dx).abs() * 0.5;
    final control1 = Offset(start.dx + dx, start.dy);
    final control2 = Offset(end.dx - dx, end.dy);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, end.dx, end.dy);

    canvas.drawPath(path, paint);

    // Draw End Arrowhead (Single & Double Arrow)
    if (type == LinkType.singleArrow || type == LinkType.doubleArrow) {
      final endAngle = math.atan2(end.dy - control2.dy, end.dx - control2.dx);
      _drawArrowHead(canvas, end, endAngle, paint.color);
    }

    // Draw Start Arrowhead (Double Arrow Only)
    if (type == LinkType.doubleArrow) {
      final startAngle = math.atan2(start.dy - control1.dy, start.dx - control1.dx);
      _drawArrowHead(canvas, start, startAngle, paint.color);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset point, double angle, Color color) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const arrowSize = 8.0;
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
  bool shouldRepaint(covariant LinkPainter oldDelegate) => true;
}