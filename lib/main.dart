import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'storage.dart';

// Link the split files to this main library! 🔗
part 'terminal_screen.dart';
part 'task_item.dart';
part 'core.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D0D);
const _kSurface = Color(0xFF141414);
const _kBorder = Color(0xFF1E1E1E);
const _kPrompt = Color(0xFF00FF88);
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
