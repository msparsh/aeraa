part of 'main.dart';

// --- TASKBOOK ENGINE ---

class Core {
  Map<int, TaskItem> items = {};
  Map<int, TaskItem> archive = {};
  Map<String, String> aliases = {};
  int _nextId = 1;
  final StorageService _storage = StorageService();

  Timer? _saveTimer;

  Core() {}

  Future<void> init() async {
    final data = await _storage.loadData();
    if (data != null) {
      if (data['items'] != null) items = _decodeMap(data['items']);
      if (data['archive'] != null) archive = _decodeMap(data['archive']);
      if (data['aliases'] != null) {
        aliases = Map<String, String>.from(data['aliases'] as Map);
      }
    }
    _refreshNextId();
  }

  Map<int, TaskItem> _decodeMap(dynamic raw) {
    final result = <int, TaskItem>{};
    if (raw is! Map) return result;
    raw.forEach((key, value) {
      try {
        final id = int.parse(key.toString());
        result[id] = TaskItem.fromJson(value as Map<String, dynamic>);
      } catch (_) {}
    });
    return result;
  }

  int _maxId(Map<int, dynamic> map) =>
      map.isEmpty ? 0 : map.keys.reduce((a, b) => a > b ? a : b);

  void _refreshNextId() {
    final mItems = _maxId(items);
    final mArch = _maxId(archive);
    _nextId = (mItems > mArch ? mItems : mArch) + 1;
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _storage.saveData({
        'items': items.map((k, v) => MapEntry(k.toString(), v.toJson())),
        'archive': archive.map((k, v) => MapEntry(k.toString(), v.toJson())),
        'aliases': aliases,
      });
    });
  }

  void forceSaveImmediate() {
    _saveTimer?.cancel();
    _storage.saveData({
      'items': items.map((k, v) => MapEntry(k.toString(), v.toJson())),
      'archive': archive.map((k, v) => MapEntry(k.toString(), v.toJson())),
      'aliases': aliases,
    });
  }

  int _generateId() => _nextId++;

  /// Helper to fetch an item and avoid repetitive parse checks.
  TaskItem? _getItem(String idRaw) => items[int.tryParse(idRaw) ?? -1];

  ({int timestamp, String dateString}) _nowMeta() {
    final now = DateTime.now();
    return (
      timestamp: now.millisecondsSinceEpoch,
      dateString: now.toLocal().toString().split(' ')[0],
    );
  }

  ({
    List<String> boards,
    List<String> tags,
    int priority,
    String description,
    String? dueDate,
  })
  _parseOptions(List<String> args) {
    final boards = <String>[], tags = <String>[], descWords = <String>[];
    int priority = 1;
    String? dueDate;

    for (var t in args) {
      final lower = t.toLowerCase();
      if (t.startsWith('@') && t.length > 1) {
        boards.add(t);
      } else if (lower.startsWith('#') && t.length > 1) {
        tags.add(lower);
      } else if (lower.startsWith('p:') && t.length == 3) {
        priority = int.tryParse(t[2])?.clamp(1, 3) ?? 1;
      } else if (lower.startsWith('due:') &&
          RegExp(r'^due:\d{2}-\d{2}-\d{4}$').hasMatch(lower)) {
        dueDate = t.substring(4);
      } else {
        descWords.add(t);
      }
    }

    return (
      boards: boards.isEmpty ? ['inbox'] : boards,
      tags: tags,
      priority: priority,
      description: descWords.join(' ').trim(),
      dueDate: dueDate,
    );
  }

  ({bool error, String msg, int? id}) _createItem(
    List<String> args, {
    required bool isTask,
  }) {
    if (args.isEmpty)
      return (
        error: true,
        msg: '${isTask ? 'task' : 'note'} description required',
        id: null,
      );

    final parsed = _parseOptions(args);
    if (parsed.description.isEmpty)
      return (error: true, msg: 'empty description', id: null);

    final id = _generateId();
    final meta = _nowMeta();
    items[id] = TaskItem(
      id: id,
      description: parsed.description,
      boards: parsed.boards,
      tags: parsed.tags,
      priority: isTask ? parsed.priority : 1,
      dueDate: isTask ? parsed.dueDate : null,
      dateString: meta.dateString,
      timestamp: meta.timestamp,
      isTask: isTask,
    );

    _save();
    return (
      error: false,
      msg: 'Created ${isTask ? 'task' : 'note'} [$id]: ${parsed.description}',
      id: id,
    );
  }

  ({bool error, String msg, int? id}) createTask(List<String> args) =>
      _createItem(args, isTask: true);

  ({bool error, String msg}) createNote(List<String> args) {
    final res = _createItem(args, isTask: false);
    return (error: res.error, msg: res.msg);
  }

  ({bool error, String msg, List<int> valid}) _validateIds(
    List<String> idsRaw, {
    bool fromArchive = false,
  }) {
    final pool = fromArchive ? archive : items;
    final valid = <int>[];
    for (var raw in idsRaw) {
      final num = int.tryParse(raw);
      if (num == null || !pool.containsKey(num)) {
        return (error: true, msg: 'Invalid ID: $raw not found', valid: []);
      }
      valid.add(num);
    }
    return (error: false, msg: '', valid: valid);
  }

  ({bool error, String msg}) _processItems(
    List<String> idsRaw,
    String? Function(TaskItem) action,
  ) {
    final v = _validateIds(idsRaw);
    if (v.error) return (error: true, msg: v.msg);

    final results = <String, List<int>>{};
    for (var id in v.valid) {
      final statusGroup = action(items[id]!);
      if (statusGroup != null)
        results.putIfAbsent(statusGroup, () => []).add(id);
    }

    if (results.isEmpty) return (error: true, msg: 'No eligible items updated');

    _save();
    return (
      error: false,
      msg: results.entries
          .map((e) => '${e.key}: ${e.value.join(', ')}')
          .join('. '),
    );
  }

  ({bool error, String msg}) checkTasks(List<String> idsRaw) =>
      _processItems(idsRaw, (item) {
        if (!item.isTask) return null;
        item.isComplete = !item.isComplete;
        if (item.isComplete) item.inProgress = false;
        return item.isComplete ? 'Checked (complete)' : 'Unchecked (pending)';
      });

  ({bool error, String msg}) beginTasks(List<String> idsRaw) =>
      _processItems(idsRaw, (item) {
        if (!item.isTask || item.isComplete) return null;
        item.inProgress = !item.inProgress;
        return item.inProgress ? 'Started' : 'Paused';
      });

  ({bool error, String msg}) starItems(List<String> idsRaw) =>
      _processItems(idsRaw, (item) {
        item.isStarred = !item.isStarred;
        return item.isStarred ? 'Starred' : 'Unstarred';
      });

  ({bool error, String msg}) toggleArchive(List<String> idsRaw) {
    final toggled = <String>[];
    final notFound = <String>[];

    for (var raw in idsRaw) {
      final id = int.tryParse(raw);
      if (id == null) {
        notFound.add(raw);
        continue;
      }

      if (items.containsKey(id)) {
        // Active -> Archive (plus all subtasks) 🗄️⬇️
        final toArchive = <int>{};
        void collect(int currentId) {
          if (!toArchive.add(currentId)) return;
          items.values
              .where((it) => it.parentId == currentId)
              .forEach((c) => collect(c.id));
        }

        collect(id);

        for (var aId in toArchive) {
          final item = items.remove(aId);
          if (item != null) archive[aId] = item;
        }
        toggled.add('$id (archived)');
      } else if (archive.containsKey(id)) {
        // Archive -> Active (plus all subtasks!) 🗂️⬆️
        final toRestore = <int>{};
        void collectRestore(int currentId) {
          if (!toRestore.add(currentId)) return;
          archive.values
              .where((it) => it.parentId == currentId)
              .forEach((c) => collectRestore(c.id));
        }

        collectRestore(id);

        for (var rId in toRestore) {
          final item = archive.remove(rId);
          if (item != null) {
            items[rId] = item;

            // If the explicitly requested item has a parent that is STILL in the archive,
            // we sever the tie so it becomes a root item on the active board. ✂️
            if (rId == id &&
                item.parentId != null &&
                !items.containsKey(item.parentId)) {
              item.parentId = null;
            }
          }
        }
        toggled.add('$id (restored)');
      } else {
        notFound.add(raw);
      }
    }

    if (toggled.isEmpty)
      return (error: true, msg: 'IDs not found: ${notFound.join(', ')} 🤷♂️');

    _save();
    return (error: false, msg: ' ${toggled.join(', ')} ');
  }

  ({bool error, String msg}) editItem(String idRaw, String newDesc) {
    final item = _getItem(idRaw);
    if (item == null) return (error: true, msg: 'ID $idRaw not found');
    if (newDesc.trim().isEmpty)
      return (error: true, msg: 'Description required');

    item.description = newDesc.trim();
    _save();
    return (
      error: false,
      msg: 'Updated item ${item.id}: "${item.description}"',
    );
  }

  ({bool error, String msg}) moveBoards(
    String idRaw,
    List<String> targetBoards,
  ) {
    final item = _getItem(idRaw);
    if (item == null) return (error: true, msg: 'ID $idRaw not found');

    final boards = targetBoards
        .map((b) {
          final clean = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');
          return clean == 'inbox' ? clean : (clean.isNotEmpty ? '@$clean' : '');
        })
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList();

    if (boards.isEmpty) boards.add('inbox');

    item.parentId = null;
    item.boards = boards;
    _save();
    return (
      error: false,
      msg: 'Moved [${item.id}] to boards: ${boards.join(', ')} (Unlinked)',
    );
  }

  bool _wouldCreateCycle(int currentId, int targetParentId) {
    TaskItem? parent = items[targetParentId];
    while (parent != null) {
      if (parent.id == currentId) return true;
      parent = parent.parentId != null ? items[parent.parentId!] : null;
    }
    return false;
  }

  ({bool error, String msg}) getLocation(String idRaw) {
    final item = _getItem(idRaw);
    if (item == null) return (error: true, msg: 'ID $idRaw not found');

    final loc = item.parentId != null
        ? 'a subtask of @${item.parentId}'
        : 'on board(s): ${item.boards.join(', ')}';
    return (error: false, msg: 'Item [${item.id}] is currently $loc');
  }

  ({bool error, String msg}) createSubtask(
    String parentIdRaw,
    List<String> args,
  ) {
    final parent = _getItem(parentIdRaw);
    if (parent == null)
      return (error: true, msg: 'Parent ID $parentIdRaw not found');

    final res = createTask(args);
    if (res.error) return (error: res.error, msg: res.msg);

    final newId = res.id!;
    if (_wouldCreateCycle(newId, parent.id)) {
      items.remove(newId);
      _save();
      return (
        error: true,
        msg: 'Cannot create subtask - would create circular reference',
      );
    }

    items[newId]!.parentId = parent.id;
    _save();
    return (
      error: false,
      msg: 'Created subtask [$newId] linked to parent [${parent.id}]',
    );
  }

  ({bool error, String msg}) reparentTask(
    String subtaskIdRaw,
    String newParentIdRaw,
  ) {
    final sub = _getItem(subtaskIdRaw);
    final parent = _getItem(newParentIdRaw);

    if (sub == null)
      return (error: true, msg: 'Subtask ID $subtaskIdRaw not found');
    if (parent == null)
      return (error: true, msg: 'Parent ID $newParentIdRaw not found');
    if (sub.id == parent.id)
      return (error: true, msg: 'Cannot nest an item under itself');

    if (_wouldCreateCycle(sub.id, parent.id))
      return (
        error: true,
        msg: 'Cannot reparent - would create circular reference',
      );

    sub.parentId = parent.id;
    _save();
    return (error: false, msg: 'Nested [${sub.id}] under [${parent.id}]');
  }

  ({bool error, String msg}) updatePriority(String idRaw, [String? levelRaw]) {
    final item = _getItem(idRaw);
    if (item == null) return (error: true, msg: 'ID $idRaw not found');
    if (!item.isTask) return (error: true, msg: 'Only tasks have priority');

    if (levelRaw != null) {
      final level = int.tryParse(levelRaw);
      if (level == null || level < 1 || level > 3)
        return (error: true, msg: 'Priority must be 1,2,3');
      item.priority = level;
    } else {
      // Toggle magic!
      item.priority = item.priority == 3 ? 1 : item.priority + 1;
    }

    _save();
    final prioStr = const ['', 'NORMAL', 'MEDIUM', 'HIGH'][item.priority];
    return (error: false, msg: 'Priority of task ${item.id} set to $prioStr');
  }

  ({bool error, String msg}) updateDue(String idRaw, String dueDateRaw) {
    final item = _getItem(idRaw);
    if (item == null) return (error: true, msg: 'ID $idRaw not found');
    if (!item.isTask)
      return (error: true, msg: 'Only tasks can have due dates');

    if (dueDateRaw != 'none' &&
        !RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(dueDateRaw)) {
      return (
        error: true,
        msg: 'Due date must be DD-MM-YYYY (or "none" to remove)',
      );
    }

    item.dueDate = dueDateRaw == 'none' ? null : dueDateRaw;
    _save();
    return (
      error: false,
      msg: 'Due date for task ${item.id} set to ${item.dueDate ?? 'none'}',
    );
  }

  ({bool error, String msg}) clearCompleted() {
    final toDelete = items.values
        .where((it) => it.isTask && it.isComplete)
        .map((it) => it.id.toString())
        .toList();

    if (toDelete.isEmpty)
      return (error: false, msg: 'No completed tasks to clear');
    return toggleArchive(toDelete);
  }

  ({bool error, String msg}) toggleTag(String idRaw, List<String> targetTags) {
    final item = _getItem(idRaw);
    if (item == null) return (error: true, msg: 'ID $idRaw not found');

    final formattedTags = targetTags
        .where((t) => t.startsWith('#') && t.length > 1)
        .map((t) => t.toLowerCase())
        .toList();

    if (formattedTags.isEmpty)
      return (error: true, msg: 'Provide at least one #tag to toggle');

    final added = <String>[];
    final removed = <String>[];

    for (var t in formattedTags) {
      if (item.tags.contains(t)) {
        item.tags.remove(t);
        removed.add(t);
      } else {
        item.tags.add(t);
        added.add(t);
      }
    }

    _save();
    final parts = <String>[];
    if (added.isNotEmpty) parts.add('Added: ${added.join(' ')}');
    if (removed.isNotEmpty) parts.add('Removed: ${removed.join(' ')}');
    return (
      error: false,
      msg: 'Updated [${item.id}] tags -> ${parts.join(', ')}',
    );
  }

  // --- VIEW GENERATORS ---

  Widget _buildRichText(
    List<InlineSpan> mainSpans, {
    List<InlineSpan>? footerSpans,
  }) {
    final textWidget = RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: _kFontSize,
          height: _kLineH,
          color: Color(0xFFCCCCCC),
        ),
        children: mainSpans,
      ),
    );

    if (footerSpans == null) return textWidget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        textWidget,
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: _kMono,
              fontSize: _kFontSize - 1,
              height: 1.4,
              color: cDim,
            ),
            children: footerSpans,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  bool _isOverdue(String dueStr) {
    try {
      final parts = dueStr.split('-');
      final dueTime = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
        23,
        59,
        59,
      );
      return DateTime.now().isAfter(dueTime);
    } catch (_) {
      return false;
    }
  }

  Widget getBoardView() {
    final groups = _groupByBoard();
    final stats = _computeStats();
    final spans = <InlineSpan>[];

    for (var board in groups.keys) {
      final itemsList = groups[board]!;
      if (itemsList.isEmpty) continue;

      final tasks = itemsList.where((i) => i.isTask);
      final doneCount = tasks.where((i) => i.isComplete).length;
      final boardName = board == 'inbox' ? '@inbox' : board;

      spans.addAll([
        const TextSpan(text: '\n'),
        TextSpan(
          text: boardName,
          style: const TextStyle(
            color: Color(0xFFEEEEEE),
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFFEEEEEE), // Color of the underline
            decorationStyle: TextDecorationStyle.solid,
            // Style (solid, dashed, dotted, etc.)
            decorationThickness: 2, // Thickness of the line
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: '  [$doneCount/${tasks.length}]\n',
          style: const TextStyle(color: cDim),
        ),
      ]);

      for (var it in itemsList) {
        spans.addAll(_formatItemLine(it));
        spans.add(const TextSpan(text: '\n'));
      }
    }

    final footerSpans = <InlineSpan>[
      TextSpan(
        text: '${stats.complete}',
        style: const TextStyle(color: cGreen),
      ),
      const TextSpan(
        text: ' done · ',
        style: TextStyle(color: cDim),
      ),
      TextSpan(
        text: '${stats.inProgress}',
        style: const TextStyle(color: cBlue),
      ),
      const TextSpan(
        text: ' started · ',
        style: TextStyle(color: cDim),
      ),
      TextSpan(
        text: '${stats.pending}',
        style: const TextStyle(color: cPurple),
      ),
      const TextSpan(
        text: ' pending · ',
        style: TextStyle(color: cDim),
      ),
      TextSpan(
        text: '${stats.notes}',
        style: const TextStyle(color: cBlue),
      ),
      const TextSpan(
        text: ' notes',
        style: TextStyle(color: cDim),
      ),
    ];

    return _buildRichText(spans, footerSpans: footerSpans);
  }

  Widget getTimelineView() {
    final groups = _groupByDate();
    final spans = <InlineSpan>[
      const TextSpan(
        text: 'TIMELINE\n',
        style: TextStyle(
          color: Color(0xFFEEEEEE),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    ];

    final sortedDates = groups.keys.toList()..sort();
    for (var date in sortedDates) {
      spans.add(
        TextSpan(
          text: '\n$date\n',
          style: const TextStyle(color: cDim, letterSpacing: 0.5),
        ),
      );
      for (var it in groups[date]!) {
        spans.addAll(_formatItemLine(it));
        spans.add(const TextSpan(text: '\n'));
      }
    }
    if (spans.isNotEmpty) spans.removeLast();

    return _buildRichText(spans);
  }

  Widget getArchiveView() {
    if (archive.isEmpty)
      return const Text(
        'Archive is empty. 🕸️',
        style: TextStyle(
          color: cDim,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: _kFontSize,
        ),
      );

    final spans = <InlineSpan>[
      const TextSpan(
        text: 'ARCHIVED ITEMS\n',
        style: TextStyle(
          color: Color(0xFFEEEEEE),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    ];

    // 👇 NEW: Only grab root tasks to prevent duplicating subtasks!
    final rootArchivedItems =
        archive.values.where((it) => it.parentId == null).toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    for (var it in rootArchivedItems) {
      // 👇 NEW: Pass the isArchive flag to get that sweet formatting!
      spans.addAll(_formatItemLine(it, isArchive: true));
      spans.add(const TextSpan(text: '\n'));
    }

    if (spans.isNotEmpty) spans.removeLast();

    return _buildRichText(spans);
  }

  Map<int, TaskItem> filterItems(List<String> args) {
    final boards = <String>{};
    final reqTags = <String>{};
    final exclTags = <String>{};
    final flags = <String>{};
    final searchTerms = <String>[];

    // The definitive list of system flags
    final knownFlags = {
      'star',
      'starred',
      'done',
      'complete',
      'checked',
      'progress',
      'started',
      'pending',
      'unchecked',
      'task',
      'tasks',
      'note',
      'notes',
    };

    for (var arg in args) {
      final lower = arg.toLowerCase();
      if (lower.startsWith('@')) {
        boards.add(lower == '@inbox' ? 'inbox' : lower);
      } else if (lower.startsWith('-#') && lower.length > 2) {
        exclTags.add('#${lower.substring(2)}');
      } else if (lower.startsWith('#') && lower.length > 1) {
        reqTags.add(lower);
      } else if (knownFlags.contains(lower)) {
        flags.add(lower);
      } else {
        searchTerms.add(lower); // Unrecognized text becomes a search term!
      }
    }

    return Map.fromEntries(
      items.entries.where((e) {
        final v = e.value;

        // 1. Boards Check (OR logic)
        if (boards.isNotEmpty && !v.boards.any(boards.contains)) return false;

        // 2. Required Tags Check (AND logic)
        if (reqTags.isNotEmpty && !reqTags.every(v.tags.contains)) return false;

        // 3. Excluded Tags Check (NOT logic)
        if (exclTags.isNotEmpty && exclTags.any(v.tags.contains)) return false;

        // 4. Keyword Search Check (AND logic for precision)
        if (searchTerms.isNotEmpty) {
          final desc = v.description.toLowerCase();
          if (!searchTerms.every((term) => desc.contains(term))) return false;
        }

        // 5. State Flags Check
        return flags.every(
          (f) => switch (f) {
            'star' || 'starred' => v.isStarred,
            'done' || 'complete' || 'checked' => v.isTask && v.isComplete,
            'progress' ||
            'started' => v.isTask && v.inProgress && !v.isComplete,
            'pending' ||
            'unchecked' => v.isTask && !v.isComplete && !v.inProgress,
            'task' || 'tasks' => v.isTask,
            'note' || 'notes' => !v.isTask,
            _ => true,
          },
        );
      }),
    );
  }

  List<InlineSpan> _formatItemLine(
    TaskItem item, {
    int indent = 0,
    List<String>? parentBoards,
    Set<int>? visited,
    bool isArchive = false, // 👈 NEW: Tell it where to look for children!
  }) {
    final seen = visited ?? <int>{};
    seen.add(item.id);

    // 👈 NEW: Point to the correct pool based on the view
    final pool = isArchive ? archive : items;

    String prefix = '•';
    Color pColor = cBlue;
    TextStyle dStyle = const TextStyle(color: Color(0xFFDADADA));

    if (item.isTask) {
      if (item.isComplete) {
        prefix = '✓';
        pColor = cGreen;
        dStyle = const TextStyle(color: cDim);
      } else if (item.inProgress) {
        prefix = '•';
        pColor = cBlue;
      } else {
        prefix = '☐';
        pColor = cPurple;
      }

      if (!item.isComplete && item.priority == 3) {
        dStyle = const TextStyle(
          color: cYellow,
          decoration: TextDecoration.underline,
        );
      }
    } else {
      dStyle = const TextStyle(color: cDim);
    }

    final spacing = ' ' * (indent == 0 ? 2 : indent);
    final spans = <InlineSpan>[
      TextSpan(text: spacing),
      TextSpan(
        text: '${item.id}.',
        style: const TextStyle(color: cDim),
      ),
      TextSpan(
        text: ' $prefix ',
        style: TextStyle(color: pColor),
      ),
      TextSpan(text: item.description, style: dStyle),
    ];

    if (item.isTask && !item.isComplete) {
      if (item.priority >= 2)
        spans.add(
          const TextSpan(
            text: ' (!)',
            style: TextStyle(color: cYellow),
          ),
        );
      if (item.dueDate != null)
        spans.add(
          TextSpan(
            text: ' [due: ${item.dueDate}]',
            style: TextStyle(color: _isOverdue(item.dueDate!) ? cRed : cDim),
          ),
        );
    }

    final age = _getAge(item.timestamp);
    if (age != null)
      spans.add(
        TextSpan(
          text: ' ${age}d',
          style: const TextStyle(color: cDim),
        ),
      );
    if (item.isStarred)
      spans.add(
        const TextSpan(
          text: ' ★',
          style: TextStyle(color: cYellow),
        ),
      );

    if (item.tags.isNotEmpty) {
      spans.add(
        TextSpan(
          text: '  ${item.tags.join(' ')}',
          style: const TextStyle(color: Color(0xFFC678DD)),
        ),
      );
    }

    // 👇 UPDATED: Search the correct pool for children
    final children =
        pool.values
            .where((c) => c.parentId == item.id && !seen.contains(c.id))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    for (var child in children) {
      spans.add(const TextSpan(text: '\n'));
      spans.addAll(
        _formatItemLine(
          child,
          indent: indent == 0 ? 6 : indent + 4,
          parentBoards: parentBoards ?? item.boards,
          visited: seen,
          isArchive: isArchive, // 👈 NEW: Pass the flag down the tree
        ),
      );
    }

    return spans;
  }

  int? _getAge(int ts) {
    final days = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts))
        .inDays;
    return days == 0 ? null : days;
  }

  Map<String, List<TaskItem>> _groupByBoard() {
    final groups = <String, List<TaskItem>>{};
    for (var it in items.values) {
      if (it.parentId != null) continue;
      for (var b in it.boards) {
        groups.putIfAbsent(b, () => []).add(it);
      }
    }
    for (var b in groups.keys) {
      groups[b]!.sort((a, b) => a.id.compareTo(b.id));
    }
    return groups;
  }

  Map<String, List<TaskItem>> _groupByDate() {
    final groups = <String, List<TaskItem>>{};
    for (var it in items.values) {
      if (it.parentId != null) continue;
      groups.putIfAbsent(it.dateString, () => []).add(it);
    }
    for (var d in groups.keys) {
      groups[d]!.sort((a, b) => a.id.compareTo(b.id));
    }
    return groups;
  }

  ({int percent, int complete, int inProgress, int pending, int notes})
  _computeStats() {
    int c = 0, i = 0, p = 0, n = 0;
    for (var it in items.values) {
      if (!it.isTask)
        n++;
      else if (it.isComplete)
        c++;
      else if (it.inProgress)
        i++;
      else
        p++;
    }
    final total = c + i + p;
    return (
      percent: total == 0 ? 0 : (c * 100 ~/ total),
      complete: c,
      inProgress: i,
      pending: p,
      notes: n,
    );
  }

  ({bool error, String msg}) setAlias(List<String> args) {
    if (args.isEmpty) {
      if (aliases.isEmpty)
        return (error: false, msg: 'No aliases currently set. 📭');
      return (
        error: false,
        msg: aliases.entries.map((e) => '${e.key} = "${e.value}"').join('\n'),
      );
    }
    if (args.length < 2) {
      return (
        error: true,
        msg: 'Usage: alias <name> <command> (or "alias <name> none" to remove)',
      );
    }

    final aliasName = args[0].toLowerCase();
    final commandStr = args.sublist(1).join(' ');

    if (commandStr.toLowerCase() == 'none') {
      if (aliases.remove(aliasName) != null) {
        _save();
        return (error: false, msg: 'Alias "$aliasName" removed 🗑️');
      }
      return (error: true, msg: 'Alias "$aliasName" not found 🤷‍♂️');
    }

    // Prevent overriding real commands to avoid chaotic loops 🛑
    final reserved = {
      'task',
      '-t',
      'add',
      'note',
      '-n',
      'list',
      '-l',
      'ls',
      'board',
      'timeline',
      '-i',
      'archive',
      '-a',
      'restore',
      '-r',
      'check',
      '-c',
      'begin',
      '-b',
      'star',
      '-s',
      'delete',
      '-d',
      'sweep',
      'edit',
      '-e',
      'move',
      'mv',
      '-m',
      'm',
      'sub',
      'subtask',
      'priority',
      '-p',
      'due',
      'help',
      '-h',
      '--help',
      'alias',
    };
    if (reserved.contains(aliasName) || aliasName.startsWith('-')) {
      return (
        error: true,
        msg: 'Cannot overwrite core system command "$aliasName" 🚫',
      );
    }

    aliases[aliasName] = commandStr;
    _save();
    return (error: false, msg: 'Alias set! 🔗 $aliasName -> "$commandStr"');
  }
}
