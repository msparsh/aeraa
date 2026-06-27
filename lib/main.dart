import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:window_manager/window_manager.dart';
import 'storage.dart';
import 'themes/theme_model.dart';
import 'themes/app_themes.dart';

// Link the split files to this main library! 🔗
part 'terminal_screen.dart';
part 'task_item.dart';
part 'core.dart';
part 'renderer.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────


const _kMono = [
  'JetBrains Mono',
  'Fira Code',
  'Cascadia Code',
  'Menlo',
  'Monaco',
  'Consolas',
  'Courier New',
];
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
    windowManager.setTitle("Aeraa");
    await windowManager.show();
    await windowManager.focus(); // Brings the window to the front on launch
  });
  runApp(const TaskTerminal());
}

class TaskTerminal extends StatefulWidget {
  const TaskTerminal({super.key});

  @override
  State<TaskTerminal> createState() => _TaskTerminalState();
}

class _TaskTerminalState extends State<TaskTerminal> {
  final Core app = Core();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await app.init();
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF000000),
          body: SizedBox.shrink(),
        ),
        debugShowCheckedModeBanner: false,
      );
    }
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final theme = app.theme;
        return MaterialApp(
          title: 'Aeraa',
          theme: ThemeData(
            scaffoldBackgroundColor: theme.bg,
            applyElevationOverlayColor: false,
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(theme.border),
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: theme.prompt,
              selectionHandleColor: theme.prompt,
              selectionColor: theme.prompt.withOpacity(0.3),
            ),
            textTheme: TextTheme(
              bodyMedium: TextStyle(
                color: theme.textMain,
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: _kMono,
                fontSize: app.fontSize,
                height: _kLineH,
              ),
            ),
          ),
          home: TerminalScreen(app: app),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
