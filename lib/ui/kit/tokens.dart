import 'package:flutter/widgets.dart';

/// iOS 设计令牌：一套自适应的语义色 + 排版 + 间距 + 圆角。
///
/// 这是全应用唯一的配色来源——取代 Material 3 的 `ColorScheme.fromSeed`
/// （那套会生成靛紫色板，是之前"黑紫混杂"的根源）。
///
/// 取值对齐 Apple HIG / iOS 系统 App（设置、健康、App Store）实际观感：
/// - 亮色：分组列表底 `#F2F2F7`，卡片白，主文本黑，次要文本系统灰
/// - 暗色：分组列表底 `#000000` 或 `#1C1C1E`，卡片 `#1C1C1E`，主文本白
///
/// 用法：`AppTokens.of(context).labelPrimary`。所有字段随明暗自动切换，
/// 业务代码不再出现任何硬编码颜色。
class AppTokens {
  const AppTokens._({
    required this.brightness,
    required this.canvas,
    required this.groupedBackground,
    required this.cardBackground,
    required this.cardBackgroundElevated,
    required this.separator,
    required this.labelPrimary,
    required this.labelSecondary,
    required this.labelTertiary,
    required this.labelQuaternary,
    required this.accent,
    required this.accentSubtle,
    required this.fill,
    required this.fillSecondary,
    required this.danger,
    required this.warning,
    required this.success,
    required this.glassTint,
    required this.glassStroke,
  });

  /// 当前明暗。
  final Brightness brightness;

  /// 根画布底色（最底层，全屏平铺）。
  final Color canvas;

  /// 分组列表底（iOS `systemGroupedBackground`）。
  final Color groupedBackground;

  /// 卡片底（iOS `secondarySystemGroupedBackground`）。
  final Color cardBackground;

  /// 抬升卡片底（弹层/强调卡）。
  final Color cardBackgroundElevated;

  /// 分隔线（iOS 半透明分隔，发丝线）。
  final Color separator;

  /// 一级文本（标题、主数值）。
  final Color labelPrimary;

  /// 二级文本（副标题、说明）。
  final Color labelSecondary;

  /// 三级文本（占位、脚注）。
  final Color labelTertiary;

  /// 四级文本（极弱提示）。
  final Color labelQuaternary;

  /// 强调色（iOS 系统蓝，全应用唯一强调色）。
  final Color accent;

  /// 强调色的浅底（选中态、胶囊底）。
  final Color accentSubtle;

  /// 填充色（输入框、滑块轨道底）。
  final Color fill;

  /// 次级填充（更弱的容器底）。
  final Color fillSecondary;

  /// 危险色（删除、挂科）。
  final Color danger;

  /// 警告色（疑似误输入）。
  final Color warning;

  /// 成功色（达标、通过）。
  final Color success;

  /// 玻璃材质染色（局部玻璃点缀用）。
  final Color glassTint;

  /// 玻璃材质描边。
  final Color glassStroke;

  /// 亮色令牌。
  static const AppTokens light = AppTokens._(
    brightness: Brightness.light,
    // 画布与分组底：Apple 系统灰。
    canvas: Color(0xFFF2F2F7),
    groupedBackground: Color(0xFFF2F2F7),
    cardBackground: Color(0xFFFFFFFF),
    cardBackgroundElevated: Color(0xFFFFFFFF),
    // 分隔线：iOS 发丝线（亮色下约 0.29 alpha 的黑）。
    separator: Color(0x493C3C43),
    labelPrimary: Color(0xFF000000),
    labelSecondary: Color(0x993C3C43),
    labelTertiary: Color(0x4D3C3C43),
    labelQuaternary: Color(0x2E3C3C43),
    // iOS systemBlue。
    accent: Color(0xFF007AFF),
    accentSubtle: Color(0x1A007AFF),
    fill: Color(0x1F767680),
    fillSecondary: Color(0xFFE5E5EA),
    // iOS systemRed / systemOrange / systemGreen。
    danger: Color(0xFFFF3B30),
    warning: Color(0xFFFF9500),
    success: Color(0xFF34C759),
    glassTint: Color(0xB3FFFFFF),
    glassStroke: Color(0x33FFFFFF),
  );

