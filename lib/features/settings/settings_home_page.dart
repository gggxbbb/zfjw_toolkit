import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zfjw_toolkit/core/stats/target_analysis.dart';
import 'package:zfjw_toolkit/features/settings/state/gpa_goals.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 设置功能域首页：目标 GPA、规则包信息、关于。
///
/// 明暗模式跟随系统自动切换（无手动调色板）。
/// 布局对齐 iOS「设置」页：内嵌大标题 + 玻璃分组卡片 + 玻璃列表行，
/// 内容从顶/底玻璃栏下方穿过。
class SettingsHomePage extends ConsumerWidget {
  const SettingsHomePage({super.key, required this.titleController});

  /// 由主壳传入的大标题折叠控制器（驱动顶部栏小标题联动）。
  final GlassLargeTitleController titleController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(gpaGoalsProvider).value ?? const GpaGoals();
    final tokens = AppTokens.of(context);

    return CustomScrollView(
      controller: titleController.scrollController,
      slivers: [
        // 页面内嵌标题（App Store 式），自带状态栏 + 导航栏留白。
        AppGlassLargeTitle(text: '设置', controller: titleController),
        SliverPadding(
          padding: AppPagePadding.body(context),
          sliver: SliverList.list(
            children: [
              // ---- 目标/最低 GPA ----
              _GpaGoalsCard(goals: goals),
              const SizedBox(height: AppTokens.space4),

              // ---- 规则包信息 ----
              AppGlassGroupedCard(
                title: '成绩计算规则',
                footer: '绩点取教务官方值，缺失按 (分数-50)/10 计算；重修与补考取历次最高分；'
                    '学位课按教务标记判定；免修不参与统计，学分单独展示。',
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_seal,
                      size: 22,
                      color: tokens.success,
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: Text(
                        '徐医规则包（xzhmu）',
                        style:
                            AppText.body.copyWith(color: tokens.labelPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space4),

              // ---- 关于 ----
              AppGlassGroupedCard(
                title: '关于',
                child: Column(
                  children: [
                    const _InfoRow(
                      icon: CupertinoIcons.app,
                      label: '应用',
                      value: '正方教务工具箱',
                    ),
                    const SizedBox(height: AppTokens.space3),
                    const _InfoRow(
                      icon: CupertinoIcons.info_circle,
                      label: '版本',
                      value: '1.0.0',
                    ),
                    const SizedBox(height: AppTokens.space3),
                    const _InfoRow(
                      icon: CupertinoIcons.person,
                      label: '作者',
                      value: 'gggxbbb',
                    ),
                    const SizedBox(height: AppTokens.space3),
                    const _InfoRow(
                      icon: CupertinoIcons.doc_text,
                      label: '开源协议',
                      value: 'MIT License',
                    ),
                    const SizedBox(height: AppTokens.space3),
                    const _LinkRow(
                      icon: CupertinoIcons.link,
                      label: 'GitHub',
                      value: 'gggxbbb/zfjw_toolkit',
                      url: 'https://github.com/gggxbbb/zfjw_toolkit',
                    ),
                    const SizedBox(height: AppTokens.space3),
                    const _LinkRow(
                      icon: CupertinoIcons.arrow_down_circle,
                      label: '获取最新版本',
                      value: 'GitHub Releases',
                      url: 'https://github.com/gggxbbb/zfjw_toolkit/releases',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 外部链接行（点击在浏览器打开）。
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String value;
  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return GestureDetector(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.labelSecondary),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Text(
              label,
              style: AppText.body.copyWith(color: tokens.labelPrimary),
            ),
          ),
          Text(
            value,
            style: AppText.subhead.copyWith(color: tokens.accent),
          ),
          const SizedBox(width: AppTokens.space2),
          Icon(CupertinoIcons.chevron_forward,
              size: 16, color: tokens.labelTertiary),
        ],
      ),
    );
  }
}

/// 键值信息行（图标 + 标签 + 值）。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: tokens.labelSecondary),
        const SizedBox(width: AppTokens.space3),
        Expanded(
          child: Text(
            label,
            style: AppText.body.copyWith(color: tokens.labelPrimary),
          ),
        ),
        Text(
          value,
          style: AppText.subhead.copyWith(color: tokens.labelSecondary),
        ),
      ],
    );
  }
}

/// 目标/最低 GPA 设置卡：全部课程与学位课分别设置。
class _GpaGoalsCard extends ConsumerStatefulWidget {
  const _GpaGoalsCard({required this.goals});

  final GpaGoals goals;

  @override
  ConsumerState<_GpaGoalsCard> createState() => _GpaGoalsCardState();
}

class _GpaGoalsCardState extends ConsumerState<_GpaGoalsCard> {
  late final TextEditingController _targetAll;
  late final TextEditingController _targetDegree;
  late final TextEditingController _minAll;
  late final TextEditingController _minDegree;

  String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _targetAll = TextEditingController(text: _fmt(widget.goals.targetAll));
    _targetDegree =
        TextEditingController(text: _fmt(widget.goals.targetDegree));
    _minAll = TextEditingController(text: _fmt(widget.goals.minAll));
    _minDegree = TextEditingController(text: _fmt(widget.goals.minDegree));
  }

  @override
  void dispose() {
    _targetAll.dispose();
    _targetDegree.dispose();
    _minAll.dispose();
    _minDegree.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) => double.tryParse(c.text.trim());

  void _save() {
    final notifier = ref.read(gpaGoalsProvider.notifier);
    notifier.setTarget(TargetScope.all, _parse(_targetAll));
    notifier.setTarget(TargetScope.degree, _parse(_targetDegree));
    notifier.setMin(TargetScope.all, _parse(_minAll));
    notifier.setMin(TargetScope.degree, _parse(_minDegree));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    Widget field(String label, TextEditingController controller,
            String placeholder) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(color: tokens.labelPrimary),
                ),
              ),
              SizedBox(
                width: 96,
                child: AppGlassTextField(
                  controller: controller,
                  placeholder: placeholder,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
        );

    return AppGlassGroupedCard(
      title: '目标与最低 GPA',
      footer: '目标 GPA 是个人期望，最低 GPA 是毕业/学位硬性要求；'
          '留空恢复默认（目标 3.0 / 最低 2.0）。'
          '设置后成绩页与目标分析页按范围分别展示差距。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field('目标 GPA（全部课程）', _targetAll, '默认 3.00'),
          field('目标 GPA（学位课）', _targetDegree, '默认 3.00'),
          const AppDivider(),
          field('最低 GPA（全部课程）', _minAll, '默认 2.00'),
          field('最低 GPA（学位课）', _minDegree, '默认 2.00'),
          const SizedBox(height: AppTokens.space3),
          AppGlassButton(
            label: '保存',
            style: AppButtonStyle.regular,
            expand: true,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}
