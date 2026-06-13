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
list / ls / -l [@board] [flags]                        : list items (flags: star,done,progress,pending,task,note)
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
priority / -p id [1|2|3]                               : cycle priority OR set to 1/2/3
due id DD-MM-YYYY | none                               : set or remove due date
find / -f keyword                                      : search descriptions
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

  void _handleCommand(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _addNode(widget: tb.getBoardView());
      return;
    }

    final args = trimmed.split(RegExp(r'\s+'));
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
        if (tailArgs.isEmpty) {
          _addResponse('No items match.');
        } else {
          final flags = <String>[];
          final boards = <String>[];
          for (var tok in tailArgs) {
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
        }

      case 'check' || '-c':
        final res = tb.checkTasks(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'begin' || '-b':
        final res = tb.beginTasks(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'star' || '-s':
        final res = tb.starItems(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'delete' || '-d':
        final res = tb.toggleArchive(tailArgs);
        _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);

      case 'sweep':
        final res = tb.clearCompleted();
        _addResponse(res.msg);

      case 'edit' || '-e':
        if (tailArgs.length < 2) {
          _addResponse('Usage: edit id new description');
        } else {
          final res = tb.editItem(tailArgs[0], tailArgs.sublist(1).join(' '));
          _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
        }

      case 'move' || 'mv' || '-m' || 'm':
        if (tailArgs.isEmpty) {
          _addResponse(
            'Usage: mv id parent_id OR mv id @board1 @board2 (unlinks)',
          );
        } else {
          final id = tailArgs[0];
          if (tailArgs.length == 1) {
            final res = tb.getLocation(id);
            _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
          } else {
            final targetFlag = tailArgs[1];
            // Since parents are now raw numbers, we just check if it's strictly digits!
            final isParentId = RegExp(r'^\d+$').hasMatch(targetFlag);
            if (isParentId) {
              final res = tb.reparentTask(id, targetFlag);
              _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
            } else {
              final res = tb.moveBoards(id, tailArgs.sublist(1));
              _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
            }
          }
        }

      case 'sub' || 'subtask':
        if (tailArgs.length < 2) {
          _addResponse('Usage: sub id [options] description');
        } else {
          final res = tb.createSubtask(tailArgs[0], tailArgs.sublist(1));
          _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
        }

      case 'priority' || '-p':
        if (tailArgs.isEmpty) {
          _addResponse('Usage: priority id [1|2|3]');
        } else {
          final res = tb.updatePriority(
            tailArgs[0],
            tailArgs.length > 1 ? tailArgs[1] : null,
          );
          _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
        }

      case 'due':
        if (tailArgs.length < 2) {
          _addResponse('Usage: due id DD-MM-YYYY (or "none" to remove)');
        } else {
          final res = tb.updateDue(tailArgs[0], tailArgs[1]);
          _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
        }

      case 'archive' || '-a' || 'delete' || '-d' || 'restore' || '-r':
        if (tailArgs.isEmpty) {
          if (mainCmd == 'archive' || mainCmd == '-a') {
            _addNode(widget: tb.getArchiveView());
          } else {
            _addResponse('Usage: $mainCmd id1 [id2 ...]');
          }
        } else {
          final res = tb.toggleArchive(tailArgs);
          _addResponse(res.error ? 'Error: ${res.msg}' : res.msg);
        }

      case 'timeline' || '-i':
        _addNode(widget: tb.getTimelineView());

      case 'find' || '-f':
        final matches = tb.findItems(tailArgs);
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
          _addNode(
            widget: RichText(text: TextSpan(children: spans)),
          );
        }

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
