import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/model/teaching_plan.dart';
import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/core/stats/stats_engine.dart'
    show semesterKeyOf, simulateAll;
import 'package:zfjw_toolkit/core/stats/target_analysis.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

String _fmt(double? v, [int digits = 2]) =>
    v == null ? '—' : v.toStringAsFixed(digits);

/// 多课程假设分析：可同时修改已修课程分数、预估计划内未修课程分数，
/// 实时重算所选范围（全部课程/学位课）的 GPA 与加权平均分。
///
/// 假设分数按规则包公式重估绩点（无法取教务官方值），不落库，
/// 基于当前快照内存模拟。
class WhatIfSection extends ConsumerStatefulWidget {
  const WhatIfSection({
    super.key,
    required this.stats,
    required this.plan,
    required this.scope,
    this.targetGpa,
    this.minGpa,
  });

  final StatsResult stats;

  /// 教学计划；null 时仅支持修改已修课程，不支持预估未修课。
  final TeachingPlan? plan;

  /// 当前分析范围（全部课程/学位课），决定结果区展示哪组指标。
  final TargetScope scope;

  /// 目标 GPA；提供时在结果区展示新 GPA 与目标的差距。
  final double? targetGpa;

  /// 最低 GPA（硬性要求）；提供时在模拟结果低于它时给出警示。
  final double? minGpa;

  @override
  ConsumerState<WhatIfSection> createState() => _WhatIfSectionState();
}

class _WhatIfSectionState extends ConsumerState<WhatIfSection> {
  /// 课程键 → 假设分数（按添加顺序）。
  final Map<String, double> _scores = {};

  /// 计划内未修课程（无有效记录匹配）。
  List<PlannedCourse> get _remainingPlanCourses {
    final plan = widget.plan;
    if (plan == null) return const [];
    final takenKeys = {for (final r in widget.stats.rows) r.courseKey};
    final takenNames = {for (final r in widget.stats.rows) r.kcmc};
    return [
      for (final c in plan.courses)
        if (!takenKeys.contains(plannedCourseKey(c)) &&
            !takenNames.contains(c.name))
          c,
    ];
  }

  /// 可选课程目录：(显示文案, 课程键, 默认分数)。已修在前，计划未修在后。
  /// 学位课范围仅列学位课程——非学位课不影响学位 GPA，列出无意义。
  List<(String, String, double)> get _catalog {
    final degreeOnly = widget.scope == TargetScope.degree;
    return [
      for (final r in widget.stats.rows)
        if (!degreeOnly || widget.stats.preset.isDegreeCourse(r))
          (
            '${r.kcmc ?? '?'}（${semesterKeyOf(r)}）',
            r.courseKey,
            r.numericScore ?? 80,
          ),
      for (final c in _remainingPlanCourses)
        if (!degreeOnly || isDegreePlannedCourse(widget.stats, c))
          (
            '${c.name}（未修 · ${_fmt(c.credits, 1)}学分）',
            plannedCourseKey(c),
            80,
          ),
    ];
  }

  @override
  void didUpdateWidget(WhatIfSection old) {
    super.didUpdateWidget(old);
    // 范围切换后剔除不在目录内的课程（如学位课范围下的非学位课）。
    if (old.scope != widget.scope) {
      final valid = {for (final (_, key, _) in _catalog) key};
      _scores.removeWhere((key, _) => !valid.contains(key));
    }
  }

  String _labelOf(String key) {
    for (final (label, k, _) in _catalog) {
      if (k == key) return label;
    }
    return key;
  }

