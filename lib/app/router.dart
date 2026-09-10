import 'package:flutter/cupertino.dart';

import 'package:zfjw_toolkit/features/gpa/gpa_home_page.dart';
import 'package:zfjw_toolkit/features/settings/settings_home_page.dart';

/// 底部导航 tab 定义 —— 路由清单集中在 [app]。
///
/// 每个 feature 暴露自己的首页工厂，新功能只需在此追加一条 [AppTab] 即可接入
/// 底部导航，零侵入其它目录（符合 feature-first 布局）。
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
  final WidgetBuilder page;
}

/// 应用全部底部导航 tab（当前：成绩、设置）。
final List<AppTab> appTabs = [
  AppTab(
    id: 'gpa',
    label: '成绩',
    icon: CupertinoIcons.chart_bar,
    selectedIcon: CupertinoIcons.chart_bar_fill,
    page: (_) => const GpaHomePage(),
  ),
  AppTab(
    id: 'settings',
    label: '设置',
    icon: CupertinoIcons.settings,
    selectedIcon: CupertinoIcons.settings_solid,
    page: (_) => const SettingsHomePage(),
  ),
];
