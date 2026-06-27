import 'theme_model.dart';
import 'default_theme.dart';
import 'catppuccin_theme.dart';
import 'tokyo_night_theme.dart';
import 'gruvbox_theme.dart';
import 'solarized_theme.dart';
import 'classic_themes.dart';

final Map<String, TerminalTheme> appThemes = {
  'default': defaultTheme,
  'catppuccin_latte': catppuccinLatteTheme,
  'catppuccin_frappe': catppuccinFrappeTheme,
  'catppuccin_macchiato': catppuccinMacchiatoTheme,
  'catppuccin_mocha': catppuccinMochaTheme,
  'catppuccin': catppuccinMochaTheme, // alias for backwards compatibility
  'tokyo_night_storm': tokyoNightStormTheme,
  'tokyo_night_night': tokyoNightNightTheme,
  'tokyo_night_day': tokyoNightDayTheme,
  'gruvbox_dark': gruvboxDarkTheme,
  'gruvbox_light': gruvboxLightTheme,
  'solarized_dark': solarizedDarkTheme,
  'solarized_light': solarizedLightTheme,
  'dracula': draculaTheme,
  'one_dark': oneDarkTheme,
  'nord': nordTheme,
};
