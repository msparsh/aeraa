part of 'main.dart';

// --- TERMINAL UI ---

/// Data record for storing terminal output history
typedef TerminalNode = ({String? command, Widget? widget});

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final Core tb = Core();
  late final Renderer tp = Renderer(tb);
  final TextEditingController _cmdController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<TerminalNode> _outputHistory = [];
  final List<String> _cmdHistory = [];
  int _historyPos = 0;
  bool _isNavigating = false;

  static const _helpMenu = '''
COMMAND REFERENCE

Create
  task, -t, add <desc>      : Create a task (Options: @board #tag due:DD-MM-YYYY p:1-3)
  note, -n <desc>           : Create a note (Options: @board #tag)
  sub, subtask <id> <desc>  : Create a subtask under a specific parent ID

View & Filter
  board                     : Show the default board view
  timeline, -i              : Show tasks grouped by creation date
  list, -l, ls [filters]    : Search and filter items. 
                              Filters: @board, #tag, -#tag (exclude), star, done, pending, progress, task, note
  archive, -a               : View the archive

Update
  check, -c <id...>         : Toggle complete/pending status
  begin, -b <id...>         : Toggle in-progress/paused status
  star, -s <id...>          : Toggle starred status
  priority, -p <id> [1-3]   : Set priority level (omitting the level cycles it)
  due <id> [DD-MM-YYYY]     : Set due date (use "none" to remove)

Modify & Organize
  edit, -e <id> <desc>      : Edit an item's description
  tag <id> #tag1...         : Toggle specific tags on an item
  move, mv, -m <id> <dest>  : Nest under a parent ID, or unnest to @boards
  delete, -d <id...>        : Send items to the archive
  restore, -r <id...>       : Restore items from the archive
  sweep                     : Clear and archive all completed tasks

System
  alias <name> <cmd>        : Create a shortcut (e.g., alias hw list @homework)
  alias <name> none         : Remove a specific alias
  alias                     : List all active aliases
  manage                    : View and modify configuration settings
  help, -h, --help          : Show this menu
  ''';

  @override
  void initState() {
    super.initState();
    _initializeTaskbook();
  }

  Future<void> _initializeTaskbook() async {
    await tb.init();
    try {
      await windowManager.setOpacity(tb.opacity);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _cmdHistory.clear();
        _cmdHistory.addAll(tb.history);
        _historyPos = _cmdHistory.length;
      });
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
    _trimHistory();
    tb.saveHistory(_cmdHistory);
  }

  void _trimHistory() {
    while (_cmdHistory.length > tb.historyLimit) {
      _cmdHistory.removeAt(0);
    }
  }

  /// Universal method to add terminal output nodes (command or widget)
  void _addNode({String? command, Widget? widget}) {
    setState(() => _outputHistory.add((command: command, widget: widget)));
  }

  /// Wrapper for text responses with error coloring
  void _addResponse(String msg) {
    final isError = msg.startsWith('Error:');
    _addNode(
      widget: Text(
        msg,
        style: TextStyle(
          color: isError ? const Color(0xFFE06C75) : const Color(0xFFCCCCCC),
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: tb.fontSize,
          height: _kLineH,
        ),
      ),
    );
  }

  /// Universal method to display a list of items based on filter arguments 📋
  void _displayList(List<String> filterArgs) {
    final filtered = tb.filterItems(filterArgs);
    if (filtered.isEmpty) {
      _addResponse('No items match your criteria.');
      return;
    }

    final rootItems = filtered.values
        .where((it) => it.parentId == null)
        .toList();
    rootItems.sort((a, b) => a.id.compareTo(b.id));

    final spans = <InlineSpan>[];
    for (var it in rootItems) {
      spans.addAll(
        tp.formatItemLine(
          it,
          showBoards:
              true, // 👈 Crucial for understanding where filtered results live
          showTags: true,
          showAge: true,
        ),
      );
      spans.add(const TextSpan(text: '\n'));
    }
    if (spans.isNotEmpty) spans.removeLast();

    _addNode(
      widget: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontFamilyFallback: _kMono,
            fontSize: tb.fontSize,
            height: _kLineH,
            color: const Color(0xFFCCCCCC),
          ),
          children: spans,
        ),
      ),
    );
  }

  /// Reusable dispatcher: Executes an action if IDs are provided,
  /// OR displays a filtered view if arguments are empty. 🚦
  void _executeOrView(
    List<String> args, {
    required ({bool error, String msg}) Function(List<String>) action,
    String? viewFlag,
    String? usageMsg,
  }) {
    if (args.isEmpty) {
      if (viewFlag != null) {
        _displayList([viewFlag]);
      } else if (usageMsg != null) {
        _addResponse(usageMsg);
      } else {
        _addResponse('Error: Missing arguments.');
      }
    } else {
      final res = action(args);
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
    }
  }

  void _handleCommand(String raw, [Set<String>? visited]) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      if (tb.defaultView == 'timeline') {
        _addNode(widget: tp.getTimelineView());
      } else {
        _addNode(widget: tp.getBoardView());
      }
      return;
    }

    final matches = RegExp(r'[^\s"]+|"([^"]*)"').allMatches(trimmed);
    final args = matches.map((m) => m.group(1) ?? m.group(0)!).toList();

    final mainCmd = args[0].toLowerCase();
    final tailArgs = args.sublist(1);

    // Add user command to history
    _addNode(
      command: trimmed,
      widget: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '\$ ',
              style: TextStyle(
                color: const Color.fromARGB(255, 255, 255, 255),
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: _kMono,
                fontSize: tb.fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: trimmed,
              style: TextStyle(
                color: const Color(0xFFEEEEEE),
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: _kMono,
                fontSize: tb.fontSize,
              ),
            ),
          ],
        ),
      ),
    );

    // 👇 NEW: ALIAS INTERCEPTOR 🕵️‍♂️
    // If the typed command matches an alias, swap it out and re-run!
    if (tb.aliases.containsKey(mainCmd)) {
      final activeVisited = visited ?? <String>{};
      if (activeVisited.contains(mainCmd)) {
        _addResponse('Error: Circular alias loop detected for "$mainCmd"');
        return;
      }
      activeVisited.add(mainCmd);

      final aliasedCmd = tb.aliases[mainCmd]!;
      // Append any extra arguments the user passed after the alias
      final extraArgs = tailArgs.isNotEmpty ? ' ${tailArgs.join(' ')}' : '';

      // Recursively run the real command 🔁
      _handleCommand('$aliasedCmd$extraArgs', activeVisited);
      return; // Stop execution here for the original alias command
    }
    // 👆 END ALIAS INTERCEPTOR

    switch (mainCmd) {
      case 'help' || '-h' || '--help':
        _addResponse(_helpMenu);

      case 'board':
        _addNode(widget: tp.getBoardView());

      case 'task' || '-t' || 'add':
        final res = tb.createTask(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'note' || '-n':
        final res = tb.createNote(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'list' || '-l' || 'ls':
        _displayList(tailArgs);

      case 'tag' when tailArgs.length < 2:
        _addResponse('Usage: tag id #tag1 [#tag2 ...]');
      case 'tag':
        final res = tb.toggleTag(tailArgs[0], tailArgs.sublist(1));
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'check' || '-c':
        _executeOrView(tailArgs, action: tb.checkTasks, viewFlag: 'done');

      case 'begin' || '-b':
        _executeOrView(tailArgs, action: tb.beginTasks, viewFlag: 'progress');

      case 'star' || '-s':
        _executeOrView(tailArgs, action: tb.starItems, viewFlag: 'star');

      case 'delete' || '-d' when tailArgs.isEmpty:
        _addResponse('Usage: delete id1 [id2 ... / @board1 ...]');
      case 'delete' || '-d':
        final res = tb.toggleArchive(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'sweep':
        final res = tb.clearCompleted();
        _addResponse(res.msg);

      case 'edit' || '-e' when tailArgs.length < 2:
        _addResponse('Usage: edit id new description');
      case 'edit' || '-e':
        final res = tb.editItem(tailArgs[0], tailArgs.sublist(1).join(' '));
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'move' || 'mv' || '-m' || 'm' when tailArgs.isEmpty:
        _addResponse(
          'Usage: mv id parent_id OR mv id @board1 @board2 (unlinks)',
        );
      case 'move' || 'mv' || '-m' || 'm' when tailArgs.length == 1:
        final res = tb.moveBoards(tailArgs[0], ['inbox']);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
      case 'move' || 'mv' || '-m' || 'm':
        final id = tailArgs[0];
        final targetFlag = tailArgs[1];

        if (RegExp(r'^\d+$').hasMatch(targetFlag)) {
          if (tailArgs.length > 2) {
            _addResponse('Error: Reparenting only takes one target ID.');
            return;
          }
          final res = tb.reparentTask(id, targetFlag);
          _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
        } else {
          final res = tb.moveBoards(id, tailArgs.sublist(1));
          _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
        }

      case 'sub' || 'subtask' when tailArgs.length < 2:
        _addResponse('Usage: sub id [options] description');
      case 'sub' || 'subtask':
        final res = tb.createSubtask(tailArgs[0], tailArgs.sublist(1));
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'priority' || '-p' when tailArgs.isEmpty || tailArgs.length > 2:
        _addResponse('Usage: priority id [1|2|3]');
      case 'priority' || '-p':
        final res = tb.updatePriority(
          tailArgs[0],
          tailArgs.length > 1 ? tailArgs[1] : null,
        );
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'due' when tailArgs.isEmpty || tailArgs.length > 2:
        _addResponse('Usage: due id [DD-MM-YYYY] (leave date blank to remove)');
      case 'due':
        final targetDate = tailArgs.length > 1 ? tailArgs[1] : 'none';
        final res = tb.updateDue(tailArgs[0], targetDate);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'archive' || '-a' when tailArgs.isNotEmpty:
        _addResponse('Usage: archive');
      case 'archive' || '-a':
        _addNode(widget: tp.getArchiveView());
      case 'restore' || '-r' when tailArgs.isEmpty:
        _addResponse('Usage: restore id1 [id2 ...]');
      case 'restore' || '-r':
        final res = tb.toggleArchive(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'timeline' || '-i':
        _addNode(widget: tp.getTimelineView());

      case 'alias':
        final res = tb.setAlias(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'manage':
        final res = tb.manageSettings(tailArgs);
        if (!res.error) {
          try {
            await windowManager.setOpacity(tb.opacity);
          } catch (_) {}
          _trimHistory();
          tb.saveHistory(_cmdHistory);
          setState(() {});
        }
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      default:
        _addResponse('Command not recognized: "$mainCmd"\n\n$_helpMenu');
    }
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
      _addToHistory(text);
      _historyPos = _cmdHistory.length;
    }
    _cmdController.clear();
    _handleCommand(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Stack(
          children: [
            // ── Content ─────────────────────────────────────────────────────
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Output area ─────────────────────────────────────────────
                  Expanded(
                    child: Container(
                      color: _kBg,
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 10,
                      ),
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _outputHistory.length,
                        itemBuilder: (context, index) {
                          final node = _outputHistory[index];
                          if (node.command != null) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 14,
                                bottom: 2,
                              ),
                              child: node.widget,
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(
                              top: 6,
                              bottom: 4,
                              left: 16,
                            ),
                            child: node.widget!,
                          );
                        },
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
                    fontSize: tb.fontSize,
                  ),
                ],
              ),
            ),

            // ── Overlay Title Bar ───────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: kWindowCaptionHeight,
              child: const WindowCaption(
                brightness: Brightness.dark,
                backgroundColor: Colors.transparent,
              ),
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

  final double fontSize;

  const _InputBar({
    required this.cmdController,
    required this.focusNode,
    required this.isNavigating,
    required this.onChanged,
    required this.onSubmitted,
    required this.onKeyEvent,
    required this.fontSize,
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
          Text(
            '\$',
            style: TextStyle(
              color: _kPrompt,
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: _kMono,
              fontSize: fontSize + 1,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
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
                style: TextStyle(
                  color: const Color(0xFFEEEEEE),
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: _kMono,
                  fontSize: fontSize,
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
