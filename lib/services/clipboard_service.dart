import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:uuid/uuid.dart';

import '../models/canvas_item.dart';

class ClipboardService {
  static const _uuid = Uuid();

  /// Reads the clipboard in this order:
  /// 1. Native/web image clipboard via pasteboard.
  /// 2. Flutter text clipboard.
  ///
  /// The old implementation tried to cast the browser's JS ClipboardItem
  /// collection to Dart List<dynamic>. On Flutter Web that is not reliable,
  /// and the exception was swallowed, which made both image and text paste
  /// appear to be broken.
  static Future<CanvasNote?> processClipboard({
    required double targetX,
    required double targetY,
  }) async {
    // Image first: pasteboard supports image clipboard data on Web and
    // avoids depending on the concrete JS collection type.
    try {
      final Uint8List? imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final dataUrl = 'data:image/png;base64,${base64Encode(imageBytes)}';
        return CanvasNote(
          id: _uuid.v7(),
          x: targetX,
          y: targetY,
          contentType: NoteContentType.IMAGE,
          imageUrl: dataUrl,
        );
      }
    } catch (_) {
      // Some browsers deny direct clipboard image access. Continue to text.
    }

    // Text is deliberately independent from image handling.
    try {
      final pasteboardText = await Pasteboard.text;
      final rawText = pasteboardText ?? await _flutterClipboardText();

      if (rawText == null || rawText.isEmpty) return null;
      return _noteFromText(rawText, targetX, targetY);
    } catch (_) {
      final rawText = await _flutterClipboardText();
      if (rawText == null || rawText.isEmpty) return null;
      return _noteFromText(rawText, targetX, targetY);
    }
  }

  static Future<String?> _flutterClipboardText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (_) {
      return null;
    }
  }

  static CanvasNote _noteFromText(
    String rawText,
    double targetX,
    double targetY,
  ) {
    final trimmed = rawText.trim();

    final isDataImage = trimmed.startsWith('data:image/');
    final isUrl = trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        isDataImage;

    final isImageFormat = isDataImage ||
        RegExp(
          r'\.(png|jpe?g|webp|gif|bmp)(?:[?#].*)?$',
          caseSensitive: false,
        ).hasMatch(trimmed);

    if (isUrl && isImageFormat) {
      return CanvasNote(
        id: _uuid.v7(),
        x: targetX,
        y: targetY,
        contentType: NoteContentType.IMAGE,
        imageUrl: trimmed,
      );
    }

    final isTable = trimmed.contains('<table') || rawText.contains('\t');

    return CanvasNote(
      id: _uuid.v7(),
      x: targetX,
      y: targetY,
      contentType: isTable ? NoteContentType.TABLE : NoteContentType.TEXT,
      textContent: rawText,
    );
  }
}
