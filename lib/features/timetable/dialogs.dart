import 'package:flutter/cupertino.dart';
import '../../ui/kit/kit.dart';
import 'diff.dart';
import 'model.dart';

String dateLabel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String timestampLabel(DateTime d) =>
    '${dateLabel(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

Future<T?> chooseTimetableItem<T>(
  BuildContext context,
  String title,
  List<({String label, T value})> items,
) => showCupertinoModalPopup<T>(
  context: context,
  builder: (c) => CupertinoActionSheet(
    title: Text(title),
    actions: [
      for (final item in items)
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(c, item.value),
          child: Text(item.label),
        ),
    ],
    cancelButton: CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(c),
      child: const Text('取消'),
    ),
  ),
);

Future<(DateTime, int)?> editTermSettings(
  BuildContext context, {
  DateTime? monday,
  required int weeks,
  required int minimumWeeks,
}) => showCupertinoDialog<(DateTime, int)>(
  context: context,
  builder: (_) => _TermSettingsDialog(
    monday: monday,
    weeks: weeks,
    minimumWeeks: minimumWeeks,
  ),
);

class _TermSettingsDialog extends StatefulWidget {
  const _TermSettingsDialog({
    this.monday,
    required this.weeks,
    required this.minimumWeeks,
  });
  final DateTime? monday;
  final int weeks, minimumWeeks;
  @override
  State<_TermSettingsDialog> createState() => _TermSettingsDialogState();
}

class _TermSettingsDialogState extends State<_TermSettingsDialog> {
  late final date = TextEditingController(
    text: widget.monday == null ? '' : dateLabel(widget.monday!),
  );
  late final weeks = TextEditingController(text: '${widget.weeks}');
  String? error;
  @override
  void dispose() {
    date.dispose();
    weeks.dispose();
    super.dispose();
  }

  void submit() {
    final raw = date.text.trim();
    final d = DateTime.tryParse(raw);
    final n = int.tryParse(weeks.text.trim());
    if (d == null ||
        dateLabel(d) != raw ||
        d.weekday != DateTime.monday ||
        n == null ||
        n < widget.minimumWeeks ||
        n > 60) {
      setState(
        () => error = '日期须为周一（YYYY-MM-DD），总周数须为 ${widget.minimumWeeks}–60',
      );
      return;
    }
    Navigator.pop(context, (d, n));
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: const Text('学期设置'),
    content: Column(
      children: [
        const SizedBox(height: 12),
        const Text('第 1 周的周一日期'),
        CupertinoTextField(
          controller: date,
          placeholder: 'YYYY-MM-DD',
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: 12),
        const Text('学期总周数'),
        CupertinoTextField(
          controller: weeks,
          keyboardType: TextInputType.number,
        ),
        if (error != null)
          Text(
            error!,
            style: const TextStyle(color: CupertinoColors.systemRed),
          ),
      ],
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      CupertinoDialogAction(onPressed: submit, child: const Text('确定')),
    ],
  );
}

Future<void> showTimetableMessage(
  BuildContext context,
  String title,
  String text,
) => showCupertinoDialog<void>(
  context: context,
  builder: (c) => CupertinoAlertDialog(
    title: Text(
      title,
      style: AppText.title.copyWith(color: AppTokens.of(c).labelPrimary),
    ),
    content: Padding(
      padding: const EdgeInsets.only(top: AppTokens.space2),
      child: Text(
        text,
        style: AppText.subhead.copyWith(color: AppTokens.of(c).labelPrimary),
      ),
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(c),
        child: Text(
          '知道了',
          style: AppText.body.copyWith(color: AppTokens.of(c).accent),
        ),
      ),
    ],
  ),
);

Future<void> showSessionDetails(
  BuildContext context,
  ClassSession s,
  TimetableTerm term,
) => showTimetableMessage(
  context,
  s.name,
  [
    '${dateLabel(term.dateFor(s.week, s.day))} · ${s.when}',
    '${periodTime(s.start)}–${periodTime(s.end, end: true)}',
    if (s.type.isNotEmpty) '教学类型：${s.type}',
    '教师：${s.teacher.isEmpty ? '未提供' : s.teacher}',
    '地点：${s.location.isEmpty ? '未提供' : s.location}',
    if (s.group.isNotEmpty) '教学班：${s.group}',
    if (s.adjusted) '平台调课标记：有',
    '原始标题：${s.rawTitle}',
    if (s.rawTime.isNotEmpty) '原始节次/周次：${s.rawTime}',
  ].join('\n'),
);

