import 'package:flutter/material.dart';

/// GNOME Adwaita-inspired theme colors matching the original web app CSS.
class AdwColors {
  // --- Dark Mode ---
  static const Color window = Color(0xFF242424);
  static const Color view = Color(0xFF2D2D2D);
  static const Color card = Color(0xFF383838);
  static const Color popover = Color(0xFF383838);
  static const Color dialog = Color(0xFF3D3D3D);

  static const Color border = Color(0xFF1E1E1E);
  static const Color shade = Color(0x33000000);
  static const Color shadow = Color(0x1A000000);

  static const Color blue = Color(0xFF3584E4);
  static const Color green = Color(0xFF2EC27E);
  static const Color yellow = Color(0xFFF5C211);
  static const Color orange = Color(0xFFF99B1D);
  static const Color red = Color(0xFFE01B24);
  static const Color purple = Color(0xFF9141AC);
  static const Color brown = Color(0xFFCDAB8F);
  static const Color pink = Color(0xFFFF669B);
  static const Color gray = Color(0xFF8B8E8F);

  static const Color fg = Color(0xFFFFFFFF);
  static const Color fgDim = Color(0xFFA8A8A8);
  static const Color fgSecondary = Color(0xFFA8A8A8);
  static const Color accent = Color(0xFF3584E4);
  static const Color accentDim = Color(0xFF2A68B2);
  static const Color destructive = Color(0xFFE01B24);

  static const Color header = Color(0xFF2D2D2D);
  static const Color sidebar = Color(0xFF1E1E1E);
  static const Color selected = Color(0x1AFFFFFF);
  static const Color hover = Color(0x12FFFFFF);
  static const Color active = Color(0x26FFFFFF);

  // Login page background
  static const Color loginBg = Color(0xFF333333);
}

/// Border radii matching the original CSS.
class AdwRadius {
  static const double normal = 8.0;   // 改为 8.0，更接近 GNOME 风格
  static const double sm = 6.0;
  static const double lg = 12.0;
  static const double pill = 999.0;   // 保留用于特殊按钮
}

/// Build the dark Material ThemeData that mimics Gnome/Adwaita style.
ThemeData buildAdwaitaDarkTheme() {
  // 定义文本样式，使用 HarmonyOS Sans 字体
  const textTheme = TextTheme(
    displayLarge: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 57, fontWeight: FontWeight.bold, color: AdwColors.fg),
    displayMedium: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 45, fontWeight: FontWeight.bold, color: AdwColors.fg),
    displaySmall: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 36, fontWeight: FontWeight.bold, color: AdwColors.fg),
    headlineLarge: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 32, fontWeight: FontWeight.w600, color: AdwColors.fg),
    headlineMedium: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 28, fontWeight: FontWeight.w600, color: AdwColors.fg),
    headlineSmall: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 24, fontWeight: FontWeight.w600, color: AdwColors.fg),
    titleLarge: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 20, fontWeight: FontWeight.w600, color: AdwColors.fg),
    titleMedium: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 18, fontWeight: FontWeight.w500, color: AdwColors.fg),
    titleSmall: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 16, fontWeight: FontWeight.w500, color: AdwColors.fg),
    bodyLarge: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 16, fontWeight: FontWeight.normal, color: AdwColors.fg),
    bodyMedium: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 14, fontWeight: FontWeight.normal, color: AdwColors.fg),
    bodySmall: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 12, fontWeight: FontWeight.normal, color: AdwColors.fgDim),
    labelLarge: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 14, fontWeight: FontWeight.w500, color: AdwColors.fg),
    labelMedium: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 12, fontWeight: FontWeight.w500, color: AdwColors.fg),
    labelSmall: TextStyle(fontFamily: 'HarmonyOSSans', fontSize: 11, fontWeight: FontWeight.w500, color: AdwColors.fgDim),
  );

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AdwColors.window,
    canvasColor: AdwColors.view,
    cardColor: AdwColors.card,
    dialogTheme: const DialogThemeData(
      backgroundColor: AdwColors.dialog,
    ),
    dividerColor: AdwColors.border,
    primaryColor: AdwColors.accent,
    fontFamily: 'HarmonyOSSans',
    colorScheme: const ColorScheme.dark(
      primary: AdwColors.accent,
      secondary: AdwColors.accentDim,
      surface: AdwColors.view,
      error: AdwColors.destructive,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AdwColors.fg,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AdwColors.header,
      foregroundColor: AdwColors.fg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AdwColors.sidebar,
      selectedIconTheme: IconThemeData(color: AdwColors.accent, size: 24),
      unselectedIconTheme: IconThemeData(color: AdwColors.fgDim, size: 24),
      indicatorColor: AdwColors.selected,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AdwColors.header,
      selectedItemColor: AdwColors.accent,
      unselectedItemColor: AdwColors.fgDim,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdwColors.view,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdwRadius.normal),
        borderSide: const BorderSide(color: AdwColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdwRadius.normal),
        borderSide: const BorderSide(color: AdwColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdwRadius.normal),
        borderSide: const BorderSide(color: AdwColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdwRadius.normal),
        borderSide: const BorderSide(color: AdwColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdwRadius.normal),
        borderSide: const BorderSide(color: AdwColors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: AdwColors.fgDim),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AdwColors.view,
        foregroundColor: AdwColors.fg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdwRadius.sm),
          side: const BorderSide(color: AdwColors.border),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AdwColors.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdwRadius.sm),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdwRadius.sm),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AdwColors.accent,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AdwColors.fg,
      unselectedLabelColor: AdwColors.fgDim,
      indicatorColor: AdwColors.accent,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AdwColors.fg,
      iconColor: AdwColors.fgDim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AdwRadius.sm)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AdwColors.popover,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdwRadius.sm),
        side: const BorderSide(color: AdwColors.border),
      ),
    ),
    textTheme: textTheme,
  );
}