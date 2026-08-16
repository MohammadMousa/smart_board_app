import 'package:flutter/material.dart';
import '../models/board_tab.dart';
import '../models/canvas_item.dart';
import '../models/connection.dart';

class BoardProvider extends ChangeNotifier {
  final List<BoardTab> _tabs = [BoardTab(id: '1', title: 'board1')];
  int _activeTabIndex = 0;
  int _tabCounter = 1;

  // Session State
  String? _authToken;
  String? _userEmail;
  String? _userDisplayName;

  // Connection State
  String? _activeSourceNoteId;
  String? _hoveredConnectionId;
  Offset? _hoverCursorPos;
  ConnectionStyle _activeWireStyle = ConnectionStyle.arrow;

  // Tab Getters
  List<BoardTab> get tabs => List.unmodifiable(_tabs);
  int get activeTabIndex => _activeTabIndex;
  BoardTab get activeTab => _tabs[_activeTabIndex];

  // Canvas Getters scoped to Active Tab
  List<CanvasNote> get notes => List.unmodifiable(activeTab.notes);
  List<NodeConnection> get connections => List.unmodifiable(activeTab.connections);
  String? get activeSourceNoteId => _activeSourceNoteId;
  String? get hoveredConnectionId => _hoveredConnectionId;
  Offset? get hoverCursorPos => _hoverCursorPos;
  ConnectionStyle get activeWireStyle => _activeWireStyle;

  bool get isAuthenticated => _authToken != null;
  String? get userEmail => _userEmail;
  String? get userDisplayName => _userDisplayName;

  void setSession(String token, String email, {String? displayName}) {
    _authToken = token;
    _userEmail = email;
    _userDisplayName = displayName;
    notifyListeners();
  }

  // --- Tab Operations ---
  void addTab() {
    _tabCounter++;
    final newTab = BoardTab(id: DateTime.now().millisecondsSinceEpoch.toString(), title: 'board$_tabCounter');
    _tabs.add(newTab);
    _activeTabIndex = _tabs.length - 1;
    cancelConnection();
    notifyListeners();
  }

  void switchTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _activeTabIndex = index;
      cancelConnection();
      notifyListeners();
    }
  }

  void updateTabTitle(int index, String newTitle) {
    if (index >= 0 && index < _tabs.length && newTitle.trim().isNotEmpty) {
      _tabs[index].title = newTitle.trim();
      notifyListeners();
    }
  }

  void removeTab(int index) {
    if (_tabs.length > 1 && index >= 0 && index < _tabs.length) {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      cancelConnection();
      notifyListeners();
    }
  }

  // --- Canvas Operations ---
  void setWireStyle(ConnectionStyle style) {
    _activeWireStyle = style;
    notifyListeners();
  }

  void setHoveredConnection(String? id) {
    if (_hoveredConnectionId != id) {
      _hoveredConnectionId = id;
      notifyListeners();
    }
  }

  void addNote(CanvasNote note) {
    if (note.title.trim().isEmpty) {
      note.title = _nextNoteTitle();
    }
    activeTab.notes.add(note);
    notifyListeners();
  }

  String _nextNoteTitle() {
    var maxNumber = 0;
    final regex = RegExp(r'^Note\s+(\d+)$', caseSensitive: false);

    for (final note in activeTab.notes) {
      final match = regex.firstMatch(note.title.trim());
      if (match != null) {
        final number = int.tryParse(match.group(1)!) ?? 0;
        if (number > maxNumber) maxNumber = number;
      }
    }

    return 'Note ${maxNumber + 1}';
  }

  void removeNote(String id) {
    activeTab.notes.removeWhere((n) => n.id == id);
    activeTab.connections.removeWhere((c) => c.sourceNodeId == id || c.targetNodeId == id);
    if (_activeSourceNoteId == id) _activeSourceNoteId = null;
    notifyListeners();
  }

  void removeConnection(String connectionId) {
    activeTab.connections.removeWhere((c) => c.id == connectionId);
    _hoveredConnectionId = null;
    notifyListeners();
  }

  void updateNotePosition(String id, double deltaX, double deltaY, double scale) {
    final index = activeTab.notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      activeTab.notes[index].x += (deltaX / scale);
      activeTab.notes[index].y += (deltaY / scale);
      notifyListeners();
    }
  }

  void updateNoteSize(String id, double deltaWidth, double deltaHeight, double scale) {
    final index = activeTab.notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      activeTab.notes[index].width = (activeTab.notes[index].width + (deltaWidth / scale)).clamp(240.0, 1200.0);
      activeTab.notes[index].height = (activeTab.notes[index].height + (deltaHeight / scale)).clamp(160.0, 1000.0);
      notifyListeners();
    }
  }

  void updateNoteTitle(String id, String newTitle) {
    final index = activeTab.notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      activeTab.notes[index].title = newTitle;
      notifyListeners();
    }
  }

  void setNoteBadge(String id, String? emoji) {
    final index = activeTab.notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      activeTab.notes[index].statusBadge = emoji;
      notifyListeners();
    }
  }

  void updateCursorHover(Offset scenePos) {
    if (_activeSourceNoteId != null) {
      _hoverCursorPos = scenePos;
      notifyListeners();
    }
  }

  void handleOutputPortClick(String noteId, Offset portScenePos) {
    if (_activeSourceNoteId == noteId) {
      _activeSourceNoteId = null;
      _hoverCursorPos = null;
    } else {
      _activeSourceNoteId = noteId;
      _hoverCursorPos = portScenePos;
    }
    notifyListeners();
  }

  void handleInputPortClick(String targetNoteId) {
    if (_activeSourceNoteId == null) return;

    if (_activeSourceNoteId == targetNoteId) {
      cancelConnection();
      return;
    }

    final duplicateExists = activeTab.connections.any((c) {
      if (c.sourceNodeId == _activeSourceNoteId &&
          c.targetNodeId == targetNoteId) {
        return true;
      }

      // A bi-directional connection is represented by one link with arrows
      // at both ends, so don't allow the reverse copy to be created.
      if (c.style == ConnectionStyle.bidirectional &&
          c.sourceNodeId == targetNoteId &&
          c.targetNodeId == _activeSourceNoteId) {
        return true;
      }

      return false;
    });

    if (!duplicateExists) {
      activeTab.connections.add(NodeConnection(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceNodeId: _activeSourceNoteId!,
        targetNodeId: targetNoteId,
        style: _activeWireStyle,
      ));
    }

    _activeSourceNoteId = null;
    _hoverCursorPos = null;
    notifyListeners();
  }

  void cancelConnection() {
    _activeSourceNoteId = null;
    _hoverCursorPos = null;
    notifyListeners();
  }

  void clearBoard() {
    activeTab.notes.clear();
    activeTab.connections.clear();
    _activeSourceNoteId = null;
    _hoverCursorPos = null;
    notifyListeners();
  }
}