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

    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    for (var date in sortedDates) {
      spans.add(
        TextSpan(
          text: '\n$date\n',
          style: TextStyle(color: core.theme.textMain, letterSpacing: 0.5),
        ),
      );
      for (var it in groups[date]!) {
        spans.addAll(
          formatItemLine(
            it,
            showBoards: true,
            showAge: false,
            // Check if the item is in the archive map
            isArchive: core.archive.containsKey(it.id),
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

    if (isArchive) dStyle = TextStyle(color: core.theme.dim);

    // 1. Separate the Prefix (ID + Status Icon)
    final prefixSpans = <InlineSpan>[];
    if (showId) {
      prefixSpans.add(
        TextSpan(
          text: '${item.id}.',
          style: TextStyle(color: core.theme.dim),
        ),
      );
    }
    if (showStatus) {
      prefixSpans.add(
        TextSpan(
          text: ' $prefix ',
          style: TextStyle(color: pColor),
        ),
      );
    }

    // 2. Separate the Content (Description + Tags + Metadata)
    final contentSpans = <InlineSpan>[];
    contentSpans.add(TextSpan(text: item.description, style: dStyle));

    if (item.isTask && !item.isComplete) {
      if (showPriority && item.priority >= 2) {
        contentSpans.add(
          TextSpan(
            text: ' (!)',
            style: TextStyle(color: core.theme.yellow),
          ),
        );
      }
      if (showDue && item.dueDate != null) {
        final now = DateTime.now();
        final todayStr =
            '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
        Color dueColor = _isOverdue(item.dueDate!)
            ? core.theme.red
            : (item.dueDate == todayStr ? core.theme.yellow : core.theme.dim);
        contentSpans.add(
          TextSpan(
            text: ' [due: ${item.dueDate}]',
            style: TextStyle(color: dueColor),
          ),
        );
      }
    }

    if (showAge) {
      final age = _getAge(item.timestamp);
      if (age != null)
        contentSpans.add(
          TextSpan(
            text: ' ${age}d',
            style: TextStyle(color: core.theme.dim),
          ),
        );
    }
    if (showStar && item.isStarred)
      contentSpans.add(
        TextSpan(
          text: ' ★',
          style: TextStyle(color: core.theme.yellow),
        ),
      );
    if (showTags && item.tags.isNotEmpty)
      contentSpans.add(
        TextSpan(
          text: '  ${item.tags.join(' ')}',
          style: TextStyle(color: core.theme.dim),
        ),
      );
    if (showBoards && item.boards.isNotEmpty) {
      contentSpans.add(
        TextSpan(
          text:
              '  ${item.boards.map((b) => b == 'inbox' ? '@inbox' : b).join(' ')}',
          style: TextStyle(color: core.theme.purple),
        ),
      );
    }

    // 3. Structural Setup for Hanging Indent
    final baseStyle = TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: _kMono,
      fontSize: core.fontSize,
      height: _kLineH,
    );

    // Calculate left padding based on font size to replace the hardcoded string spaces
    final indentWidth = (indent == 0 ? 2 : indent) * (core.fontSize * 0.6);

    // 4. Wrap the Row inside a WidgetSpan
    final spans = <InlineSpan>[
      WidgetSpan(
        alignment: PlaceholderAlignment.top,
        child: Padding(
          padding: EdgeInsets.only(left: indentWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(children: prefixSpans, style: baseStyle),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(children: contentSpans, style: baseStyle),
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    // ── Recursive Loop for Subtasks ──
    final children =
        pool.values
            .where((c) => c.parentId == item.id && !seen.contains(c.id))
            .toList()
          ..sort(
            (a, b) => b.id.compareTo(a.id),
          ); // Assuming you kept the descending sort fix

    for (var child in children) {
      spans.add(const TextSpan(text: '\n'));
      spans.addAll(
        formatItemLine(
          child,
          indent: indent == 0 ? 6 : indent + 4,
          parentBoards: parentBoards ?? item.boards,
          visited: seen,
          isArchive: isArchive,
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
    final sortedKeys = groups.keys.toList()..sort();
    return {for (var k in sortedKeys) k: groups[k]!};
  }

  Map<String, List<TaskItem>> _groupByDate() {
    final groups = <String, List<TaskItem>>{};

    // Combine active items and archive items
    final allItems = [...core.items.values, ...core.archive.values];

    for (var it in allItems) {
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
