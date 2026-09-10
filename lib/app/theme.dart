import 'package:flutter/material.dart';

/// 应用主题：Material 3 + iOS 26 风格靛蓝主色，支持明/暗双主题。
///
/// 标签文案（如 tab 名称、占位页）均为中文，由业务代码直接提供字符串，
/// 这里仅配置色彩与排版基线。
class AppTheme {
  AppTheme._();

  /// 主色，取 iOS 26 风格靛蓝。
  static const Color seed = Color(0xFF5E5CE6);

  /// 亮色主题。
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
      );

  /// 暗色主题。
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      );
}
