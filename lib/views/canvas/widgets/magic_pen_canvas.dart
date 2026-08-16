import 'package:flutter/material.dart';
import '../../../models/drawing_point.dart';

class MagicPenCanvas extends CustomPainter {
  final List<DrawingPoint?> points;

  MagicPenCanvas({required this.points});

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
  bool shouldRepaint(covariant MagicPenCanvas oldDelegate) => true;
}