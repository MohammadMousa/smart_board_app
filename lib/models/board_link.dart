enum LinkType {
  line,
  singleArrow,
  doubleArrow, // New Bi-Directional Link Type
}

class BoardLink {
  final String id;
  final String startNoteId;
  final String endNoteId;
  final LinkType type;

  BoardLink({
    required this.id,
    required this.startNoteId,
    required this.endNoteId,
    this.type = LinkType.singleArrow,
  });
}
