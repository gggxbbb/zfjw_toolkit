import 'package:flutter/cupertino.dart';

import 'package:zfjw_toolkit/features/gpa/gpa_home_page.dart';
import 'package:zfjw_toolkit/features/settings/settings_home_page.dart';
import 'package:zfjw_toolkit/features/target/target_analysis_page.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 自适应导航 tab 定义 —— 路由清单集中在 [appTabs]。
///
/// 每个 feature 暴露自己的首页工厂，新功能只需在此追加一条 [AppTab] 即可接入
/// 自适应导航，零侵入其它目录（符合 feature-first 布局）。
class AppTab {
  const AppTab({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.page,
  });

  /// 稳定标识，用于路由/状态。
  final String id;

  /// 中文标签。
  final String label;

  /// 未选中态图标。
  final IconData icon;

  /// 选中态图标（filled 变体）。
  final IconData? selectedIcon;

  /// 首页构建器。
  ///
  /// 第二个参数是大标题折叠控制器——页面用它驱动内容里内嵌的
  /// [AppGlassLargeTitle]，并与顶部玻璃栏的小标题联动。
  final Widget Function(BuildContext context, GlassLargeTitleController title)
      page;
}

/// 应用全部导航 tab（当前：成绩、目标分析、设置）。
final List<AppTab> appTabs = [
  AppTab(
    id: 'gpa',
    label: '成绩',
    icon: CupertinoIcons.chart_bar,
    selectedIcon: CupertinoIcons.chart_bar_fill,
    page: (_, title) => GpaHomePage(titleController: title),
  ),
  AppTab(
    id: 'target',
    label: '目标分析',
    icon: CupertinoIcons.scope,
    selectedIcon: CupertinoIcons.scope,
    page: (_, title) => TargetAnalysisPage(titleController: title),
  ),
  AppTab(
    id: 'settings',
    label: '设置',
    icon: CupertinoIcons.settings,
    selectedIcon: CupertinoIcons.settings_solid,
    page: (_, title) => SettingsHomePage(titleController: title),
  ),
];
