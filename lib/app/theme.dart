import 'package:flutter/material.dart';

import 'package:zfjw_toolkit/ui/kit/tokens.dart';

/// 应用 Material 主题。
///
/// **只做两件事**：给 Material 组件（框架级、弹窗、WebView 宿主等）一个
/// 与设计系统一致的色板，以及把 [Brightness] 暴露给玻璃层的
/// `brightnessResolver`（见 `main.dart`）。
///
/// 关键：不再用 `ColorScheme.fromSeed` 生成动态色板——那会衍生出靛紫色系，
/// 是所有"黑紫混杂"的来源。这里改为用 [AppTokens] 的语义色**显式构造**
/// [ColorScheme]，全应用只有一个强调色（iOS 系统蓝）。
class AppTheme {
  AppTheme._();

  /// 亮色主题。
  static ThemeData get light => _build(AppTokens.light);

  /// 暗色主题。
  static ThemeData get dark => _build(AppTokens.dark);

  static ThemeData _build(AppTokens t) {
    final isDark = t.brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.accent,
      onPrimary: const Color(0xFFFFFFFF),
      secondary: t.accent,
      onSecondary: const Color(0xFFFFFFFF),
      error: t.danger,
      onError: const Color(0xFFFFFFFF),
      surface: t.cardBackground,
      onSurface: t.labelPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.canvas,
      dividerColor: t.separator,
      splashFactory: NoSplash.splashFactory,
      highlightColor: const Color(0x00000000),
      fontFamily: null, // 系统默认字体（iOS 上是 SF Pro）
    );
  }
}
