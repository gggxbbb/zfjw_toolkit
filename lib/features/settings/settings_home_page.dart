import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/features/settings/state/target_gpa.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 设置功能域首页：目标 GPA、规则包信息、关于。
///
/// 明暗模式跟随系统自动切换（无手动调色板）。
/// 布局对齐 iOS「设置」页：玻璃分组卡片 + 玻璃列表行。
class SettingsHomePage extends ConsumerWidget {
  const SettingsHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetGpa = ref.watch(targetGpaProvider).value;
    final tokens = AppTokens.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        AppTokens.space3,
        AppTokens.pagePadding,
        AppTokens.space6,
      ),
      children: [
        // ---- 目标 GPA ----
        _TargetGpaCard(current: targetGpa),
        const SizedBox(height: AppTokens.space4),

        // ---- 规则包信息 ----
        AppGlassGroupedCard(
          title: '成绩计算规则',
          footer: '绩点取教务官方值，缺失按 (分数-50)/10 计算；重修与补考取历次最高分；'
              '学位课按教务标记判定；免修不参与统计，学分单独展示。',
          child: Row(
            children: [
              Icon(
                Icons.rule_folder_outlined,
                size: 22,
                color: tokens.success,
              ),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: Text(
                  '徐医规则包（xzhmu）',
                  style: AppText.body.copyWith(color: tokens.labelPrimary),
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
              _InfoRow(
                icon: Icons.apps_outlined,
                label: '应用',
                value: '正方教务工具箱',
              ),
              const SizedBox(height: AppTokens.space3),
              _InfoRow(
                icon: Icons.info_outline,
                label: '版本',
                value: '1.0.0',
              ),
            ],
          ),
        ),
      ],
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

/// 目标 GPA 设置卡：玻璃输入框 + 当前值展示。
class _TargetGpaCard extends ConsumerStatefulWidget {
  const _TargetGpaCard({this.current});

  final double? current;

  @override
  ConsumerState<_TargetGpaCard> createState() => _TargetGpaCardState();
}

class _TargetGpaCardState extends ConsumerState<_TargetGpaCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.current?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String v) {
    final value = double.tryParse(v.trim());
    ref.read(targetGpaProvider.notifier).setTarget(value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return AppGlassGroupedCard(
      title: '目标 GPA',
      footer: '设置后，成绩页会显示与目标的差距，趋势图叠加目标虚线。留空可清除。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppGlassTextField(
                  controller: _controller,
                  placeholder: '如 3.50',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: _submit,
                ),
              ),
              const SizedBox(width: AppTokens.space3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.current == null
                        ? '未设置'
                        : widget.current!.toStringAsFixed(2),
                    style: AppText.title.copyWith(
                      fontSize: 22,
                      color: widget.current == null
                          ? tokens.labelTertiary
                          : tokens.accent,
                    ),
                  ),
                  if (widget.current != null)
                    Text(
                      '当前目标',
                      style: AppText.caption.copyWith(
                        color: tokens.labelSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          AppGlassButton(
            label: '保存目标',
            style: AppButtonStyle.regular,
            expand: true,
            onTap: () => _submit(_controller.text),
          ),
        ],
      ),
    );
  }
}