class TimetableDiffPage extends StatelessWidget {
  const TimetableDiffPage({
    super.key,
    required this.changes,
    required this.subtitle,
    this.confirm = false,
  });
  final List<SessionChange> changes;
  final String subtitle;
  final bool confirm;
  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final groups = _groupChanges(changes);
    final added = changes.where((c) => c.before == null).length;
    final removed = changes.where((c) => c.after == null).length;
    final modified = changes.length - added - removed;
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: const Text('课表差异'),
        leading: AppGlassIconButton(
          icon: CupertinoIcons.back,
          onTap: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: changes.isEmpty
                  ? Center(
                      child: Text(
                        '课表无变化',
                        style: AppText.body.copyWith(
                          color: tokens.labelSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: groups.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTokens.space3),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _DiffOverview(
                            subtitle: subtitle,
                            added: added,
                            removed: removed,
                            modified: modified,
                          );
                        }
                        return _ChangeCard(group: groups[index - 1]);
                      },
                    ),
            ),
            if (confirm)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.cardBackground,
                  border: Border(
                    top: BorderSide(color: tokens.separator, width: .5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppGlassButton(
                    label: '使用新课表',
                    expand: true,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ChangeKind { added, removed, modified }

class _ChangeGroup {
  const _ChangeGroup(this.kind, this.changes);
  final _ChangeKind kind;
  final List<SessionChange> changes;
  ClassSession get session => changes.first.after ?? changes.first.before!;
}

List<_ChangeGroup> _groupChanges(List<SessionChange> changes) {
  final buckets = <String, List<SessionChange>>{};
  final kinds = <String, _ChangeKind>{};
  for (var index = 0; index < changes.length; index++) {
    final change = changes[index];
    final kind = change.before == null
        ? _ChangeKind.added
        : change.after == null
        ? _ChangeKind.removed
        : _ChangeKind.modified;
    final session = change.after ?? change.before!;
    final key = kind == _ChangeKind.modified
        ? 'modified/$index'
        : [
            kind.name,
            session.name,
            session.type,
            session.day,
            session.start,
            session.end,
            session.teacher,
            session.location,
            session.group,
            session.adjusted,
          ].join('\u001f');
    buckets.putIfAbsent(key, () => []).add(change);
    kinds[key] = kind;
  }
  return [
    for (final entry in buckets.entries)
      _ChangeGroup(kinds[entry.key]!, entry.value),
  ];
}

class _DiffOverview extends StatelessWidget {
  const _DiffOverview({
    required this.subtitle,
    required this.added,
    required this.removed,
    required this.modified,
  });
  final String subtitle;
  final int added, removed, modified;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return AppGlassCard(
      glass: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: AppText.title.copyWith(color: tokens.labelPrimary),
          ),
          const SizedBox(height: AppTokens.space3),
          Wrap(
            spacing: AppTokens.space2,
            runSpacing: AppTokens.space2,
            children: [
              if (added > 0)
                _SummaryChip(label: '$added 新增', color: tokens.success),
              if (removed > 0)
                _SummaryChip(label: '$removed 取消', color: tokens.danger),
              if (modified > 0)
                _SummaryChip(label: '$modified 调整', color: tokens.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withAlpha(24),
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
    ),
    child: Text(
      label,
      style: AppText.footnote.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.group});
  final _ChangeGroup group;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final color = switch (group.kind) {
      _ChangeKind.added => tokens.success,
      _ChangeKind.removed => tokens.danger,
      _ChangeKind.modified => tokens.accent,
    };
    final label = switch (group.kind) {
      _ChangeKind.added => '新增',
      _ChangeKind.removed => '取消',
      _ChangeKind.modified => '调整',
    };
    final session = group.session;
    return AppGlassCard(
      glass: false,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppTokens.radiusCard),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SummaryChip(label: label, color: color),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: Text(
                            session.name,
                            style: AppText.title.copyWith(
                              color: tokens.labelPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space2),
                    if (group.kind == _ChangeKind.modified)
                      _ModifiedFields(change: group.changes.single)
                    else ...[
                      Text(
                        '${_weekLabel(group.changes.map((c) => (c.after ?? c.before!).week))}'
                        ' · 周${'一二三四五六日'[session.day - 1]}'
                        ' · ${session.start}–${session.end} 节',
                        style: AppText.subhead.copyWith(
                          color: tokens.labelSecondary,
                        ),
                      ),
                      if (_sessionDetails(session).isNotEmpty) ...[
                        const SizedBox(height: AppTokens.space1),
                        Text(
                          _sessionDetails(session),
                          style: AppText.footnote.copyWith(
                            color: tokens.labelTertiary,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _weekLabel(Iterable<int> source) {
  final weeks = source.toSet().toList()..sort();
  final ranges = <String>[];
  var start = weeks.first, end = weeks.first;
  void addRange() {
    ranges.add(start == end ? '$start' : '$start–$end');
  }

  for (final week in weeks.skip(1)) {
    if (week == end + 1) {
      end = week;
    } else {
      addRange();
      start = end = week;
    }
  }
  addRange();
  return '第 ${ranges.join('、')} 周';
}

String _sessionDetails(ClassSession session) => [
  if (session.type.isNotEmpty) session.type,
  if (session.adjusted) '调课',
  if (session.location.isNotEmpty) session.location,
  if (session.teacher.isNotEmpty) session.teacher,
].join(' · ');

class _ModifiedFields extends StatelessWidget {
  const _ModifiedFields({required this.change});
  final SessionChange change;

  @override
  Widget build(BuildContext context) {
    final before = change.before!, after = change.after!;
    final rows = <(String, String, String)>[
      if (before.slotKey != after.slotKey) ('时间', before.when, after.when),
      if (before.teacher != after.teacher)
        ('教师', before.teacher, after.teacher),
      if (before.location != after.location)
        ('地点', before.location, after.location),
      if (before.group != after.group) ('教学班', before.group, after.group),
      if (before.adjusted != after.adjusted)
        ('调课标记', before.adjusted ? '有' : '无', after.adjusted ? '有' : '无'),
    ];
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: AppTokens.space2),
          _ChangedField(
            label: rows[index].$1,
            before: rows[index].$2,
            after: rows[index].$3,
          ),
        ],
      ],
    );
  }
}

class _ChangedField extends StatelessWidget {
  const _ChangedField({
    required this.label,
    required this.before,
    required this.after,
  });
  final String label, before, after;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: AppText.caption.copyWith(color: tokens.labelTertiary),
          ),
        ),
        Expanded(
          child: Text(
            '${before.isEmpty ? '未提供' : before}  →  ${after.isEmpty ? '未提供' : after}',
            style: AppText.subhead.copyWith(color: tokens.labelSecondary),
          ),
        ),
      ],
    );
  }
}
