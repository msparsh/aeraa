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
          color: const Color(0xFFCCCCCC),
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
          style: const TextStyle(
            color: Color(0xFFEEEEEE),
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFFEEEEEE),
            decorationStyle: TextDecorationStyle.solid,
            decorationThickness: 2,
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: '  [$doneCount/${tasks.length}]\n',
          style: const TextStyle(color: cDim),
        ),
      ]);

      for (var it in itemsList) {
        spans.addAll(formatItemLine(
          it,
          showBoards: false, // Column headers already show this info
          showAge: core.showGlobalAge, // Honors global manage profile configuration!
          showTags: core.showGlobalTags,
        ));
        spans.add(const TextSpan(text: '\n'));
      }
    }

    final footerSpans = <InlineSpan>[
      TextSpan(
        text: '${stats.percent}% of all tasks complete.\n',
        style: const TextStyle(color: cDim),
      ),
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
        style: const TextStyle(color: cYellow),
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
        spans.addAll(formatItemLine(
          it,
          showBoards: true,  // 👈 Enable board visibility here!
          showAge: false,    // Optional: Hide age because date headers handle it
        ));
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
          color: cDim,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: _kMono,
          fontSize: core.fontSize,
        ),
      );
    }

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

    final rootArchivedItems =
        core.archive.values.where((it) => it.parentId == null).toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    for (var it in rootArchivedItems) {
      spans.addAll(formatItemLine(
        it,
        isArchive: true,
        showBoards: true, // Helpful to see where an archived item originally belonged
      ));
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
    Color pColor = cBlue;
    TextStyle dStyle = const TextStyle(color: Color(0xFFDADADA));

    if (item.isTask) {
      if (item.isComplete) {
        prefix = '✓';
        pColor = cGreen;
        dStyle = const TextStyle(color: cDim);
      } else if (item.inProgress) {
        prefix = '≡';
        pColor = cYellow;
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
    ];

    // 1. 🪪 ID Element
    if (showId) {
      spans.add(
        TextSpan(
          text: '${item.id}.',
          style: const TextStyle(color: cDim),
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
          const TextSpan(
            text: ' (!)',
            style: TextStyle(color: cYellow),
          ),
        );
      }

      // 5. 📅 Due Date Element
      if (showDue && item.dueDate != null) {
        final now = DateTime.now();
        final todayStr =
            '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

        Color dueColor = cDim;
        if (_isOverdue(item.dueDate!)) {
          dueColor = cRed;
        } else if (item.dueDate == todayStr) {
          dueColor = cYellow;
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
            style: const TextStyle(color: cDim),
          ),
        );
      }
    }

    // 7. ⭐ Star Badge Element
    if (showStar && item.isStarred) {
      spans.add(
        const TextSpan(
          text: ' ★',
          style: TextStyle(color: cYellow),
        ),
      );
    }

    // 8. 🏷️ Category Tags Element
    if (showTags && item.tags.isNotEmpty) {
      spans.add(
        TextSpan(
          text: '  ${item.tags.join(' ')}',
          style: const TextStyle(color: cDim),
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
          style: const TextStyle(color: cPurple),
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
