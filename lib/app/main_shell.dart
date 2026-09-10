import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/app/router.dart';
import 'package:zfjw_toolkit/ui/glass/glass.dart';

/// 应用主壳：持有底部 tab 选中态，装配玻璃脚手架、顶部栏与底部标签栏。
///
/// 背景为自动明暗纯色（[GlassWallpaper]）。
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
    return GlassScaffold(
      background: const GlassWallpaper(),
      appBar: GlassAppBar(title: Text(tab.label)),
      bottomBar: GlassTabBar.bottom(
        tabs: [
          for (final t in appTabs) GlassTab(icon: Icon(t.icon), label: t.label),
        ],
        selectedIndex: _index,
        onTabSelected: (i) => setState(() => _index = i),
      ),
      // 玻璃脚手架是 Cupertino 系，树内无 Material 祖先；Material 组件
      // （TextField/DropdownButton/Slider 等）需要 Material 提供墨水渲染与
      // 主题上下文，此处用透明 Material 统一为所有 feature 页兜底。
      body: Material(
        type: MaterialType.transparency,
        child: tab.page(context),
      ),
    );
  }
}
