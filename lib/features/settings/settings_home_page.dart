import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/features/settings/state/target_gpa.dart';
import 'package:zfjw_toolkit/ui/glass/glass.dart';

/// 设置功能域首页：目标 GPA、规则包信息。
///
/// 明暗模式跟随系统自动切换（无手动调色板）。
class SettingsHomePage extends ConsumerWidget {
  const SettingsHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetGpa = ref.watch(targetGpaProvider).value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ---- 目标 GPA ----
        _TargetGpaCard(current: targetGpa),
        const SizedBox(height: 12),
        // ---- 规则包信息 ----
        const GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('规则包',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('徐医规则包（xzhmu）', style: TextStyle(fontSize: 13)),
              SizedBox(height: 4),
              Text(
                '绩点取教务官方值，缺失按 (分数-50)/10 计算；重修/补考取历次最高分；'
                '学位课按教务标记判定；免修不参与统计。',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('目标 GPA',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '如 3.50，留空清除',
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      final value = double.tryParse(v.trim());
                      ref
                          .read(targetGpaProvider.notifier)
                          .setTarget(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.current == null
                      ? '未设置'
                      : widget.current!.toStringAsFixed(2),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      );
}
