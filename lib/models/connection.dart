enum ConnectionStyle { line, arrow, bidirectional }

class NodeConnection {
  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final ConnectionStyle style;

  NodeConnection({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    this.style = ConnectionStyle.arrow,
  });
}
