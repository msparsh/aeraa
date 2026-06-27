part of 'main.dart';

class Renderer {
  final Core core;

  Renderer(this.core);

  Widget _buildRichText(
    List<InlineSpan> mainSpans, {
    List<InlineSpan>? footerSpans,
  }) {
    final textWidget = RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: core.fontSize,
          height: _kLineH,
          color: core.theme.textMain,
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
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: _kMono,
              fontSize: core.fontSize - 1,
              height: 1.4,
              color: core.theme.dim,
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

    bool isFirst = true;
    for (var board in groups.keys) {
      final itemsList = groups[board]!;
      if (itemsList.isEmpty) continue;

      final tasks = itemsList.where((i) => i.isTask);
      final doneCount = tasks.where((i) => i.isComplete).length;
      final boardName = board == 'inbox' ? '@inbox' : board;

      if (!isFirst) {
        spans.add(const TextSpan(text: '\n'));
      }
      isFirst = false;

      spans.addAll([
        TextSpan(
          text: boardName,
          style: TextStyle(
            color: core.theme.textMain,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: core.theme.textMain,
            decorationStyle: TextDecorationStyle.solid,
            decorationThickness: 2,
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: '  [$doneCount/${tasks.length}]\n',
          style: TextStyle(color: core.theme.dim),
        ),
      ]);

      for (var it in itemsList) {
        spans.addAll(
          formatItemLine(
            it,
            showBoards: false, // Column headers already show this info
            showAge: core
                .showGlobalAge, // Honors global manage profile configuration!
            showTags: core.showGlobalTags,
          ),
        );
        spans.add(const TextSpan(text: '\n'));
      }
    }

    final footerSpans = <InlineSpan>[
      TextSpan(
        text: '${stats.percent}% of all tasks complete.\n',
        style: TextStyle(color: core.theme.dim),
      ),
      TextSpan(
        text: '${stats.complete}',
        style: TextStyle(color: core.theme.green),
      ),
      TextSpan(
        text: ' done · ',
        style: TextStyle(color: core.theme.dim),
      ),
      TextSpan(
        text: '${stats.inProgress}',
        style: TextStyle(color: core.theme.yellow),
      ),
      TextSpan(
        text: ' started · ',
        style: TextStyle(color: core.theme.dim),
      ),
      TextSpan(
        text: '${stats.pending}',
        style: TextStyle(color: core.theme.purple),
      ),
      TextSpan(
        text: ' pending · ',
        style: TextStyle(color: core.theme.dim),
      ),
      TextSpan(
        text: '${stats.notes}',
        style: TextStyle(color: core.theme.blue),
      ),
      TextSpan(
        text: ' notes',
        style: TextStyle(color: core.theme.dim),
      ),
    ];
    return _buildRichText(spans, footerSpans: footerSpans);
  }

  Widget getTimelineView() {
    final groups = _groupByDate();
    final spans = <InlineSpan>[
      TextSpan(
        text: 'TIMELINE\n',
        style: TextStyle(
          color: core.theme.textMain,
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
          style: TextStyle(color: core.theme.dim, letterSpacing: 0.5),
        ),
      );
      for (var it in groups[date]!) {
        spans.addAll(
          formatItemLine(
            it,
            showBoards: true, // 👈 Enable board visibility here!
            showAge: false, // Optional: Hide age because date headers handle it
          ),
        );
        spans.add(const TextSpan(text: '\n'));
      }
    }
    if (spans.isNotEmpty) spans.removeLast();

    return _buildRichText(spans);
  }

  Widget getArchiveView() {
    if (core.archive.isEmpty) {
      return Text(
        'Archive is empty.',
        style: TextStyle(
          color: core.theme.dim,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: core.fontSize,
        ),
      );
    }

    final spans = <InlineSpan>[
      TextSpan(
        text: 'ARCHIVED ITEMS\n',
        style: TextStyle(
          color: core.theme.textMain,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    ];

    final rootArchivedItems =
        core.archive.values.where((it) => it.parentId == null).toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    for (var it in rootArchivedItems) {
      spans.addAll(
        formatItemLine(
          it,
          isArchive: true,
          showBoards: true,
          showStatus: false,
        ),
      );
      spans.add(const TextSpan(text: '\n'));
    }

    if (spans.isNotEmpty) spans.removeLast();

    return _buildRichText(spans);
  }

  List<InlineSpan> formatItemLine(
    TaskItem item, {
    int indent = 0,
    List<String>? parentBoards,
    Set<int>? visited,
    bool isArchive = false,
    // 👇 Contextual toggle arguments
    bool showId = true,
    bool showStatus = true,
    bool showPriority = true,
    bool showDue = true,
    bool showAge = true,
    bool showStar = true,
    bool showTags = true,
    bool showBoards = false,
  }) {
    final seen = visited ?? <int>{};
    seen.add(item.id);

    final pool = isArchive ? core.archive : core.items;

    String prefix = '•';
    Color pColor = core.theme.blue;
    TextStyle dStyle = TextStyle(color: core.theme.textMain);

    if (item.isTask) {
      if (item.isComplete) {
        prefix = '✓';
        pColor = core.theme.green;
        dStyle = TextStyle(color: core.theme.dim);
      } else if (item.inProgress) {
        prefix = '≡';
        pColor = core.theme.yellow;
      } else {
        prefix = '☐';
        pColor = core.theme.purple;
      }

      if (!item.isComplete && item.priority == 3) {
        dStyle = TextStyle(
          color: core.theme.yellow,
          decoration: TextDecoration.underline,
        );
      }
    } else {
      dStyle = TextStyle(color: core.theme.dim);
    }

    if (isArchive) {
      dStyle = TextStyle(color: core.theme.dim);
    }

    final spacing = ' ' * (indent == 0 ? 2 : indent);
    final spans = <InlineSpan>[TextSpan(text: spacing)];

    // 1. 🪪 ID Element
    if (showId) {
      spans.add(
        TextSpan(
          text: '${item.id}.',
          style: TextStyle(color: core.theme.dim),
        ),
      );
    }

    // 2. 🚦 Status Icon Prefix Element
    if (showStatus) {
      spans.add(
        TextSpan(
          text: ' $prefix ',
          style: TextStyle(color: pColor),
        ),
      );
    }

    // 3. 📝 Description Element (Always Visible)
    spans.add(TextSpan(text: item.description, style: dStyle));

    // 4. ⚠️ Priority Warning Element
    if (item.isTask && !item.isComplete) {
      if (showPriority && item.priority >= 2) {
        spans.add(
          TextSpan(
            text: ' (!)',
            style: TextStyle(color: core.theme.yellow),
          ),
        );
      }

      // 5. 📅 Due Date Element
      if (showDue && item.dueDate != null) {
        final now = DateTime.now();
        final todayStr =
            '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

        Color dueColor = core.theme.dim;
        if (_isOverdue(item.dueDate!)) {
          dueColor = core.theme.red;
        } else if (item.dueDate == todayStr) {
          dueColor = core.theme.yellow;
        }

        spans.add(
          TextSpan(
            text: ' [due: ${item.dueDate}]',
            style: TextStyle(color: dueColor),
          ),
        );
      }
    }

    // 6. ⏳ Relative Age Element
    if (showAge) {
      final age = _getAge(item.timestamp);
      if (age != null) {
        spans.add(
          TextSpan(
            text: ' ${age}d',
            style: TextStyle(color: core.theme.dim),
          ),
        );
      }
    }

    // 7. ⭐ Star Badge Element
    if (showStar && item.isStarred) {
      spans.add(
        TextSpan(
          text: ' ★',
          style: TextStyle(color: core.theme.yellow),
        ),
      );
    }

    // 8. 🏷️ Category Tags Element
    if (showTags && item.tags.isNotEmpty) {
      spans.add(
        TextSpan(
          text: '  ${item.tags.join(' ')}',
          style: TextStyle(color: core.theme.dim),
        ),
      );
    }

    // 9. 🗂️ Project Boards Workspace Element
    if (showBoards && item.boards.isNotEmpty) {
      final displayBoards = item.boards
          .map((b) => b == 'inbox' ? '@inbox' : b)
          .join(' ');
      spans.add(
        TextSpan(
          text: '  $displayBoards',
          style: TextStyle(color: core.theme.purple),
        ),
      );
    }

    // ── Recursive Loop for Subtasks ──
    final children =
        pool.values
            .where((c) => c.parentId == item.id && !seen.contains(c.id))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    for (var child in children) {
      spans.add(const TextSpan(text: '\n'));
      spans.addAll(
        formatItemLine(
          child,
          indent: indent == 0 ? 6 : indent + 4,
          parentBoards: parentBoards ?? item.boards,
          visited: seen,
          isArchive: isArchive,
          // Forwarding exact profile values down to subtasks! 🔄
          showId: showId,
          showStatus: showStatus,
          showPriority: showPriority,
          showDue: showDue,
          showAge: showAge,
          showStar: showStar,
          showTags: showTags,
          showBoards: showBoards,
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
    for (var it in core.items.values) {
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
    for (var it in core.items.values) {
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
    for (var it in core.items.values) {
      if (!it.isTask) {
        n++;
      } else if (it.isComplete) {
        c++;
      } else if (it.inProgress) {
        i++;
      } else {
        p++;
      }
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
}
