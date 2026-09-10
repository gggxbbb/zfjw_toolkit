import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/app/router.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 应用主壳：玻璃脚手架 + 顶部栏 + 底部玻璃标签栏。
///
/// 背景为自动明暗纯色（[AppWallpaper]），衬托玻璃材质。
///
/// 页面树内不需要 Material 祖先——各 feature 页统一使用本套玻璃/Cupertino
/// 组件（`lib/ui/kit`），不依赖 Material 主题与墨水渲染。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final tab = appTabs[_index];
    final tokens = AppTokens.of(context);

    // 根级 DefaultTextStyle：兜住所有未被显式指定样式的 Text。
    // Flutter 在字体回退链上，若 TextStyle 未声明 decoration 语义，会为
    // 回退字形画"黄色下划线"告警——这就是全屏文字黄色下划线的来源。
    // 骨架内所有子组件（含 Material/玻璃库内部 Text）都从这里继承
    // decoration: none，从而彻底消除该告警。
    return DefaultTextStyle(
      style: AppText.body.copyWith(color: tokens.labelPrimary),
      child: AppGlassScaffold(
        appBar: AppGlassAppBar(title: Text(tab.label)),
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
        body: tab.page(context),
      ),
    );
  }
}
