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
  final TextEditingController _cmdController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<TerminalNode> _outputHistory = [];
  final List<String> _cmdHistory = [];
  int _historyPos = 0;
  bool _isNavigating = false;
  static const int maxHistory = 100;

  static const _helpMenu =
      '''task / -t / add description @board p:2                 : create task
note / -n description @board                           : create note
sub / subtask id description                           : create subtask under parent
list / ls / -l [@board] [#tag] [flags] [keywords]      : search and super-filter items
board                                                  : dashboard view
timeline / -i                                          : timeline by creation date
archive / -a [id1 id2 ...]                             : view archive OR toggle archive state
check / -c [id1 id2 ...]                               : toggle complete
begin / -b [id1 id2 ...]                               : start/pause task
star / -s [id1 id2 ...]                                : toggle starred
delete / -d / restore / -r [id1 id2 ...]               : toggle archive state (alias)
sweep                                                  : remove all completed tasks
edit / -e id new description                           : change description
move / mv / -m id parent_id                            : nest under another task
move / mv / -m id @board1 @board2 ...                  : move to board(s) (unlinks)
tag id #tag1 [#tag2 ...]                               : toggle tag(s) on item
priority / -p id [1|2|3]                               : cycle priority OR set to 1/2/3
due id DD-MM-YYYY | none                               : set or remove due date
alias name command                                     : create or remove a custom alias
help / -h / --help                                     : show this menu''';

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
          fontSize: _kFontSize,
          height: _kLineH,
        ),
      ),
    );
  }

  /// Universal method to display a list of items based on filter arguments 📋
  void _displayList(List<String> filterArgs) {
    final filtered = tb.filterItems(filterArgs);
    if (filtered.isEmpty) {
      _addResponse('No items match your criteria. 📭');
      return;
    }

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

    _addNode(
      widget: RichText(
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
        // e.g., 'star' with no args -> show all starred items 🌟
        _displayList([viewFlag]);
      } else if (usageMsg != null) {
        // e.g., 'move' with no args -> show usage error ❌
        _addResponse(usageMsg);
      } else {
        _addResponse('Error: Missing arguments. ⚠️');
      }
    } else {
      // Execute the actual core function! ⚡
      final res = action(args);
      _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
    }
  }

  void _handleCommand(String raw, [Set<String>? visited]) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _addNode(widget: tb.getBoardView());
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
              text: trimmed,
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
    );

    // 👇 NEW: ALIAS INTERCEPTOR 🕵️‍♂️
    // If the typed command matches an alias, swap it out and re-run!
    if (tb.aliases.containsKey(mainCmd)) {
      final activeVisited = visited ?? <String>{};
      if (activeVisited.contains(mainCmd)) {
        _addResponse('Error: Circular alias loop detected for "$mainCmd" 🔄');
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
        _addNode(widget: tb.getBoardView());

      case 'task' || '-t' || 'add':
        final res = tb.createTask(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'note' || '-n':
        final res = tb.createNote(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'list' || '-l' || 'ls':
        _displayList(tailArgs);

      // 💡 Improved: Guard clause prevents nested if/else!
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

      case 'delete' || '-d':
        final res = tb.toggleArchive(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'sweep':
        final res = tb.clearCompleted();
        _addResponse(res.msg);

      // 💡 Improved: Flattened edit logic!
      case 'edit' || '-e' when tailArgs.length < 2:
        _addResponse('Usage: edit id new description');
      case 'edit' || '-e':
        final res = tb.editItem(tailArgs[0], tailArgs.sublist(1).join(' '));
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      // 💡 Improved: Complex 'move' command is now beautifully separated!
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

      case 'archive' || '-a' when tailArgs.isEmpty:
        _addNode(widget: tb.getArchiveView());
      case 'restore' || '-r' when tailArgs.isEmpty:
        _addResponse('Usage: restore id1 [id2 ...]');
      case 'archive' || '-a' || 'restore' || '-r':
        final res = tb.toggleArchive(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'timeline' || '-i':
        _addNode(widget: tb.getTimelineView());

      case 'alias':
        final res = tb.setAlias(tailArgs);
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
                  itemBuilder: (context, index) {
                    final node = _outputHistory[index];
                    if (node.command != null) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 2),
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
