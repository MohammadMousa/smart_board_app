import 'package:flutter/material.dart';

enum NoteContentType { TEXT, TABLE, IMAGE }
enum ImageFitMode { contain, cover, fitWidth, fitHeight }

class CanvasNote {
  final String id;
  String title;
  double x;
  double y;
  double width;
  double height;

  NoteContentType contentType;
  String textContent;

  // Table Data (2D List representing Rows x Columns)
  List<List<String>> tableData;

  // Image Data
  String imageUrl;
  ImageFitMode imageFit;

  // Status Emoji/Badge
  String? statusBadge;

  CanvasNote({
    required this.id,
    this.title = '',
    required this.x,
    required this.y,
    this.width = 340.0,
    this.height = 240.0,
    this.contentType = NoteContentType.TEXT,
    this.textContent = 'Click to edit note content...',
    List<List<String>>? tableData,
    this.imageUrl = '',
    this.imageFit = ImageFitMode.contain,
    this.statusBadge,
  }) : tableData = tableData ?? [
    ['Header 1', 'Header 2'],
    ['Row 1 Cell 1', 'Row 1 Cell 2'],
  ];

  BoxFit get fitAsBoxFit {
    switch (imageFit) {
      case ImageFitMode.contain:
        return BoxFit.contain;
      case ImageFitMode.cover:
        return BoxFit.cover;
      case ImageFitMode.fitWidth:
        return BoxFit.fitWidth;
      case ImageFitMode.fitHeight:
        return BoxFit.fitHeight;
    }
  }
}