import 'package:flutter/material.dart';
import 'theme_model.dart';

const draculaTheme = TerminalTheme(
  name: 'Dracula',
  bg: Color(0xFF282A36),
  surface: Color(0xFF282A36),
  border: Color(0xFF44475A),
  prompt: Color(0xFF50FA7B),
  textMain: Color(0xFFF8F8F2),
  red: Color(0xFFFF5555),
  green: Color(0xFF50FA7B),
  yellow: Color(0xFFF1FA8C),
  blue: Color(0xFF8BE9FD),
  purple: Color(0xFFBD93F9),
  dim: Color(0xFF6272A4),
);

const oneDarkTheme = TerminalTheme(
  name: 'One Dark',
  bg: Color(0xFF282C34),
  surface: Color(0xFF282C34),
  border: Color(0xFF3E4451),
  prompt: Color(0xFF98C379),
  textMain: Color(0xFFABB2BF),
  red: Color(0xFFE06C75),
  green: Color(0xFF98C379),
  yellow: Color(0xFFE5C07B),
  blue: Color(0xFF61AFEF),
  purple: Color(0xFFC678DD),
  dim: Color(0xFF5C6370),
);

const nordTheme = TerminalTheme(
  name: 'Nord',
  bg: Color(0xFF2E3440),
  surface: Color(0xFF2E3440),
  border: Color(0xFF3B4252),
  prompt: Color(0xFFA3BE8C),
  textMain: Color(0xFFD8DEE9),
  red: Color(0xFFBF616A),
  green: Color(0xFFA3BE8C),
  yellow: Color(0xEBCB8B | 0xFF000000), // 0xEBCB8B -> Color(0xFFEBCB8B)
  blue: Color(0xFF88C0D0),
  purple: Color(0xFFB48EAD),
  dim: Color(0xFF4C566A),
);
