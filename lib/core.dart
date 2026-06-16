part of 'main.dart';

// --- TASKBOOK ENGINE ---

class Core {
  Map<int, TaskItem> items = {};
  Map<int, TaskItem> archive = {};
  Map<String, String> aliases = {};
  int _nextId = 1;
  final StorageService _storage = StorageService();

  Timer? _saveTimer;

  double fontSize = 13.5;
  double opacity = 1.0;
  String defaultView = 'board';
  int historyLimit = 100;
  List<String> history = [];
  bool showGlobalAge = true;
  bool showGlobalTags = true;

  Core() {}

  Future<void> init() async {
    final data = await _storage.loadData();
    if (data != null) {
      if (data['items'] != null) items = _decodeMap(data['items']);
      if (data['archive'] != null) archive = _decodeMap(data['archive']);
      if (data['aliases'] != null) {
        aliases = Map<String, String>.from(data['aliases'] as Map);
      }
      // 👇 Trust the saved ID, or fallback to the manual calculation if it's an older save file
      if (data['nextId'] != null) {
        _nextId = data['nextId'] as int;
      } else {
        _refreshNextId();
      }
      if (data['settings'] != null) {
        final s = data['settings'] as Map;
        fontSize = (s['font_size'] as num?)?.toDouble() ?? 13.5;
        opacity = (s['opacity'] as num?)?.toDouble() ?? 1.0;
        defaultView = s['default'] as String? ?? 'board';
        historyLimit = s['history_limit'] as int? ?? 100;
        showGlobalAge = s['show_global_age'] as bool? ?? true;
        showGlobalTags = s['show_global_tags'] as bool? ?? true;
      }
      if (data['history'] != null) {
        history = List<String>.from(data['history'] as List);
      }
    }
  }