  /// 暗色令牌。
  static const AppTokens dark = AppTokens._(
    brightness: Brightness.dark,
    canvas: Color(0xFF000000),
    groupedBackground: Color(0xFF000000),
    cardBackground: Color(0xFF1C1C1E),
    cardBackgroundElevated: Color(0xFF2C2C2E),
    separator: Color(0x99545458),
    labelPrimary: Color(0xFFFFFFFF),
    labelSecondary: Color(0x99EBEBF5),
    labelTertiary: Color(0x4DEBEBF5),
    labelQuaternary: Color(0x2EEBEBF5),
    // iOS systemBlue（暗色版略亮）。
    accent: Color(0xFF0A84FF),
    accentSubtle: Color(0x260A84FF),
    fill: Color(0x33767680),
    fillSecondary: Color(0xFF2C2C2E),
    // iOS systemRed / systemOrange / systemGreen（暗色版）。
    danger: Color(0xFFFF453A),
    warning: Color(0xFFFF9F0A),
    success: Color(0xFF30D158),
    glassTint: Color(0x1F767680),
    glassStroke: Color(0x1FFFFFFF),
  );

  /// 按上下文取令牌（跟随系统明暗，或由上层 MediaQuery 覆写）。
  static AppTokens of(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? dark
          : light;

  /// 按明暗值直接取。
  static AppTokens resolve(Brightness b) =>
      b == Brightness.dark ? dark : light;

  /// 圆角常量（对齐 iOS）。
  static const double radiusCard = 12;
  static const double radiusControl = 10;
  static const double radiusPill = 999;

  /// 间距梯度（8pt 栅格）。
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;

  /// 页面水平内边距（iOS 分组列表标准 16）。
  static const double pagePadding = 16;
}

/// iOS 排版刻度（对齐 HIG：大标题 34 / 标题 17 / 正文 17 / 脚注 13）。
///
/// 全部使用系统默认字体族（Android 上是 Roboto + Noto CJK，iOS 上是 SF Pro），
/// 不引入自定义字体——"像系统 App"的前提就是不换字体。
///
/// **关键：所有样式都显式声明 `decoration: TextDecoration.none` 与
/// `decorationColor/decorationStyle`**。Flutter 在字体回退（fallback）链条上
/// 若遇到未显式声明装饰语义的 `TextStyle`，会用"黄色下划线"标记回退字形
/// ——这正是中文全量黄色下划线的来源。显式声明后回退渲染不再画告警线。
class AppText {
  AppText._();

  /// 统一的装饰语义：无下划线，且颜色/样式显式给出，避免回退告警。
  static const TextDecoration _noDecoration = TextDecoration.none;

  /// 超大数值（GPA 大字，对齐 Health 页指标）。
  static const TextStyle display = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    height: 1.05,
    decoration: _noDecoration,
    decorationColor: Color(0x00000000),
    decorationStyle: TextDecorationStyle.solid,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 大标题（页面主标题，iOS Large Title）。
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.15,
    decoration: _noDecoration,
    decorationColor: Color(0x00000000),
    decorationStyle: TextDecorationStyle.solid,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 标题（卡片标题、区域标题）。
  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.25,
    decoration: _noDecoration,
    decorationColor: Color(0x00000000),
    decorationStyle: TextDecorationStyle.solid,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 小标题 / section header（iOS 分组列表小写灰字）。
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.2,
    decoration: _noDecoration,
    decorationColor: Color(0x00000000),
    decorationStyle: TextDecorationStyle.solid,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 正文。
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.35,
    decoration: _noDecoration,
    decorationColor: Color(0x00000000),
    decorationStyle: TextDecorationStyle.solid,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 次级正文（列表行副标题）。
  static const TextStyle subhead = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.3,
    decoration: _noDecoration,
    decorationColor: Color(0x00000000),
    decorationStyle: TextDecorationStyle.solid,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 脚注（说明文字、统计口径）。
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    decoration: _noDecoration,
    decorationColor: Color(0x00000000),
    decorationStyle: TextDecorationStyle.solid,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 极小注释（表格注脚、时间戳）。
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
    decoration: _noDecoration,
    decorationColor: Color(0x00000000),
    decorationStyle: TextDecorationStyle.solid,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 数值（等宽数字，避免跳变）。
  static const TextStyle numeric = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    decoration: _noDecoration,
    decorationColor: Color(0x00000000),
    decorationStyle: TextDecorationStyle.solid,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 供 [AppTheme] 构造完整 `TextTheme` 用：把全部刻度一次性铺开，
  /// 保证 Material 组件继承到同一套"无黄色下划线"的样式。
  static TextTheme get textTheme => const TextTheme(
        displayLarge: display,
        displayMedium: largeTitle,
        displaySmall: title,
        headlineMedium: title,
        titleLarge: title,
        titleMedium: body,
        bodyLarge: body,
        bodyMedium: subhead,
        bodySmall: footnote,
        labelLarge: subhead,
        labelMedium: footnote,
        labelSmall: caption,
      );
}
