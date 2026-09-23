import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
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
    title: Text(title),
    content: Text(text),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(c),
        child: const Text('知道了'),
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
  Widget build(BuildContext context) => AppGlassScaffold(
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
          Padding(padding: const EdgeInsets.all(16), child: Text(subtitle)),
          Expanded(
            child: changes.isEmpty
                ? const Center(child: Text('课表无变化'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: changes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTokens.of(context).accentSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(changes[i].description),
                    ),
                  ),
          ),
          if (confirm)
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppGlassButton(
                label: '使用新课表',
                expand: true,
                onTap: () => Navigator.pop(context, true),
              ),
            ),
        ],
      ),
    ),
  );
}
