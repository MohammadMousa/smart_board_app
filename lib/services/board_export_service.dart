import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BoardExportService {
  static Future<bool> exportToImage(
    GlobalKey boundaryKey, {
    required TransformationController transformationController,
    required Rect contentBounds,
    String fileName = 'smart_board.png',
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return false;

    final viewportSize = boundary.size;
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return false;

    final fitScale = _fitScale(contentBounds, viewportSize);
    final tx = (viewportSize.width - contentBounds.width * fitScale) / 2 - contentBounds.left * fitScale;
    final ty = (viewportSize.height - contentBounds.height * fitScale) / 2 - contentBounds.top * fitScale;

    final previous = Matrix4.copy(transformationController.value);
    try {
      transformationController.value = Matrix4.identity()
        ..translate(tx, ty)
        ..scale(fitScale);

      // Give Flutter a frame to paint the fitted whole-board state before capture.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final pixelRatio = _exportPixelRatio(contentBounds, viewportSize, fitScale);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final blob = html.Blob([pngBytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return true;
    } finally {
      transformationController.value = previous;
    }
  }

  static double _fitScale(Rect bounds, Size viewport) {
    if (bounds.width <= 0 || bounds.height <= 0) return 1.0;
    final scaleX = viewport.width / bounds.width;
    final scaleY = viewport.height / bounds.height;
    return (scaleX < scaleY ? scaleX : scaleY).clamp(0.05, 2.5);
  }

  static double _exportPixelRatio(Rect bounds, Size viewport, double fitScale) {
    // Keep the output crisp without producing an impractically huge bitmap.
    // The captured viewport is scaled by the fitted scene, so 2x is a useful
    // compromise for diagrams and text.
    final desiredWidth = bounds.width * fitScale * 2.0;
    final ratio = desiredWidth / viewport.width;
    return ratio.clamp(1.5, 3.0);
  }
}
