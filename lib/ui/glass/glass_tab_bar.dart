import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;

/// 底部玻璃标签栏薄封装。
///
/// 当前仅暴露 `.bottom` 工厂（iOS 26 风格浮动玻璃药丸），对应 App 壳的双 tab
/// 导航。业务代码用 [lg.GlassTab] 描述每个 tab（图标 + 中文标签）。
///
/// textStyle 显式去掉文本装饰：玻璃层渲染路径上 DefaultTextStyle 可能缺失
/// （debug 下表现为黄色下划线），显式 decoration 防止回退样式泄漏。
class GlassTabBar extends StatelessWidget {
  const GlassTabBar.bottom({
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
        textStyle: const TextStyle(decoration: TextDecoration.none),
      );
}
