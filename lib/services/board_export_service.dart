import 'dart:async';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BoardExportService {
  static Future<void> exportToImage(GlobalKey boundaryKey, {String fileName = 'smart_board.png'}) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // 3.0 pixelRatio ensures high-resolution capture
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Trigger Web Download
      final blob = html.Blob([pngBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Export Error: $e');
    }
  }
}