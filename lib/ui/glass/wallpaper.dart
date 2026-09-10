import 'package:flutter/widgets.dart';

/// 自动明暗纯色背景。
///
/// 风格对齐 Apple 系统应用（App Store 等）：无调色板、无渐变，
/// 亮模式系统灰、暗模式石墨黑，跟随系统主题自动切换。
class GlassWallpaper extends StatelessWidget {
  const GlassWallpaper({super.key});

  /// 亮模式底色（系统灰）。
  static const Color light = Color(0xFFF2F2F7);

  /// 暗模式底色（石墨黑）。
  static const Color dark = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return ColoredBox(
      color: isDark ? dark : light,
      child: const SizedBox.expand(),
    );
  }
}
