part of 'main.dart';

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
