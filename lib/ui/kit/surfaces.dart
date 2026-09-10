import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;

import 'tokens.dart';

/// 应用级玻璃页面骨架：背景 + 顶部玻璃栏 + 底部玻璃栏 + 安全区。
///
/// 全应用页面布局的唯一入口。底层 [lg.GlassScaffold] 已处理安全区与滚动边缘，
/// 本封装只负责：装配统一背景、统一 `edgeFade` 行为（默认关闭——纯内容页
/// 不需要顶/底莫名阴影条）。
class AppGlassScaffold extends StatelessWidget {
  const AppGlassScaffold({
    super.key,
    required this.body,
    this.background,
    this.appBar,
    this.bottomBar,
    this.statusBarStyle = lg.GlassStatusBarStyle.auto,
    this.edgeFade = false,
    this.extendBody = true,
  });

  /// 主内容区。
  final Widget body;

  /// 背景层，默认回退到自动明暗纯色背景。
  final Widget? background;

  /// 顶部玻璃栏，通常为 [AppGlassAppBar]。
  final Widget? appBar;

  /// 底部玻璃栏，通常为 [AppGlassTabBar]。
  final Widget? bottomBar;

  /// 状态栏图标明暗样式。
  final lg.GlassStatusBarStyle statusBarStyle;

  /// 顶部/底部滚动边缘渐隐（默认关闭）。
  final bool edgeFade;

  /// 内容是否延伸到栏下（玻璃需要内容衬托才有效果）。
  final bool extendBody;

  @override
  Widget build(BuildContext context) => lg.GlassScaffold(
        body: body,
        background: background ?? const AppWallpaper(),
        appBar: appBar,
        bottomBar: bottomBar,
        statusBarStyle: statusBarStyle,
        edgeFade: edgeFade,
        extendBody: extendBody,
      );
}

/// 自动明暗纯色背景。
///
/// 风格对齐 Apple 系统应用：无调色板、无渐变，亮模式系统灰、暗模式石墨黑，
/// 跟随系统主题自动切换。玻璃材质在这种干净底色上折射最自然。
class AppWallpaper extends StatelessWidget {
  const AppWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return ColoredBox(
      color: isDark ? AppTokens.dark.canvas : AppTokens.light.canvas,
      child: const SizedBox.expand(),
    );
  }
}

/// 顶部玻璃栏薄封装（iOS 26 navigation bar）。
class AppGlassAppBar extends StatelessWidget {
  const AppGlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
  });

  /// 标题。
  final Widget? title;

  /// 标题前控件（通常为返回按钮）。
  final Widget? leading;

  /// 标题后控件列表。
  final List<Widget>? actions;

  /// 标题是否居中。
  final bool centerTitle;

  @override
  Widget build(BuildContext context) => lg.GlassAppBar(
        title: title,
        leading: leading,
        actions: actions,
        centerTitle: centerTitle,
      );
}

/// 底部玻璃标签栏薄封装（iOS 26 floating glass tab bar）。
class AppGlassTabBar extends StatelessWidget {
  const AppGlassTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  /// 所有 tab 定义。
  final List<lg.GlassTab> tabs;

  /// 当前选中索引。
  final int selectedIndex;

  /// tab 切换回调。
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) => lg.GlassTabBar.bottom(
        tabs: tabs,
        selectedIndex: selectedIndex,
        onTabSelected: onTabSelected,
      );
}

/// 玻璃卡片：iOS 26 内容容器。
///
/// [glass] 为 false 时退化为不透明卡（正文密集区用它避免可读性下降——
/// iOS 26 本身也是这么分层的：浮动层玻璃，内容区不透明）。
class AppGlassCard extends StatelessWidget {
  const AppGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space4),
    this.glass = true,
    this.onTap,
  });

  /// 卡片内容。
  final Widget child;

  /// 内边距。
  final EdgeInsetsGeometry padding;

  /// 是否使用玻璃材质；false 时为不透明卡。
  final bool glass;

  /// 整卡点击。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    Widget card;
    if (glass) {
      card = lg.GlassCard(
        padding: padding,
        shape: const lg.LiquidRoundedSuperellipse(
          borderRadius: AppTokens.radiusCard,
        ),
        child: child,
      );
    } else {
      card = DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.cardBackground,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
        child: Padding(padding: padding, child: child),
      );
    }

    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}
