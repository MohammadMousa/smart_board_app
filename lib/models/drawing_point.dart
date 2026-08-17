import 'package:flutter/material.dart';

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({required this.offset, required Paint paint})
      : paint = (Paint()
          ..color = paint.color
          ..strokeCap = paint.strokeCap
          ..strokeJoin = paint.strokeJoin
          ..strokeWidth = paint.strokeWidth
          ..style = PaintingStyle.stroke);
}
