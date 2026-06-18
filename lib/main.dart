import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:window_manager/window_manager.dart';
import 'storage.dart';

// Link the split files to this main library! 🔗
part 'terminal_screen.dart';
part 'task_item.dart';
part 'core.dart';
part 'renderer.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

// Core Colors
const cRed = Color.fromRGBO(224, 108, 117, 1);
const cPurple = Color(0xFFC678DD);
const cGreen = Color(0xFF98C379);
const cBlue = Color(0xFF61AFEF);
const cYellow = Color(0xFFE5C07B);
const cDim = Color(0xFF5C6370);
const cVeryDim = Color.fromARGB(255, 27, 27, 27);
const cBlack = Color.fromARGB(255, 0, 0, 0);

const _kBg = cBlack;
const _kSurface = cBlack;
const _kBorder = cVeryDim;
const _kPrompt = cGreen;

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Define your initial window size, position, and style
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1000, 700),
    minimumSize: Size(300, 300),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus(); // Brings the window to the front on launch
  });
  runApp(const TaskTerminal());
}

class TaskTerminal extends StatelessWidget {
  const TaskTerminal({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskTerminal',
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
