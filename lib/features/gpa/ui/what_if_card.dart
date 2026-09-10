import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/core/stats/stats_engine.dart'
    show simulate, semesterKeyOf;
import 'package:zfjw_toolkit/features/gpa/ui/stats_sections.dart' show fmt;
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// What-If 假设分析卡：选课 + 分数滑杆，实时重算总/学位 GPA。
///
/// 对齐油猴「假设分析」：假设分数按规则包公式重估绩点（无法取教务官方值），
/// 展示新旧对比。不落库，基于当前快照内存模拟。
///
/// 控件全部走玻璃设计系统：课程选择用玻璃下拉菜单，分数用玻璃滑杆。
class WhatIfCard extends ConsumerStatefulWidget {
  const WhatIfCard({super.key, required this.stats});

  final StatsResult stats;

  @override
  ConsumerState<WhatIfCard> createState() => _WhatIfCardState();
}

class _WhatIfCardState extends ConsumerState<WhatIfCard> {
  String? _courseKey;
  double? _score;

  CourseRecord? get _selected {
    for (final r in widget.stats.rows) {
      if (r.courseKey == _courseKey) return r;
    }
    return widget.stats.rows.isEmpty ? null : widget.stats.rows.first;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stats.rows.isEmpty) return const SizedBox.shrink();

    final selected = _selected;
    if (selected == null) return const SizedBox.shrink();

    final tokens = AppTokens.of(context);
    final key = selected.courseKey;
    final score = _score ?? selected.numericScore ?? 60;
    final result = simulate(widget.stats, key, score);
    final courseLabel =
        '${selected.kcmc ?? '?'}（${semesterKeyOf(selected)}）';

    return AppGlassGroupedCard(
      title: '假设分析',
      footer: '假设分数按规则包公式重估绩点，仅供参考，不影响已保存成绩。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 课程选择（玻璃下拉）。
          _CourseSelector(
            label: courseLabel,
            courses: [
              for (final r in widget.stats.rows)
                ('${r.kcmc ?? '?'}（${semesterKeyOf(r)}）', r.courseKey),
            ],
            selectedKey: key,
            onPicked: (k) => setState(() {
              _courseKey = k;
              _score = null;
            }),
          ),
          const SizedBox(height: AppTokens.space4),

          // 分数标题行。
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '假设分数',
                style: AppText.subhead.copyWith(color: tokens.labelSecondary),
              ),
              const Spacer(),
              Text(
                score.toStringAsFixed(0),
                style: AppText.title.copyWith(
                  color: tokens.accent,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          AppGlassSlider(
            value: score.clamp(0, 100),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) => setState(() {
              _courseKey = key;
              _score = v;
            }),
          ),
          const SizedBox(height: AppTokens.space3),
          AppDivider(),
          const SizedBox(height: AppTokens.space3),

          _SimRow(
            label: '总 GPA',
            oldGpa: result.oldOverall.gpa,
            newGpa: result.newOverall.gpa,
          ),
          _SimRow(
            label: '学位 GPA',
            oldGpa: result.oldDegree.gpa,
            newGpa: result.newDegree.gpa,
          ),
        ],
      ),
    );
  }
}

/// 课程选择器：玻璃字段 + 底部 Cupertino 滚轮。
///
/// 用 [AppGlassPicker] + [showAppPicker]（均基于 Cupertino），避免 Material 的
/// `showMenu`/`PopupMenuItem` 在无 Material 祖先的玻璃骨架下崩溃。
class _CourseSelector extends StatelessWidget {
  const _CourseSelector({
    required this.label,
    required this.courses,
    required this.selectedKey,
    required this.onPicked,
  });

  /// 当前课程显示文案。
  final String label;

  /// (显示文案, 课程 key) 列表。
  final List<(String, String)> courses;

  /// 当前选中的课程 key。
  final String selectedKey;

  /// 选中回调。
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    return AppGlassPicker(
      value: label,
      placeholder: '选择课程',
      onTap: () async {
        final labels = [for (final (text, _) in courses) text];
        final currentIndex = courses
            .indexWhere((element) => element.$2 == selectedKey)
            .clamp(0, courses.isEmpty ? 0 : courses.length - 1);
        final picked = await showAppPicker(
          context,
          options: labels,
          initialIndex: currentIndex,
          title: '选择课程',
        );
        if (picked != null && picked >= 0 && picked < courses.length) {
          onPicked(courses[picked].$2);
        }
      },
    );
  }
}

/// 模拟前后对比行：旧值 → 新值，增量用绿/红着色。
class _SimRow extends StatelessWidget {
  const _SimRow({
    required this.label,
    required this.oldGpa,
    required this.newGpa,
  });

  final String label;
  final double? oldGpa;
  final double? newGpa;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final changed = oldGpa != null &&
        newGpa != null &&
        (newGpa! - oldGpa!).abs() > 0.001;
    final delta = (oldGpa != null && newGpa != null) ? newGpa! - oldGpa! : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.subhead.copyWith(color: tokens.labelSecondary),
            ),
          ),
          Text(
            fmt(oldGpa, 2),
            style: AppText.numeric.copyWith(color: tokens.labelTertiary),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space2),
            child: Icon(
              Icons.arrow_forward,
              size: 12,
              color: tokens.labelTertiary,
            ),
          ),
          Text(
            fmt(newGpa, 2),
            style: AppText.numeric.copyWith(
              color: !changed
                  ? tokens.labelPrimary
                  : (delta! > 0 ? tokens.success : tokens.danger),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