  void resetSettings() {
    fontSize = 13.5;
    opacity = 1.0;
    defaultView = 'board';
    historyLimit = 100;
    showGlobalAge = true;
    showGlobalTags = true;
    _save();
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

  Map<String, dynamic> _buildSavePayload() => {
    'items': items.map((k, v) => MapEntry(k.toString(), v.toJson())),
    'archive': archive.map((k, v) => MapEntry(k.toString(), v.toJson())),
    'aliases': aliases,
    'nextId': _nextId, // 👈 Save the exact next ID
    'settings': {
      'font_size': fontSize,
      'opacity': opacity,
      'default': defaultView,
      'history_limit': historyLimit,
      'show_global_age': showGlobalAge,
      'show_global_tags': showGlobalTags,
    },
    'history': history,
  };

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _storage.saveData(_buildSavePayload());
    });
  }

  void forceSaveImmediate() {
    _saveTimer?.cancel();
    _storage.saveData(_buildSavePayload());
  }

  void saveHistory(List<String> newHistory) {
    history = List<String>.from(newHistory);
    _save();
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
      } else if (lower.startsWith('due:')) {
        if (RegExp(r'^due:\d{2}-\d{2}-\d{4}$').hasMatch(lower)) {
          dueDate = t.substring(4);
        } else {
          throw FormatException('Invalid due date format. Use DD-MM-YYYY');
        }
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

    var parsed;
    try {
      parsed = _parseOptions(args);
    } catch (e) {
      return (
        error: true,
        msg: e.toString().replaceFirst('FormatException: ', ''),
        id: null,
      );
    }

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

  /// Recursively collects an item and all its nested subtasks from a given pool.
  Set<int> _getFamilyTree(int rootId, Map<int, TaskItem> pool) {
    final family = <int>{};
    void collect(int currentId) {
      if (!family.add(currentId)) return; // Prevent cycles
      pool.values
          .where((it) => it.parentId == currentId)
          .forEach((c) => collect(c.id));
    }

    collect(rootId);
    return family;
  }

  ({bool error, String msg}) toggleArchive(List<String> idsRaw) {
    final toggled = <String>[];
    final notFound = <String>[];
    final targetIds = <int>{};

    String normalizeBoard(String b) {
      final lower = b.toLowerCase();
      if (lower == '@inbox' || lower == 'inbox') return 'inbox';
      if (lower.startsWith('@')) return lower;
      return '@$lower';
    }

    // Normalization Pass
    for (var raw in idsRaw) {
      final id = int.tryParse(raw);
      if (id != null) {
        if (items.containsKey(id) || archive.containsKey(id)) {
          targetIds.add(id);
        } else {
          notFound.add(raw);
        }
      } else if (raw.startsWith('@')) {
        final targetBoard = normalizeBoard(raw);
        var foundAny = false;
        for (var item in items.values) {
          if (item.boards.map(normalizeBoard).contains(targetBoard)) {
            targetIds.add(item.id);
            foundAny = true;
          }
        }
        if (!foundAny) {
          notFound.add(raw);
        }
      } else {
        notFound.add(raw);
      }
    }

    final processed =
        <int>{}; // 👈 CRITICAL: Track IDs to prevent double-bouncing!

    // The "Family Tree" Sweep
    for (var id in targetIds) {
      // 👈 CRITICAL: Skip if already moved as part of a parent's family tree
      if (processed.contains(id)) continue;

      if (items.containsKey(id)) {
        // Active -> Archive 🗄️⬇️
        final family = _getFamilyTree(id, items);
        for (var fId in family) {
          final item = items.remove(fId);
          if (item != null) archive[fId] = item;
        }
        processed.addAll(family); // 👈 Mark family as processed
        toggled.add('$id (archived)');
      } else if (archive.containsKey(id)) {
        // Archive -> Active 🗂️⬆️
        final family = _getFamilyTree(id, archive);
        for (var fId in family) {
          final item = archive.remove(fId);
          if (item != null) {
            items[fId] = item;
            // Sever tie if parent is still archived
            if (fId == id &&
                item.parentId != null &&
                !items.containsKey(item.parentId)) {
              item.parentId = null;
            }
          }
        }
        processed.addAll(family); // 👈 Mark family as processed
        toggled.add('$id (restored)');
      }
    }

    if (toggled.isEmpty) {
      return (error: true, msg: 'IDs/Boards not found: ${notFound.join(', ')}');
    }

    _save();
    final msgBuffer = StringBuffer(toggled.join(', '));
    if (notFound.isNotEmpty) {
      msgBuffer.write('. Unresolved: ${notFound.join(', ')}');
    }
    return (error: false, msg: ' ${msgBuffer.toString()} ');
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
        .map((t) => t.startsWith('#') ? t.toLowerCase() : '#${t.toLowerCase()}')
        .where((t) => t.length > 1)
        .toList();

    if (formattedTags.isEmpty)
      return (error: true, msg: 'Provide at least one valid tag to toggle');

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


  ({bool error, String msg}) setAlias(List<String> args) {
    if (args.isEmpty) {
      if (aliases.isEmpty)
        return (error: false, msg: 'No aliases currently set.');
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
        return (error: false, msg: 'Alias "$aliasName" removed');
      }
      return (error: true, msg: 'Alias "$aliasName" not found');
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
        msg: 'Cannot overwrite core system command "$aliasName"',
      );
    }

    aliases[aliasName] = commandStr;
    _save();
    return (error: false, msg: 'Alias set! $aliasName -> "$commandStr"');
  }

  ({bool error, String msg}) manageSettings(List<String> args) {
    if (args.isEmpty) {
      final fsDiff = fontSize != 13.5;
      final fsPrefix = fsDiff ? '* ' : '  ';
      final fsFormatted =
          '${fsPrefix}manage font_size <number>              : Set the terminal font size. '
          '${fsDiff ? '(current: $fontSize, default: 13.5)' : '(default: 13.5)'}';

      final opDiff = opacity != 1.0;
      final opPrefix = opDiff ? '* ' : '  ';
      final opFormatted =
          '${opPrefix}manage opacity <0.1-1.0>               : Set the window opacity. '
          '${opDiff ? '(current: $opacity, default: 1.0)' : '(default: 1.0)'}';

      final dfDiff = defaultView != 'board';
      final dfPrefix = dfDiff ? '* ' : '  ';
      final dfFormatted =
          '${dfPrefix}manage default <board|timeline>        : Set default view on start and empty command. '
          '${dfDiff ? '(current: $defaultView, default: board)' : '(default: board)'}';

      final hlDiff = historyLimit != 100;
      final hlPrefix = hlDiff ? '* ' : '  ';
      final hlFormatted =
          '${hlPrefix}manage history_limit <num>             : Set maximum number of command history. '
          '${hlDiff ? '(current: $historyLimit, default: 100)' : '(default: 100)'}';

      return (
        error: false,
        msg:
            'ACTIVE CONFIGURATIONS & COMMANDS\n'
            '$fsFormatted\n'
            '$opFormatted\n'
            '$dfFormatted\n'
            '$hlFormatted\n'
            '  manage reset                           : Reset all configurations.',
      );
    }

    final sub = args[0].toLowerCase();
    if (sub == 'reset') {
      resetSettings();
      return (error: false, msg: 'Settings reset to default values.');
    } else if (sub == 'font_size') {
      if (args.length < 2) {
        return (error: true, msg: 'Usage: manage font_size <number>');
      }
      final size = double.tryParse(args[1]);
      if (size == null || size <= 0) {
        return (error: true, msg: 'Font size must be a positive number.');
      }
      fontSize = size;
      forceSaveImmediate();
      return (error: false, msg: 'Font size set to $size');
    } else if (sub == 'opacity') {
      if (args.length < 2) {
        return (error: true, msg: 'Usage: manage opacity <0.1-1.0>');
      }
      final op = double.tryParse(args[1]);
      if (op == null || op < 0.1 || op > 1.0) {
        return (
          error: true,
          msg: 'Opacity must be a number between 0.1 and 1.0 (inclusive).',
        );
      }
      opacity = op;
      forceSaveImmediate();
      return (error: false, msg: 'Opacity set to $op');
    } else if (sub == 'default') {
      if (args.length < 2) {
        return (error: true, msg: 'Usage: manage default <board|timeline>');
      }
      final view = args[1].toLowerCase();
      if (view != 'board' && view != 'timeline') {
        return (
          error: true,
          msg: 'Default view must be "board" or "timeline".',
        );
      }
      defaultView = view;
      forceSaveImmediate();
      return (error: false, msg: 'Default view set to $view');
    } else if (sub == 'history_limit') {
      if (args.length < 2) {
        return (error: true, msg: 'Usage: manage history_limit <number>');
      }
      final limit = int.tryParse(args[1]);
      if (limit == null || limit <= 0) {
        return (error: true, msg: 'History limit must be a positive integer.');
      }
      historyLimit = limit;
      while (history.length > historyLimit) {
        history.removeAt(0);
      }
      forceSaveImmediate();
      return (error: false, msg: 'History limit set to $limit');
    }

    return (
      error: true,
      msg:
          'Unknown manage option "$sub". Options are font_size, opacity, default, history_limit, reset.',
    );
  }
}
