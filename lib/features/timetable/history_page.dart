import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/kit/kit.dart';
import 'dialogs.dart';
import 'diff.dart';
import 'model.dart';
import 'providers.dart';

class TimetableHistoryPage extends ConsumerWidget {
  const TimetableHistoryPage({super.key, required this.term});
  final TimetableTerm term;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppGlassScaffold(
    extendBody: false,
    appBar: AppGlassAppBar(
      title: const Text('历史快照'),
      leading: AppGlassIconButton(
        icon: CupertinoIcons.back,
        onTap: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: ref
          .watch(timetableHistoryProvider(term.id))
          .when(
            loading: () => const Center(child: AppGlassProgress()),
            error: (e, _) => Center(child: Text('历史读取失败：$e')),
            data: (versions) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(term.label),
                const SizedBox(height: 12),
                for (var i = 0; i < versions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${timestampLabel(versions[i].capturedAt)}${i == 0 ? ' · 当前版本' : ''}',
                        ),
                        Text('${versions[i].sessions.length} 次课'),
                        Wrap(
                          spacing: 8,
                          children: [
                            AppGlassButton(
                              label: '查看课次',
                              onTap: () => Navigator.push(
                                context,
                                CupertinoPageRoute<void>(
                                  builder: (_) => _SnapshotPage(
                                    term: term,
                                    snapshot: versions[i],
                                  ),
                                ),
                              ),
                            ),
                            if (versions.length > 1)
                              AppGlassButton(
                                label: '比较版本',
                                onTap: () async {
                                  final other = await chooseTimetableItem(
                                    context,
                                    '选择要比较的版本',
                                    [
                                      for (final v in versions)
                                        if (v.id != versions[i].id)
                                          (
                                            label: timestampLabel(v.capturedAt),
                                            value: v,
                                          ),
                                    ],
                                  );
                                  if (other == null || !context.mounted) return;
                                  final selected = versions[i];
                                  final older =
                                      selected.capturedAt.isBefore(
                                        other.capturedAt,
                                      )
                                      ? selected
                                      : other;
                                  final newer = older.id == selected.id
                                      ? other
                                      : selected;
                                  await Navigator.push(
                                    context,
                                    CupertinoPageRoute<void>(
                                      builder: (_) => TimetableDiffPage(
                                        changes: diffTimetable(
                                          older.sessions,
                                          newer.sessions,
                                        ),
                                        subtitle:
                                            '${timestampLabel(older.capturedAt)} → ${timestampLabel(newer.capturedAt)}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    ),
  );
}

class _SnapshotPage extends StatelessWidget {
  const _SnapshotPage({required this.term, required this.snapshot});
  final TimetableTerm term;
  final TimetableSnapshot snapshot;
  @override
  Widget build(BuildContext context) => AppGlassScaffold(
    extendBody: false,
    appBar: AppGlassAppBar(
      title: const Text('快照课次'),
      leading: AppGlassIconButton(
        icon: CupertinoIcons.back,
        onTap: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${term.label}\n${timestampLabel(snapshot.capturedAt)}'),
          if (snapshot.sessions.isEmpty) const Text('此版本没有课程'),
          for (final s in snapshot.sessions)
            CupertinoButton(
              onPressed: () => showSessionDetails(context, s, term),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${s.name} · ${s.type}${s.adjusted ? ' · 调课' : ''}\n${s.when}\n${s.location} · ${s.teacher}',
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
