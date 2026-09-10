import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/core/stats/stats_engine.dart' show simulate, semesterKeyOf;
import 'package:zfjw_toolkit/features/gpa/ui/stats_sections.dart' show fmt, statRow;
import 'package:zfjw_toolkit/ui/glass/glass.dart';

/// What-If 假设分析卡：选课 + 分数滑杆，实时重算总/学位 GPA。
///
/// 对齐油猴「假设分析」：假设分数按规则包公式重估绩点（无法取教务官方值），
/// 展示新旧对比。不落库，基于当前快照内存模拟。
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
    final key = selected.courseKey;
    final score = _score ?? selected.numericScore ?? 60;
    final result = simulate(widget.stats, key, score);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('假设分析', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: key,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            items: [
              for (final r in widget.stats.rows)
                DropdownMenuItem(
                  value: r.courseKey,
                  child: Text(
                    '${r.kcmc ?? '?'}（${semesterKeyOf(r)}）',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              _courseKey = v;
              _score = null;
            }),
          ),
          const SizedBox(height: 4),
          Slider(
            value: score.clamp(0, 100),
            min: 0,
            max: 100,
            divisions: 100,
            label: score.toStringAsFixed(0),
            onChanged: (v) => setState(() {
              _courseKey = key;
              _score = v;
            }),
          ),
          statRow('假设此科 ${score.toStringAsFixed(0)} 分', ''),
          statRow(
            '总 GPA',
            '${fmt(result.oldOverall.gpa, 2)} → ${fmt(result.newOverall.gpa, 2)}',
          ),
          statRow(
            '学位 GPA',
            '${fmt(result.oldDegree.gpa, 2)} → ${fmt(result.newDegree.gpa, 2)}',
          ),
        ],
      ),
    );
  }
}
