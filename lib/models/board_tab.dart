import 'canvas_item.dart';
import 'connection.dart';

class BoardTab {
  final String id;
  String title;
  final List<CanvasNote> notes;
  final List<NodeConnection> connections;

  BoardTab({
    required this.id,
    required this.title,
    List<CanvasNote>? notes,
    List<NodeConnection>? connections,
  })  : notes = notes ?? [],
        connections = connections ?? [];
}
