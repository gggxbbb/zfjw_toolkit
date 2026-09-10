import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/app/router.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 应用主壳：玻璃脚手架 + 顶部玻璃栏 + 底部玻璃标签栏。
///
/// **布局模型（iOS 26 / App Store 式）**：
/// - 骨架 `extendBody: true`——页面内容从顶/底玻璃栏下方穿过，玻璃因内容
///   衬托而通透（这是底栏"只有一半透明"的解药）。
/// - 页面标题**嵌在滚动内容里**（[AppGlassLargeTitle] 作为首个 sliver），
///   向上滚动时平滑收起，顶部玻璃栏的小标题同步淡入。
/// - 留白由页面用 [AppPagePadding] 自算（骨架不做隐式 padding）。
///
/// 每个 tab 持有独立的 [GlassLargeTitleController]：切换 tab 时滚动位置与
/// 折叠状态互不串扰。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  var _index = 0;

  /// 每个 tab 一份大标题控制器（含各自的 ScrollController）。
  late final List<GlassLargeTitleController> _titleControllers = [
    for (var i = 0; i < appTabs.length; i++) GlassLargeTitleController(),
  ];

  @override
  void dispose() {
    for (final c in _titleControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = appTabs[_index];
    final titleController = _titleControllers[_index];
    final tokens = AppTokens.of(context);

    // 根级 DefaultTextStyle：兜住所有未被显式指定样式的 Text。
    // Flutter 在字体回退链上，若 TextStyle 未声明 decoration 语义，会为
    // 回退字形画"黄色下划线"告警——这就是全屏文字黄色下划线的来源。
    // 骨架内所有子组件（含 Material/玻璃库内部 Text）都从这里继承
    // decoration: none，从而彻底消除该告警。
    return DefaultTextStyle(
      style: AppText.body.copyWith(color: tokens.labelPrimary),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: AppGlassScaffold(
          // 顶部栏：小标题常显，与大标题做折叠联动。
          // 显式指定颜色——玻璃库默认的 Cupertino navTitleTextStyle 在本工程的
          // 无色 textTheme 下暗色解析不可靠（会渲染成暗色字）。
          appBar: AppGlassAppBar(
            title: Text(
              tab.label,
              style: AppText.title.copyWith(color: tokens.labelPrimary),
            ),
            largeTitleController: titleController,
          ),
          // 键盘打开时仍固定在屏幕底部，不随 viewInsets 上移。
          bottomBar: AppGlassTabBar(
            tabs: [
              for (final t in appTabs)
                GlassTab(
                  icon: Icon(t.icon),
                  activeIcon:
                      t.selectedIcon == null ? null : Icon(t.selectedIcon),
                  label: t.label,
                ),
            ],
            selectedIndex: _index,
            onTabSelected: (i) => setState(() => _index = i),
          ),
          // 页面接收标题滚动控制器以装配 Large Title。
          body: tab.page(context, titleController),
        ),
      ),
    );
  }
}
