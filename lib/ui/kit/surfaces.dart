import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;

import 'tokens.dart';

/// 玻璃栏的几何常量，与 [AppGlassAppBar] / [AppGlassTabBar] 的实际尺寸对齐。
///
/// 用于给页面滚动内容算上下留白，使内容能从玻璃栏下方滚过（玻璃才有东西
/// 可折射），同时首屏内容又不会顶进状态栏、末屏内容不被 tab bar 遮挡。
class AppGlassMetrics {
  AppGlassMetrics._();

  /// 顶部导航栏高度（`GlassAppBar.toolbarHeight` 默认值）。
  static const double appBarHeight = 44;

  /// 底部标签栏的**实际占位高度**。
  ///
  /// `GlassTabBar.bottom` 的 `preferredSize.height` 计算式为
  /// `barHeight + verticalPadding * 2`，默认值代入即 `64 + 20 * 2 = 104`。
  /// （`barHeight` 默认 64，`verticalPadding` 默认 20。）
  /// 注意不要误用 64——那只是药丸本体高度，会让内容底部被裁 40pt。
  static const double tabBarHeight = 104;

  /// 页面顶部的状态栏留白 + 导航栏高度。
  static double topInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + appBarHeight;

  /// 页面底部的标签栏高度 + Home Indicator 留白。
  static double bottomInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + tabBarHeight;
}

/// 应用级玻璃页面骨架：背景 + 顶部玻璃栏 + 底部玻璃栏。
///
/// **布局契约（重要）**：
/// 本骨架默认 `extendBody: true`——内容延伸穿过顶/底玻璃栏。这是 iOS 26 的
/// 正确观感：玻璃栏半透明，内容在它下方滚动时透出，折射效果才成立
/// （否则底栏只会呈现"一半透明"的死板外观）。
///
/// 代价是**页面必须自己给滚动内容加留白**（见 [AppPagePadding] /
/// [AppGlassLargeTitle]），否则首屏会顶进状态栏、末屏被 tab bar 切掉。
///
/// 页面标题**嵌在内容里**（App Store 式 Large Title），不用独立栏位：
/// 用 [AppGlassLargeTitle] 作为滚动内容的第一个 sliver，滚动时它会收起、
/// 并由顶部玻璃栏淡入小标题承接。
class AppGlassScaffold extends StatelessWidget {
  const AppGlassScaffold({
    super.key,
    required this.body,
    this.background,
    this.appBar,
    this.bottomBar,
    this.statusBarStyle = lg.GlassStatusBarStyle.auto,
    this.edgeFade = true,
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

  /// 滚动至栏位边缘时的内容渐隐（iOS 26 `.scrollEdgeEffectStyle(.soft)`）。
  final bool edgeFade;

  /// 内容是否延伸穿过栏位。
  ///
  /// 默认 `true`：内容滚过玻璃栏下方，玻璃材质因内容衬托而通透自然。
  /// 页面需自行提供滚动留白。设 `false` 时内容被夹在两栏之间（无玻璃折射
  /// 效果，仅在极少数不希望内容透出的场景使用）。
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

/// 页面滚动内容的上下留白：让内容从玻璃栏下方滚过。
///
/// 用法（配合 `AppGlassScaffold(extendBody: true)`）：
/// ```dart
/// CustomScrollView(
///   controller: controller,
///   slivers: [
///     AppGlassLargeTitle(text: '成绩', controller: controller),
///     SliverPadding(
///       padding: AppPagePadding.bottom(context),
///       sliver: SliverList(...),
///     ),
///   ],
/// )
/// ```
class AppPagePadding {
  AppPagePadding._();

  /// 顶部留白：状态栏 + 导航栏。
  ///
  /// 使用 [AppGlassLargeTitle] 时**不需要**它——Large Title 自身已占据
  /// 顶部空间并随滚动收起。
  static EdgeInsets top(BuildContext context) => EdgeInsets.only(
        top: AppGlassMetrics.topInset(context),
      );

  /// 顶部留白 + 页面左右内边距。
  static EdgeInsets topWithHorizontal(BuildContext context) => EdgeInsets.only(
        top: AppGlassMetrics.topInset(context),
        left: AppTokens.pagePadding,
        right: AppTokens.pagePadding,
      );

  /// 底部留白：标签栏 + Home Indicator。
  ///
  /// 用作滚动内容最后的 padding，保证末屏内容完整露出、不被 tab bar 覆盖。
  static EdgeInsets bottom(BuildContext context) => EdgeInsets.only(
        bottom: AppGlassMetrics.bottomInset(context),
      );

  /// 底部留白 + 页面左右内边距。
  static EdgeInsets bottomWithHorizontal(BuildContext context) =>
      EdgeInsets.only(
        bottom: AppGlassMetrics.bottomInset(context),
        left: AppTokens.pagePadding,
        right: AppTokens.pagePadding,
      );

  /// 页面主体的完整内边距（左右 + 底部），配合 Large Title 使用。
  static EdgeInsets body(BuildContext context) => EdgeInsets.only(
        left: AppTokens.pagePadding,
        right: AppTokens.pagePadding,
        bottom: AppGlassMetrics.bottomInset(context),
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
///
/// 配合 [AppGlassLargeTitle] 使用时，把同一个 [largeTitleController] 传进来：
/// 滚动时页面内的大标题淡出、顶部栏的小标题淡入（App Store 式）。
///
/// **霜冻背景**：底层 [lg.GlassAppBar] 本身只是透明 `ColoredBox`（无模糊），
/// 收起后小标题会直接叠在滚过的内容上。本封装在外层套
/// `BackdropFilter` 模糊 + 半透明 tint，随 [lg.GlassLargeTitleController.
/// collapseProgress] 从零渐入——大标题展开时全透明，收起后完全霜冻
/// （对齐 UINavigationBar 的 material 行为）。无折叠联动时（[frosted] 默认
/// true）常显全量霜冻。
class AppGlassAppBar extends StatelessWidget {
  const AppGlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.largeTitleController,
    this.frosted = true,
  });

  /// 标题（折叠后显示的小标题）。
  final Widget? title;

  /// 标题前控件（通常为返回按钮）。
  final Widget? leading;

  /// 标题后控件列表。
  final List<Widget>? actions;

  /// 标题是否居中。
  final bool centerTitle;

  /// 大标题折叠控制器；传 null 时顶部栏标题常显（无折叠联动）。
  final lg.GlassLargeTitleController? largeTitleController;

  /// 是否启用霜冻背景。
  ///
  /// 有折叠联动时随进度渐入；无联动时常显全量。设 false 则与库默认一致
  /// （全透明——仅当背景本身已足够实色、无需毛玻璃时使用）。
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final bar = lg.GlassAppBar(
      title: title,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      largeTitleController: largeTitleController,
    );

    if (!frosted) return bar;

    // 无折叠联动（如采集页）：常显全量霜冻。
    final controller = largeTitleController;
    if (controller == null) {
      return _AppBarFrost(tokens: tokens, strength: 1, child: bar);
    }

    // 随折叠进度渐入霜冻。
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => _AppBarFrost(
        tokens: tokens,
        strength: controller.collapseProgress,
        child: child!,
      ),
      child: bar,
    );
  }
}

/// 霜冻背景层：`BackdropFilter` 模糊 + 半透明画布色 tint。
///
/// [strength] 为 0 时完全透明（且不产生 BackdropFilter 渲染开销）；
/// 1 时为全量霜冻。背景覆盖整个栏位（含状态栏区域），与库内部
/// `ColoredBox + SafeArea` 的布局一致。
class _AppBarFrost extends StatelessWidget {
  const _AppBarFrost({
    required this.tokens,
    required this.strength,
    required this.child,
  });