  Future<void> _addCourse() async {
    final options = [
      for (final (label, key, _) in _catalog)
        if (!_scores.containsKey(key)) label,
    ];
    if (options.isEmpty) return;
    final picked = await showAppPicker(
      context,
      options: options,
      initialIndex: 0,
      title: '添加课程',
    );
    if (picked == null || picked < 0 || picked >= options.length) return;
    final label = options[picked];
    for (final (l, key, initial) in _catalog) {
      if (l == label && !_scores.containsKey(key)) {
        setState(() => _scores[key] = initial);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final scopeAll = widget.scope == TargetScope.all;
    final result = simulateAll(
      widget.stats,
      _scores,
      planned: widget.plan?.courses ?? const [],
    );
    final oldAgg = scopeAll ? result.oldOverall : result.oldDegree;
    final newAgg = scopeAll ? result.newOverall : result.newDegree;
    final gpaLabel = scopeAll ? '总 GPA' : '学位 GPA';
    final avgLabel = scopeAll ? '总加权平均分' : '学位加权平均分';
    final target = widget.targetGpa;
    final diff =
        (target != null && newAgg.gpa != null) ? newAgg.gpa! - target : null;
    final minGpa = widget.minGpa;
    final belowMin =
        minGpa != null && newAgg.gpa != null && newAgg.gpa! < minGpa;

    return AppGlassGroupedCard(
      title: '假设分析',
      footer: '假设分数按规则包公式重估绩点，仅供参考，不影响已保存成绩。'
          '${widget.plan == null ? '采集教学计划后可预估未修课程。' : ''}'
          '${scopeAll ? '' : '当前为学位课范围，仅列出学位课程。'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppGlassPicker(
            value: null,
            placeholder: '添加课程…',
            onTap: _addCourse,
          ),
          if (_scores.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space3),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(_scores.clear),
                child: Text(
                  '清空全部',
                  style: AppText.footnote.copyWith(color: tokens.accent),
                ),
              ),
            ),
          ],
          for (final entry in _scores.entries.toList()) ...[
            const SizedBox(height: AppTokens.space3),
            _CourseScoreRow(
              label: _labelOf(entry.key),
              score: entry.value,
              onChanged: (v) => setState(() => _scores[entry.key] = v),
              onRemove: () => setState(() => _scores.remove(entry.key)),
            ),
          ],
          if (_scores.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.space3),
              child: Text(
                '添加已修课程可修改分数，添加计划内未修课程可预估分数；'
                '可同时添加多门，下方实时查看结果。',
                style: AppText.footnote.copyWith(color: tokens.labelTertiary),
              ),
            ),
          const SizedBox(height: AppTokens.space3),
          const AppDivider(),
          const SizedBox(height: AppTokens.space3),
          _SimRow(
            label: gpaLabel,
            oldValue: oldAgg.gpa,
            newValue: newAgg.gpa,
          ),
          _SimRow(
            label: avgLabel,
            oldValue: oldAgg.weightedAvg,
            newValue: newAgg.weightedAvg,
          ),
          if (diff != null) ...[
            const SizedBox(height: AppTokens.space2),
            Text(
              diff >= 0
                  ? '模拟后超出目标 GPA ${diff.toStringAsFixed(2)}'
                  : '模拟后距目标 GPA 还差 ${(-diff).toStringAsFixed(2)}',
              style: AppText.footnote.copyWith(
                color: diff >= 0 ? tokens.success : tokens.danger,
              ),
            ),
          ],
          if (belowMin) ...[
            const SizedBox(height: AppTokens.space2),
            Text(
              '模拟后低于最低 GPA ${minGpa.toStringAsFixed(2)}（硬性要求）',
              style: AppText.footnote.copyWith(color: tokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单门课程的假设分数编辑行：名称 + 移除按钮 + 分数 + 滑杆。
class _CourseScoreRow extends StatelessWidget {
  const _CourseScoreRow({
    required this.label,
    required this.score,
    required this.onChanged,
    required this.onRemove,
  });

  final String label;
  final double score;
  final ValueChanged<double> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                CupertinoIcons.minus_circle_fill,
                size: 20,
                color: tokens.danger,
              ),
            ),
            const SizedBox(width: AppTokens.space2),
            Expanded(
              child: Text(
                label,
                style: AppText.subhead.copyWith(color: tokens.labelPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              score.toStringAsFixed(0),
              style: AppText.title.copyWith(
                color: tokens.accent,
                fontSize: 18,
              ),
            ),
          ],
        ),
        AppGlassSlider(
          value: score.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// 模拟前后对比行：旧值 → 新值，增量用绿/红着色。
class _SimRow extends StatelessWidget {
  const _SimRow({
    required this.label,
    required this.oldValue,
    required this.newValue,
  });

  final String label;
  final double? oldValue;
  final double? newValue;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final changed = oldValue != null &&
        newValue != null &&
        (newValue! - oldValue!).abs() > 0.001;
    final delta =
        (oldValue != null && newValue != null) ? newValue! - oldValue! : null;

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
            _fmt(oldValue),
            style: AppText.numeric.copyWith(color: tokens.labelTertiary),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space2),
            child: Icon(
              CupertinoIcons.chevron_forward,
              size: 12,
              color: tokens.labelTertiary,
            ),
          ),
          Text(
            _fmt(newValue),
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
