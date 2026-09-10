import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;

import 'wallpaper.dart';

/// 应用级玻璃脚手架薄封装。
///
/// 业务代码只应 import [package:zfjw_toolkit/ui/glass/glass.dart]，不要直接
/// 依赖 `liquid_glass_widgets`。本封装统一装配背景壁纸与顶部/底部玻璃栏。
///
/// 底层 [lg.GlassScaffold] 基于 CupertinoPageScaffold，已在 [MaterialApp] 中通过
/// `LiquidGlassWidgets.wrap(brightnessResolver: Theme.maybeBrightnessOf)` 桥接明暗主题。
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.background,
    this.appBar,
    this.bottomBar,
    this.statusBarStyle = lg.GlassStatusBarStyle.auto,
    this.edgeFade = false,
  });

  /// 主内容区（脚手架自动处理安全区与边缘渐隐）。
  final Widget body;

  /// 背景层，默认回退到自动明暗纯色背景。
  final Widget? background;

  /// 顶部玻璃栏，通常为 [GlassAppBar]。
  final Widget? appBar;

  /// 底部玻璃栏，通常为 [GlassTabBar.bottom]。
  final Widget? bottomBar;

  /// 状态栏图标明暗样式（默认 auto：跟随系统明暗）。
  final lg.GlassStatusBarStyle statusBarStyle;

  /// 顶部/底部滚动边缘渐隐（默认关闭——纯内容页不需要阴影条）。
  final bool edgeFade;

  @override
  Widget build(BuildContext context) => lg.GlassScaffold(
        body: body,
        background: background ?? const GlassWallpaper(),
        appBar: appBar,
        bottomBar: bottomBar,
        statusBarStyle: statusBarStyle,
        backgroundColor: const Color(0x29000000),
        edgeFade: edgeFade,
      );
}
