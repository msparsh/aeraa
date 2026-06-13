import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'storage.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D0D);
const _kSurface = Color(0xFF141414);
const _kBorder = Color(0xFF1E1E1E);
const _kPrompt = Color(0xFF00FF88); // vivid green prompt symbol
const _kCaret = Color(0xFF00FF88);
const _kMono = [
  'JetBrains Mono',
  'Fira Code',
  'Cascadia Code',
  'Menlo',
  'Monaco',
  'Consolas',
  'Courier New',
];
const _kFontSize = 13.5;
const _kLineH = 1.6;
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  runApp(const TaskbookApp());
}

class TaskbookApp extends StatelessWidget {
  const TaskbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskbook',
      theme: ThemeData(
        scaffoldBackgroundColor: _kBg,
        applyElevationOverlayColor: false,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color.fromARGB(255, 255, 255, 255),
          selectionHandleColor: Color.fromARGB(255, 255, 255, 255),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: Color(0xFFBBBBBB),
            fontFamily: 'JetBrains Mono',
            fontFamilyFallback: _kMono,
            fontSize: _kFontSize,
            height: _kLineH,
          ),
        ),
      ),
      home: const TerminalScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- TERMINAL UI ---

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final Core tb = Core();
  final TextEditingController _cmdController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<Widget> _outputHistory = [];
  final List<String> _cmdHistory = [];
  int _historyPos = 0;
  bool _isNavigating = false;
  static const int maxHistory = 100;

  @override
  void initState() {
    super.initState();
    _initializeTaskbook();
  }

  Future<void> _initializeTaskbook() async {
    await tb.init();
    if (mounted) {
      _handleCommand('');
    }
  }

  @override
  void dispose() {
    _cmdController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addToHistory(String cmd) {
    if (cmd.trim().isEmpty) return;
    if (_cmdHistory.isNotEmpty && _cmdHistory.last == cmd) return;
    _cmdHistory.add(cmd);
    if (_cmdHistory.length > maxHistory) _cmdHistory.removeAt(0);
  }

  void _addUserCommand(String cmd) {
    setState(() {
      _outputHistory.add(
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 2),
          child: RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: '\$ ',
                  style: TextStyle(
                    color: Color.fromARGB(255, 255, 255, 255),
                    fontFamily: 'JetBrains Mono',
                    fontFamilyFallback: _kMono,
                    fontSize: _kFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: cmd,
                  style: const TextStyle(
                    color: Color(0xFFEEEEEE),
                    fontFamily: 'JetBrains Mono',
                    fontFamilyFallback: _kMono,
                    fontSize: _kFontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _addResponseWidget(Widget widget) {
    setState(() {
      _outputHistory.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4, left: 16),
          child: widget,
        ),
      );
    });
  }

  void _addResponse(String msg) {
    final isError = msg.startsWith('Error:');
    _addResponseWidget(
      Text(
        msg,
        style: TextStyle(
          color: isError ? const Color(0xFFE06C75) : const Color(0xFFCCCCCC),
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: _kFontSize,
          height: _kLineH,
        ),
      ),
    );
  }

  void _handleCommand(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _addResponseWidget(tb.getBoardView());
      return;
    }

    final args = trimmed.split(RegExp(r'\s+'));
    final mainCmd = args[0].toLowerCase();

    const helpMenu =
        '''task / -t / add description @board p:2                 : create task
note / -n description @board                           : create note
sub / subtask @id description                          : create subtask under parent
list / ls / -l [@board] [flags]                        : list items (flags: star,done,progress,pending,task,note)
board                                                  : dashboard view
timeline / -i                                          : timeline by creation date
archive / -a                                           : show archived items
check / -c [id1 id2 ...]                               : toggle complete
begin / -b [id1 id2 ...]                               : start/pause task
star / -s [id1 id2 ...]                                : toggle starred
delete / -d [id1 id2 ...]                              : delete & archive
sweep                                                  : remove all completed tasks
edit / -e @id new description                          : change description
move / mv / -m @id @parent_id                          : nest under another task
move / mv / -m @id @board1 @board2 ...                 : move to board(s) (unlinks)
priority / -p @id 1|2|3                                : set priority (1 normal, 3 high)
due @id DD-MM-YYYY | none                              : set or remove due date
find / -f keyword                                      : search descriptions
restore / -r [id1 id2 ...]                             : restore from archive
help / -h / --help                                     : show this menu''';

    if (['help', '-h', '--help'].contains(mainCmd)) {
      _addResponse(helpMenu);
      return;
    }
    if (mainCmd == 'board') {
      _addResponseWidget(tb.getBoardView());
      return;
    }
    if (['task', '-t', 'add'].contains(mainCmd)) {
      final res = tb.createTask(args.sublist(1));
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (['note', '-n'].contains(mainCmd)) {
      final res = tb.createNote(args.sublist(1));
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (['list', '-l', 'ls'].contains(mainCmd)) {
      final flags = <String>[];
      final boards = <String>[];
      for (int i = 1; i < args.length; i++) {
        final tok = args[i];
        if (tok.startsWith('@') || tok.toLowerCase() == 'inbox') {
          boards.add(tok);
        } else {
          flags.add(tok);
        }
      }
      final filtered = tb.listByAttributesAndBoards(flags, boards);
      if (filtered.isEmpty) {
        _addResponse('No items match.');
      } else {
        final rootItems = filtered.values
            .where((it) => it.parentId == null)
            .toList();
        rootItems.sort((a, b) => a.id.compareTo(b.id));
        final spans = <InlineSpan>[];
        for (var it in rootItems) {
          spans.addAll(tb._formatItemLine(it));
          spans.add(const TextSpan(text: '\n'));
        }
        if (spans.isNotEmpty) spans.removeLast();
        _addResponseWidget(
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: _kMono,
                fontSize: _kFontSize,
                height: _kLineH,
                color: Color(0xFFCCCCCC),
              ),
              children: spans,
            ),
          ),
        );
      }
      return;
    }
    if (['check', '-c'].contains(mainCmd)) {
      if (args.length < 2) {
        _addResponse('Usage: check id1 id2 ...');
        return;
      }
      final res = tb.checkTasks(args.sublist(1));
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (['begin', '-b'].contains(mainCmd)) {
      if (args.length < 2) {
        _addResponse('Usage: begin ids');
        return;
      }
      final res = tb.beginTasks(args.sublist(1));
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (['star', '-s'].contains(mainCmd)) {
      if (args.length < 2) {
        _addResponse('Usage: star ids');
        return;
      }
      final res = tb.starItems(args.sublist(1));
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (['delete', '-d'].contains(mainCmd)) {
      if (args.length < 2) {
        _addResponse('Usage: delete ids');
        return;
      }
      final res = tb.deleteItems(args.sublist(1));
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (mainCmd == 'sweep') {
      final res = tb.clearCompleted();
      _addResponse(res.msg);
      return;
    }
    if (['edit', '-e'].contains(mainCmd)) {
      if (args.length < 3 || !args[1].startsWith('@')) {
        _addResponse('edit @id new description');
        return;
      }
      final res = tb.editItem(args[1].substring(1), args.sublist(2).join(' '));
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (['move', 'mv', '-m', 'm'].contains(mainCmd)) {
      if (args.length < 2 || !args[1].startsWith('@')) {
        _addResponse(
          'Usage: mv @id @parent_id OR mv @id board1 board2 (unlinks)',
        );
        return;
      }
      final id = args[1].substring(1);
      if (args.length == 2) {
        final res = tb.getLocation(id);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
        return;
      }
      final targetFlag = args[2];
      final isParentId =
          targetFlag.startsWith('@') &&
          targetFlag.length > 1 &&
          RegExp(r'^\d+$').hasMatch(targetFlag.substring(1));

      if (isParentId) {
        final res = tb.reparentTask(id, targetFlag.substring(1));
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      } else {
        final res = tb.moveBoards(id, args.sublist(2));
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      }
      return;
    }
    if (['sub', 'subtask'].contains(mainCmd)) {
      if (args.length < 3 || !args[1].startsWith('@')) {
        _addResponse('Usage: sub @id [options] description');
        return;
      }
      final res = tb.createSubtask(args[1].substring(1), args.sublist(2));
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (['priority', '-p'].contains(mainCmd)) {
      if (args.length < 3 || !args[1].startsWith('@')) {
        _addResponse('priority @id 1|2|3');
        return;
      }
      final res = tb.updatePriority(args[1].substring(1), args[2]);
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (mainCmd == 'due') {
      if (args.length < 3 || !args[1].startsWith('@')) {
        _addResponse('Usage: due @id DD-MM-YYYY (or "none" to remove)');
        return;
      }
      final res = tb.updateDue(args[1].substring(1), args[2]);
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (['archive', '-a'].contains(mainCmd)) {
      _addResponseWidget(tb.getArchiveView());
      return;
    }
    if (['restore', '-r'].contains(mainCmd)) {
      if (args.length < 2) {
        _addResponse('restore ids');
        return;
      }
      final res = tb.restoreItems(args.sublist(1));
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      return;
    }
    if (['timeline', '-i'].contains(mainCmd)) {
      _addResponseWidget(tb.getTimelineView());
      return;
    }
    if (['find', '-f'].contains(mainCmd)) {
      if (args.length < 2) {
        _addResponse('find keyword');
        return;
      }
      final matches = tb.findItems(args.sublist(1));
      if (matches.isEmpty) {
        _addResponse('No matches.');
      } else {
        final matchesList = matches.values.toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        final spans = <InlineSpan>[];
        for (var it in matchesList) {
          spans.addAll(tb._formatItemLine(it));
          spans.add(const TextSpan(text: '\n'));
        }
        if (spans.isNotEmpty) spans.removeLast();
        _addResponseWidget(RichText(text: TextSpan(children: spans)));
      }
      return;
    }

    _addResponse('Command not recognized: "$mainCmd"\n\n$helpMenu');
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _isNavigating = true;
        if (_historyPos > 0) {
          setState(() {
            _historyPos--;
            _cmdController.text = _cmdHistory[_historyPos];
            _cmdController.selection = TextSelection.collapsed(
              offset: _cmdController.text.length,
            );
          });
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _isNavigating = true;
        if (_historyPos < _cmdHistory.length) {
          setState(() {
            _historyPos++;
            if (_historyPos == _cmdHistory.length) {
              _cmdController.clear();
            } else {
              _cmdController.text = _cmdHistory[_historyPos];
              _cmdController.selection = TextSelection.collapsed(
                offset: _cmdController.text.length,
              );
            }
          });
        }
        return KeyEventResult.handled;
      }
    }

    Future.microtask(() => _isNavigating = false);
    return KeyEventResult.ignored;
  }

  void _submitCommand(String text) {
    _isNavigating = false;
    setState(() {
      _outputHistory.clear();
    });

    if (text.isNotEmpty) {
      _addUserCommand(text);
      _addToHistory(text);
      _historyPos = _cmdHistory.length;
    }
    _cmdController.clear();
    _handleCommand(text);
    _focusNode.requestFocus();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Output area ─────────────────────────────────────────────────
            Expanded(
              child: Container(
                color: _kBg,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _outputHistory.length,
                  itemBuilder: (context, index) => _outputHistory[index],
                ),
              ),
            ),

            // ── Input row ───────────────────────────────────────────────────
            _InputBar(
              cmdController: _cmdController,
              focusNode: _focusNode,
              isNavigating: _isNavigating,
              onChanged: (_) {
                if (!_isNavigating) _historyPos = _cmdHistory.length;
              },
              onSubmitted: _submitCommand,
              onKeyEvent: _handleKeyEvent,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Input bar widget ──────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController cmdController;
  final FocusNode focusNode;
  final bool isNavigating;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  const _InputBar({
    required this.cmdController,
    required this.focusNode,
    required this.isNavigating,
    required this.onChanged,
    required this.onSubmitted,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Prompt symbol
          const Text(
            '\$',
            style: TextStyle(
              color: _kPrompt,
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: _kMono,
              fontSize: _kFontSize + 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Focus(
              onKeyEvent: onKeyEvent,
              child: TextField(
                controller: cmdController,
                focusNode: focusNode,
                autofocus: true,
                cursorWidth: 2,
                style: const TextStyle(
                  color: Color(0xFFEEEEEE),
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: _kMono,
                  fontSize: _kFontSize,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- DATA MODEL ---

class TaskItem {
  int id;
  String description;
  List<String> boards;
  int priority;
  bool isStarred;
  bool isComplete;
  bool inProgress;
  bool isTask;
  String dateString;
  int timestamp;
  String? dueDate;
  int? parentId;

  TaskItem({
    required this.id,
    required this.description,
    required this.boards,
    this.priority = 1,
    this.isStarred = false,
    this.isComplete = false,
    this.inProgress = false,
    required this.isTask,
    required this.dateString,
    required this.timestamp,
    this.dueDate,
    this.parentId,
  });

  TaskItem copyWith({int? newId}) {
    return TaskItem(
      id: newId ?? id,
      description: description,
      boards: List.from(boards),
      priority: priority,
      isStarred: isStarred,
      isComplete: isComplete,
      inProgress: inProgress,
      isTask: isTask,
      dateString: dateString,
      timestamp: timestamp,
      dueDate: dueDate,
      parentId: parentId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'boards': boards,
    'priority': priority,
    'isStarred': isStarred,
    'isComplete': isComplete,
    'inProgress': inProgress,
    'isTask': isTask,
    'dateString': dateString,
    'timestamp': timestamp,
    'dueDate': dueDate,
    'parentId': parentId,
  };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: json['id'],
    description: json['description'],
    boards: List<String>.from(json['boards'] ?? []),
    priority: json['priority'] ?? 1,
    isStarred: json['isStarred'] ?? false,
    isComplete: json['isComplete'] ?? false,
    inProgress: json['inProgress'] ?? false,
    isTask: json['isTask'] ?? true,
    dateString: json['dateString'],
    timestamp: json['timestamp'],
    dueDate: json['dueDate'],
    parentId: json['parentId'],
  );
}

// --- TASKBOOK ENGINE ---

class Core {
  Map<int, TaskItem> items = {};
  Map<int, TaskItem> archive = {};
  int _nextId = 1;
  final StorageService _storage = StorageService();

  static const cRed = Color(0xFFE06C75);
  static const cPurple = Color(0xFFC678DD);
  static const cGreen = Color(0xFF98C379);
  static const cBlue = Color(0xFF61AFEF);
  static const cYellow = Color(0xFFE5C07B);
  static const cDim = Color(0xFF5C6370);

  Core();

  Future<void> init() async {
    final data = await _storage.loadData();
    if (data != null) {
      if (data['items'] != null) {
        final Map<String, dynamic> itemsData = data['items'];
        items = itemsData.map(
          (key, value) => MapEntry(int.parse(key), TaskItem.fromJson(value)),
        );
      }
      if (data['archive'] != null) {
        final Map<String, dynamic> archiveData = data['archive'];
        archive = archiveData.map(
          (key, value) => MapEntry(int.parse(key), TaskItem.fromJson(value)),
        );
      }
    }
    _refreshNextId();
  }

  void _refreshNextId() {
    if (items.isEmpty && archive.isEmpty) {
      _nextId = 1;
    } else {
      final maxItem = items.isEmpty
          ? 0
          : items.keys.reduce((a, b) => a > b ? a : b);
      final maxArch = archive.isEmpty
          ? 0
          : archive.keys.reduce((a, b) => a > b ? a : b);
      _nextId = (maxItem > maxArch ? maxItem : maxArch) + 1;
    }
  }

  void _save() {
    final data = {
      'items': items.map(
        (key, value) => MapEntry(key.toString(), value.toJson()),
      ),
      'archive': archive.map(
        (key, value) => MapEntry(key.toString(), value.toJson()),
      ),
    };
    _storage.saveData(data);
  }

  int _generateId() => _nextId++;

  ({int timestamp, String dateString}) _nowMeta() {
    final now = DateTime.now();
    return (
      timestamp: now.millisecondsSinceEpoch,
      dateString: now.toLocal().toString().split(' ')[0],
    );
  }

  ({List<String> boards, int priority, String description, String? dueDate})
  _parseOptions(List<String> args) {
    final boards = <String>[];
    final desc = <String>[];
    int priority = 1;
    String? dueDate;

    for (var t in args) {
      if (t.startsWith('@') && t.length > 1) {
        boards.add(t);
      } else if (RegExp(r'^p:[123]$', caseSensitive: false).hasMatch(t)) {
        priority = int.parse(t[2]);
      } else if (RegExp(
        r'^due:\d{2}-\d{2}-\d{4}$',
        caseSensitive: false,
      ).hasMatch(t)) {
        dueDate = t.substring(4);
      } else {
        desc.add(t);
      }
    }

    return (
      boards: boards.isEmpty ? ['inbox'] : boards,
      priority: priority,
      description: desc.join(' ').trim(),
      dueDate: dueDate,
    );
  }

  ({bool error, String msg, int? id}) createTask(List<String> args) {
    if (args.isEmpty) {
      return (error: true, msg: 'Error: task description required', id: null);
    }
    final parsed = _parseOptions(args);
    if (parsed.description.isEmpty) {
      return (error: true, msg: 'Error: empty description', id: null);
    }

    final id = _generateId();
    final meta = _nowMeta();
    items[id] = TaskItem(
      id: id,
      description: parsed.description,
      boards: parsed.boards,
      priority: parsed.priority,
      dueDate: parsed.dueDate,
      dateString: meta.dateString,
      timestamp: meta.timestamp,
      isTask: true,
    );
    _save();
    return (
      error: false,
      msg: 'Created task [$id]: ${parsed.description}',
      id: id,
    );
  }

  ({bool error, String msg}) createNote(List<String> args) {
    if (args.isEmpty) {
      return (error: true, msg: 'Error: note description required');
    }
    final parsed = _parseOptions(args);
    if (parsed.description.isEmpty) {
      return (error: true, msg: 'Error: empty description');
    }

    final id = _generateId();
    final meta = _nowMeta();
    items[id] = TaskItem(
      id: id,
      description: parsed.description,
      boards: parsed.boards,
      dateString: meta.dateString,
      timestamp: meta.timestamp,
      isTask: false,
    );
    _save();
    return (error: false, msg: 'Created note [$id]: ${parsed.description}');
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

  ({bool error, String msg}) checkTasks(List<String> idsRaw) {
    final v = _validateIds(idsRaw);
    if (v.error) return (error: true, msg: v.msg);

    final checked = <int>[];
    final unchecked = <int>[];

    for (var id in v.valid) {
      final it = items[id]!;
      if (!it.isTask) {
        return (error: true, msg: 'Item $id is a note, cannot check/uncheck');
      }
      it.isComplete = !it.isComplete;
      if (it.isComplete) it.inProgress = false;
      if (it.isComplete) {
        checked.add(id);
      } else {
        unchecked.add(id);
      }
    }
    _save();

    var msg = '';
    if (checked.isNotEmpty) {
      msg += 'Checked (complete): ${checked.join(', ')}. ';
    }
    if (unchecked.isNotEmpty) {
      msg += 'Unchecked (pending): ${unchecked.join(', ')}.';
    }
    return (error: false, msg: msg.isEmpty ? 'No tasks updated' : msg.trim());
  }

  ({bool error, String msg}) beginTasks(List<String> idsRaw) {
    final v = _validateIds(idsRaw);
    if (v.error) return (error: true, msg: v.msg);

    final started = <int>[];
    final paused = <int>[];

    for (var id in v.valid) {
      final it = items[id]!;
      if (!it.isTask) {
        return (error: true, msg: 'Item $id is a note, cannot start/pause');
      }
      if (it.isComplete) {
        return (error: true, msg: 'Task $id is completed, cannot start');
      }
      it.inProgress = !it.inProgress;
      if (it.inProgress) {
        started.add(id);
      } else {
        paused.add(id);
      }
    }
    _save();

    var msg = '';
    if (started.isNotEmpty) msg += 'Started: ${started.join(', ')}. ';
    if (paused.isNotEmpty) msg += 'Paused: ${paused.join(', ')}.';
    return (error: false, msg: msg.trim());
  }

  ({bool error, String msg}) starItems(List<String> idsRaw) {
    final v = _validateIds(idsRaw);
    if (v.error) return (error: true, msg: v.msg);

    final starred = <int>[];
    final unstarred = <int>[];

    for (var id in v.valid) {
      items[id]!.isStarred = !items[id]!.isStarred;
      if (items[id]!.isStarred) {
        starred.add(id);
      } else {
        unstarred.add(id);
      }
    }
    _save();

    var msg = '';
    if (starred.isNotEmpty) msg += 'Starred: ${starred.join(', ')}. ';
    if (unstarred.isNotEmpty) msg += 'Unstarred: ${unstarred.join(', ')}.';
    return (error: false, msg: msg.trim());
  }

  ({bool error, String msg}) deleteItems(List<String> idsRaw) {
    final v = _validateIds(idsRaw);
    if (v.error) return (error: true, msg: v.msg);

    final moved = <int>[];

    List<int> getAllDescendants(int itemId, Map<int, TaskItem> allItems) {
      final descendants = <int>[];
      for (var entry in allItems.entries) {
        if (entry.value.parentId == itemId) {
          descendants.add(entry.key);
          descendants.addAll(getAllDescendants(entry.key, allItems));
        }
      }
      return descendants;
    }

    final idsToDelete = <int>{};
    for (var id in v.valid) {
      if (!items.containsKey(id)) continue;
      idsToDelete.add(id);
      idsToDelete.addAll(getAllDescendants(id, items));
    }

    for (var id in idsToDelete) {
      final item = items[id];
      if (item == null) continue;
      final archiveId = _nextArchiveId();
      archive[archiveId] = item.copyWith(newId: archiveId);
      items.remove(id);
      moved.add(id);
    }

    _save();
    return (error: false, msg: 'Deleted and archived: ${moved.join(', ')}');
  }

  int _nextArchiveId() {
    if (archive.isEmpty) return 1;
    return archive.keys.reduce((a, b) => a > b ? a : b) + 1;
  }

  ({bool error, String msg}) restoreItems(List<String> idsRaw) {
    final v = _validateIds(idsRaw, fromArchive: true);
    if (v.error) return (error: true, msg: v.msg);

    final map = <int, int>{};
    final restores = <String>[];

    for (var oldId in v.valid) {
      final archived = archive[oldId];
      if (archived == null) continue;
      final newId = _generateId();

      final restoredItem = archived.copyWith(newId: newId);
      map[oldId] = newId;
      items[newId] = restoredItem;
      archive.remove(oldId);
      restores.add('$oldId->$newId');
    }

    for (var entry in map.entries) {
      final newId = entry.value;
      final item = items[newId]!;
      if (item.parentId != null) {
        if (map.containsKey(item.parentId)) {
          item.parentId = map[item.parentId];
        } else if (!items.containsKey(item.parentId)) {
          item.parentId = null;
        }
      }
    }

    _save();
    return (error: false, msg: 'Restored: ${restores.join(', ')}');
  }

  ({bool error, String msg}) editItem(String idRaw, String newDesc) {
    final id = int.tryParse(idRaw);
    if (id == null || !items.containsKey(id)) {
      return (error: true, msg: 'ID $id not found');
    }
    if (newDesc.trim().isEmpty) {
      return (error: true, msg: 'Description required');
    }
    items[id]!.description = newDesc.trim();
    _save();
    return (error: false, msg: 'Updated item $id: "${newDesc.trim()}"');
  }

  ({bool error, String msg}) moveBoards(
    String idRaw,
    List<String> targetBoards,
  ) {
    final id = int.tryParse(idRaw);
    if (id == null || !items.containsKey(id)) {
      return (error: true, msg: 'ID $id not found');
    }

    final boards = <String>[];
    for (var b in targetBoards) {
      final clean = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');
      if (clean == 'inbox') {
        boards.add('inbox');
      } else if (clean.isNotEmpty) {
        boards.add('@$clean');
      }
    }
    if (boards.isEmpty) boards.add('inbox');

    items[id]!.parentId = null;
    items[id]!.boards = boards.toSet().toList();
    _save();
    return (
      error: false,
      msg: 'Moved [$id] to boards: ${boards.join(', ')} (Unlinked)',
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
    final id = int.tryParse(idRaw);
    if (id == null || !items.containsKey(id)) {
      return (error: true, msg: 'ID $id not found');
    }

    final item = items[id]!;
    final loc = item.parentId != null
        ? 'a subtask of @${item.parentId}'
        : 'on board(s): ${item.boards.join(', ')}';
    return (error: false, msg: 'Item [$id] is currently $loc');
  }

  ({bool error, String msg}) createSubtask(
    String parentIdRaw,
    List<String> args,
  ) {
    final parentId = int.tryParse(parentIdRaw);
    if (parentId == null || !items.containsKey(parentId)) {
      return (error: true, msg: 'Parent ID $parentId not found');
    }

    final res = createTask(args);
    if (res.error) return (error: res.error, msg: res.msg);

    final newId = res.id!;
    if (_wouldCreateCycle(newId, parentId)) {
      items.remove(newId);
      _save();
      return (
        error: true,
        msg: 'Cannot create subtask - would create circular reference',
      );
    }

    items[newId]!.parentId = parentId;
    _save();
    return (
      error: false,
      msg: 'Created subtask [$newId] linked to parent [$parentId]',
    );
  }

  ({bool error, String msg}) reparentTask(
    String subtaskIdRaw,
    String newParentIdRaw,
  ) {
    final subId = int.tryParse(subtaskIdRaw);
    final pId = int.tryParse(newParentIdRaw);

    if (subId == null || !items.containsKey(subId)) {
      return (error: true, msg: 'Subtask ID $subId not found');
    }
    if (pId == null || !items.containsKey(pId)) {
      return (error: true, msg: 'Parent ID $pId not found');
    }
    if (subId == pId) {
      return (error: true, msg: 'Cannot nest an item under itself');
    }

    if (_wouldCreateCycle(subId, pId)) {
      return (
        error: true,
        msg: 'Cannot reparent - would create circular reference',
      );
    }

    items[subId]!.parentId = pId;
    _save();
    return (error: false, msg: 'Nested [$subId] under [$pId]');
  }

  ({bool error, String msg}) updatePriority(String idRaw, String levelRaw) {
    final id = int.tryParse(idRaw);
    final level = int.tryParse(levelRaw);

    if (id == null || !items.containsKey(id)) {
      return (error: true, msg: 'ID $id not found');
    }
    if (level == null || ![1, 2, 3].contains(level)) {
      return (error: true, msg: 'Priority must be 1,2,3');
    }
    if (!items[id]!.isTask) {
      return (error: true, msg: 'Only tasks have priority');
    }

    items[id]!.priority = level;
    _save();
    final prio = level == 3 ? 'HIGH' : (level == 2 ? 'MEDIUM' : 'NORMAL');
    return (error: false, msg: 'Priority of task $id set to $prio');
  }

  ({bool error, String msg}) updateDue(String idRaw, String dueDateRaw) {
    final id = int.tryParse(idRaw);
    if (id == null || !items.containsKey(id)) {
      return (error: true, msg: 'ID $id not found');
    }
    if (!items[id]!.isTask) {
      return (error: true, msg: 'Only tasks can have due dates');
    }

    if (dueDateRaw != 'none' &&
        !RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(dueDateRaw)) {
      return (
        error: true,
        msg: 'Due date must be DD-MM-YYYY (or "none" to remove)',
      );
    }

    items[id]!.dueDate = dueDateRaw == 'none' ? null : dueDateRaw;
    _save();
    return (
      error: false,
      msg: 'Due date for task $id set to ${items[id]!.dueDate ?? 'none'}',
    );
  }

  ({bool error, String msg}) clearCompleted() {
    final toDelete = <String>[];
    for (var entry in items.entries) {
      if (entry.value.isTask && entry.value.isComplete) {
        toDelete.add(entry.key.toString());
      }
    }
    if (toDelete.isEmpty) {
      return (error: false, msg: 'No completed tasks to clear');
    }
    return deleteItems(toDelete);
  }

  // --- VIEW GENERATORS ---

  Widget getBoardView() {
    final groups = _groupByBoard();
    final stats = _computeStats();

    // Build per-board rich text
    final spans = <InlineSpan>[];

    for (var board in groups.keys) {
      final itemsList = groups[board]!;
      if (itemsList.isEmpty) continue;

      final taskCount = itemsList.where((i) => i.isTask).length;
      final completeCount = itemsList
          .where((i) => i.isTask && i.isComplete)
          .length;
      final boardName = board == 'inbox' ? '@inbox' : board;

      spans.add(const TextSpan(text: '\n'));
      spans.add(
        TextSpan(
          text: boardName,
          style: const TextStyle(
            color: Color(0xFFEEEEEE),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: '  $completeCount/$taskCount done\n',
          style: const TextStyle(color: cDim),
        ),
      );

      for (var it in itemsList) {
        spans.addAll(_formatItemLine(it));
        spans.add(const TextSpan(text: '\n'));
      }
    }

    // Stats footer spans
    final footerSpans = <InlineSpan>[
      TextSpan(
        text: '${stats.complete}',
        style: const TextStyle(color: cGreen),
      ),
      const TextSpan(
        text: ' done  ',
        style: TextStyle(color: cDim),
      ),
      TextSpan(
        text: '${stats.inProgress}',
        style: const TextStyle(color: cBlue),
      ),
      const TextSpan(
        text: ' started  ',
        style: TextStyle(color: cDim),
      ),
      TextSpan(
        text: '${stats.pending}',
        style: const TextStyle(color: cPurple),
      ),
      const TextSpan(
        text: ' pending  ',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main items
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: _kMono,
              fontSize: _kFontSize,
              height: _kLineH,
              color: Color(0xFFCCCCCC),
            ),
            children: spans,
          ),
        ),
        const SizedBox(height: 12),
        // Stats row
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
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: _kFontSize,
          height: _kLineH,
          color: Color(0xFFCCCCCC),
        ),
        children: spans,
      ),
    );
  }

  Widget getArchiveView() {
    if (archive.isEmpty) {
      return const Text(
        'Archive is empty.',
        style: TextStyle(
          color: cDim,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: _kFontSize,
        ),
      );
    }
    final spans = <InlineSpan>[
      const TextSpan(
        text: 'ARCHIVE\n',
        style: TextStyle(
          color: Color(0xFFEEEEEE),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    ];
    for (var entry in archive.entries) {
      final item = entry.value;
      final type = item.isTask
          ? (item.isComplete ? '[done]' : '[task]')
          : '[note]';
      final boards = item.boards.isNotEmpty ? item.boards.join(',') : '';
      spans.add(
        TextSpan(text: ' ${entry.key}. $type ${item.description}  $boards\n'),
      );
    }
    if (spans.isNotEmpty) spans.removeLast();
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: _kFontSize,
          height: _kLineH,
          color: Color(0xFFCCCCCC),
        ),
        children: spans,
      ),
    );
  }

  Map<int, TaskItem> findItems(List<String> terms) {
    final lower = terms.map((t) => t.toLowerCase()).toList();
    final result = <int, TaskItem>{};
    for (var entry in items.entries) {
      if (lower.any(
        (term) => entry.value.description.toLowerCase().contains(term),
      )) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Map<int, TaskItem> filterByAttributes(List<String> attrList) {
    var filtered = Map<int, TaskItem>.from(items);
    for (var a in attrList) {
      final low = a.toLowerCase();
      if (['star', 'starred'].contains(low)) {
        filtered.removeWhere((_, v) => !v.isStarred);
      } else if (['done', 'complete', 'checked'].contains(low)) {
        filtered.removeWhere((_, v) => !v.isTask || !v.isComplete);
      } else if (['progress', 'started'].contains(low)) {
        filtered.removeWhere(
          (_, v) => !v.isTask || !v.inProgress || v.isComplete,
        );
      } else if (['pending', 'unchecked'].contains(low)) {
        filtered.removeWhere(
          (_, v) => !v.isTask || v.isComplete || v.inProgress,
        );
      } else if (['task', 'tasks'].contains(low)) {
        filtered.removeWhere((_, v) => !v.isTask);
      } else if (['note', 'notes'].contains(low)) {
        filtered.removeWhere((_, v) => v.isTask);
      }
    }
    return filtered;
  }

  Map<int, TaskItem> listByAttributesAndBoards(
    List<String> flags,
    List<String> boards,
  ) {
    var filtered = filterByAttributes(flags);
    if (boards.isNotEmpty) {
      final boardSet = boards
          .map((b) => b == 'inbox' ? 'inbox' : (b.startsWith('@') ? b : '@$b'))
          .toSet();
      filtered.removeWhere(
        (_, v) => !v.boards.any((b) => boardSet.contains(b)),
      );
    }
    return filtered;
  }

  List<InlineSpan> _formatItemLine(
    TaskItem item, {
    int indent = 0,
    List<String>? parentBoards,
  }) {
    final spans = <InlineSpan>[];
    final spacing = ' ' * (indent == 0 ? 2 : indent);

    spans.add(TextSpan(text: spacing));
    spans.add(
      TextSpan(
        text: '${item.id}.',
        style: const TextStyle(color: cDim),
      ),
    );

    String prefixText;
    Color prefixColor;
    TextStyle descStyle = const TextStyle(color: Color(0xFFDADADA));

    if (item.isTask) {
      if (item.isComplete) {
        prefixText = '✓';
        prefixColor = cGreen;
        descStyle = const TextStyle(color: cDim);
      } else if (item.inProgress) {
        prefixText = '•';
        prefixColor = cBlue;
      } else {
        prefixText = '☐';
        prefixColor = cPurple;
      }
    } else {
      prefixText = '•';
      prefixColor = cBlue;
      descStyle = const TextStyle(color: cDim);
    }

    spans.add(const TextSpan(text: ' '));
    spans.add(
      TextSpan(
        text: prefixText,
        style: TextStyle(color: prefixColor),
      ),
    );
    spans.add(const TextSpan(text: ' '));

    if (item.isTask && !item.isComplete && item.priority == 3) {
      descStyle = const TextStyle(
        color: cYellow,
        decoration: TextDecoration.underline,
      );
    }

    spans.add(TextSpan(text: item.description, style: descStyle));

    if (item.isTask && !item.isComplete) {
      if (item.priority == 3 || item.priority == 2) {
        spans.add(
          const TextSpan(
            text: ' (!)',
            style: TextStyle(color: cYellow),
          ),
        );
      }
    }

    if (item.isTask && item.dueDate != null && !item.isComplete) {
      try {
        final parts = item.dueDate!.split('-');
        final dueTime = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
          23,
          59,
          59,
        );
        final isOverdue = DateTime.now().isAfter(dueTime);
        spans.add(
          TextSpan(
            text: ' [due: ${item.dueDate}]',
            style: TextStyle(color: isOverdue ? cRed : cDim),
          ),
        );
      } catch (_) {
        spans.add(
          TextSpan(
            text: ' [due: ${item.dueDate}]',
            style: const TextStyle(color: cDim),
          ),
        );
      }
    }

    final age = _getAge(item.timestamp);
    if (age != null) {
      spans.add(
        TextSpan(
          text: ' ${age}d',
          style: const TextStyle(color: cDim),
        ),
      );
    }

    if (item.isStarred) {
      spans.add(
        const TextSpan(
          text: ' ★',
          style: TextStyle(color: cYellow),
        ),
      );
    }

    final children = items.values.where((c) => c.parentId == item.id).toList();
    if (children.isNotEmpty) {
      children.sort((a, b) => a.id.compareTo(b.id));
      for (var child in children) {
        spans.add(const TextSpan(text: '\n'));
        spans.addAll(
          _formatItemLine(
            child,
            indent: indent == 0 ? 6 : indent + 4,
            parentBoards: parentBoards ?? item.boards,
          ),
        );
      }
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
    final boardsSet = {'inbox'};
    for (var it in items.values) {
      boardsSet.addAll(it.boards);
    }

    final groups = <String, List<TaskItem>>{};
    for (var b in boardsSet) {
      groups[b] = [];
    }

    for (var it in items.values) {
      if (it.parentId != null) continue;
      for (var b in it.boards) {
        groups[b]?.add(it);
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
    int complete = 0, inProgress = 0, pending = 0, notes = 0;
    for (var it in items.values) {
      if (it.isTask) {
        if (it.isComplete) {
          complete++;
        } else if (it.inProgress) {
          inProgress++;
        } else {
          pending++;
        }
      } else {
        notes++;
      }
    }
    final total = complete + inProgress + pending;
    final percent = total == 0 ? 0 : (complete * 100 ~/ total);
    return (
      percent: percent,
      complete: complete,
      inProgress: inProgress,
      pending: pending,
      notes: notes,
    );
  }
}
