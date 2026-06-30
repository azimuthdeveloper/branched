import 'package:flutter/material.dart';

class FurcateTheme {
  // Dark Palette
  static const Color darkBgPrimary = Color(0xFF1E1E1E);
  static const Color darkBgSecondary = Color(0xFF252526);
  static const Color darkBgSidebar = Color(0xFF1B1B1B);
  static const Color darkBgTitlebar = Color(0xFF323233);
  static const Color darkBgToolbar = Color(0xFF2D2D2D);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkAccent = Color(0xFF0078D4);
  static const Color darkSelection = Color(0xFF094771);
  static const Color darkTextPrimary = Color(0xFFCCCCCC);
  static const Color darkTextSecondary = Color(0xFF858585);
  static const Color darkTextEmphasis = Color(0xFFFFFFFF);

  // Diff colors
  static const Color diffAddBg = Color(0xFF1E3A1E);
  static const Color diffAddText = Color(0xFF4EC94E);
  static const Color diffDelBg = Color(0xFF3A1E1E);
  static const Color diffDelText = Color(0xFFF14C4C);
  static const Color diffHunkBg = Color(0xFF1E1E3A);

  // Graph Lane Colors (rotating)
  static const List<Color> laneColors = [
    Color(0xFF4EC9B0), // teal
    Color(0xFF569CD6), // blue
    Color(0xFFC586C0), // purple
    Color(0xFFCE9178), // orange
    Color(0xFFDCDCAA), // yellow
    Color(0xFFD16969), // red
    Color(0xFF4FC1FF), // cyan
    Color(0xFFC8C864), // lime
    Color(0xFFD7BA7D), // gold
    Color(0xFFB5CEA8), // green
  ];

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: darkBgPrimary,
      cardColor: darkBgSecondary,
      dividerColor: darkBorder,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: darkAccent,
        secondary: darkSelection,
        background: darkBgPrimary,
        surface: darkBgSecondary,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: darkAccent,
        selectionColor: darkSelection,
      ),
    );
  }
}
