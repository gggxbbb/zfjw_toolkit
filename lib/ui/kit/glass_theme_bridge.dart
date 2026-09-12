import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;

import 'tokens.dart';

/// 把 [AppTokens] 注入玻璃库主题，统一全应用配色。
///
/// **这是"黑紫混杂"的根治点**：玻璃库默认色板含靛紫，若不给它主题，各玻璃
/// 组件会按自己的默认值着色，与业务代码的颜色打架。这里用 [AppTokens] 覆盖
/// 它的全部品牌色（primary/secondary/success/warning/danger/info），
/// 使玻璃层与内容层共享同一套语义色——全应用只有系统蓝一个强调色。
class GlassThemeBridge {
  GlassThemeBridge._();

  /// 同时携带明暗变体，由 Material 主题或系统亮度动态选择。
  static lg.GlassThemeData get adaptive => lg.GlassThemeData(
    light: _variant(AppTokens.light),
    dark: _variant(AppTokens.dark),
  );

  static lg.GlassThemeVariant _variant(AppTokens t) {
    // 玻璃发光色板：直接对齐内容层的语义色。
    final glow = lg.GlassGlowColors(
      primary: t.accent,
      secondary: t.labelSecondary,
      success: t.success,
      warning: t.warning,
      danger: t.danger,
      info: t.accent,
    );

    return lg.GlassThemeVariant(glowColors: glow);
  }
}