  final AppTokens tokens;
  final double strength;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = Curves.easeOut.transform(strength.clamp(0.0, 1.0));
    if (s <= 0) return child;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20 * s, sigmaY: 20 * s),
        child: ColoredBox(
          color: tokens.canvas.withAlpha((0.72 * s * 255).round()),
          child: child,
        ),
      ),
    );
  }
}

/// 页面内嵌的大标题（iOS 26 / App Store 式 Large Title）。
///
/// 作为 `CustomScrollView.slivers` 的**第一个 sliver** 使用。它自带
/// 顶部留白（状态栏 + 导航栏），用户向上滚动时平滑收起；同时驱动
/// [AppGlassAppBar] 的小标题淡入。
///
/// **为什么自带 spacer**：[lg.GlassLargeTitle] 本身只是内容 sliver，不含安全区；
/// 而 [lg.GlassScaffold] 在 `extendBody: true` 下把 body 原样 `Positioned.fill`，
/// **不做任何自动 padding**（库文档声称会自动处理，但源码无此实现）。因此这里
/// 补一个 [SliverToBoxAdapter] 顶部 spacer，高度 = 状态栏 + 导航栏。
class AppGlassLargeTitle extends StatelessWidget {
  const AppGlassLargeTitle({
    super.key,
    required this.text,
    required this.controller,
    this.trailing,
    this.searchBar,
  });

  /// 标题文本（应与传给 [AppGlassAppBar.title] 的文案一致）。
  final String text;

  /// 折叠控制器；同时用于驱动顶部栏小标题。
  final lg.GlassLargeTitleController controller;

  /// 标题右侧控件（头像、操作按钮等）。
  final Widget? trailing;

  /// 标题下方可选搜索栏（iOS 26 二段式折叠的第二段）。
  final Widget? searchBar;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        // 顶部 spacer：让 Large Title 从顶部玻璃栏下方开始（骨架不做此事）。
        SliverToBoxAdapter(
          child: SizedBox(height: AppGlassMetrics.topInset(context)),
        ),
        lg.GlassLargeTitle(
          text: text,
          controller: controller,
          trailing: trailing,
          searchBar: searchBar,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppTokens.pagePadding,
            0,
            AppTokens.pagePadding,
            AppTokens.space3,
          ),
        ),
      ],
    );
  }
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
