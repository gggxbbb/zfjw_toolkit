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
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: Text(
          '历史快照',
          style: AppText.title.copyWith(color: tokens.labelPrimary),
        ),
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
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.space4),
                  child: Text(
                    '历史读取失败：$e',
                    style: AppText.body.copyWith(color: tokens.danger),
                  ),
                ),
              ),
              data: (versions) => ListView.separated(
                padding: const EdgeInsets.all(AppTokens.space4),
                itemCount: versions.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTokens.space3),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          term.label,
                          style: AppText.largeTitle.copyWith(
                            color: tokens.labelPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space1),
                        Text(
                          versions.length <= 1
                              ? '当前仅保留 1 个版本'
                              : '共 ${versions.length} 个版本，可任选两个比较变化',
                          style: AppText.subhead.copyWith(
                            color: tokens.labelSecondary,
                          ),
                        ),
                      ],
                    );
                  }
                  final versionIndex = index - 1;
                  final version = versions[versionIndex];
                  return AppGlassCard(
                    glass: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                timestampLabel(version.capturedAt),
                                style: AppText.title.copyWith(
                                  color: tokens.labelPrimary,
                                ),
                              ),
                            ),
                            if (versionIndex == 0)
                              _CurrentVersionBadge(tokens: tokens),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space1),
                        Text(
                          '${version.sessions.length} 次课',
                          style: AppText.subhead.copyWith(
                            color: tokens.labelSecondary,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space3),
                        Wrap(
                          spacing: AppTokens.space2,
                          runSpacing: AppTokens.space2,
                          children: [
                            AppGlassButton(
                              label: '查看课次',
                              onTap: () => Navigator.push(
                                context,
                                CupertinoPageRoute<void>(
                                  builder: (_) => _SnapshotPage(
                                    term: term,
                                    snapshot: version,
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
                                        if (v.id != version.id)
                                          (
                                            label: timestampLabel(v.capturedAt),
                                            value: v,
                                          ),
                                    ],
                                  );
                                  if (other == null || !context.mounted) return;
                                  final selected = version;
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
                  );
                },
              ),
            ),
      ),
    );
  }
}

class _CurrentVersionBadge extends StatelessWidget {
  const _CurrentVersionBadge({required this.tokens});
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: tokens.accentSubtle,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
    ),
    child: Text(
      '当前版本',
      style: AppText.caption.copyWith(
        color: tokens.accent,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _SnapshotPage extends StatelessWidget {
  const _SnapshotPage({required this.term, required this.snapshot});
  final TimetableTerm term;
  final TimetableSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: Text(
          '快照课次',
          style: AppText.title.copyWith(color: tokens.labelPrimary),
        ),
        leading: AppGlassIconButton(
          icon: CupertinoIcons.back,
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.space4),
          children: [
            Text(
              term.label,
              style: AppText.largeTitle.copyWith(color: tokens.labelPrimary),
            ),
            const SizedBox(height: AppTokens.space1),
            Text(
              timestampLabel(snapshot.capturedAt),
              style: AppText.subhead.copyWith(color: tokens.labelSecondary),
            ),
            const SizedBox(height: AppTokens.space4),
            if (snapshot.sessions.isEmpty)
              Text(
                '此版本没有课程',
                style: AppText.body.copyWith(color: tokens.labelSecondary),
              ),
            for (final s in snapshot.sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space2),
                child: AppGlassCard(
                  glass: false,
                  onTap: () => showSessionDetails(context, s, term),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.name} · ${s.type}${s.adjusted ? ' · 调课' : ''}',
                        style: AppText.title.copyWith(
                          color: tokens.labelPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space1),
                      Text(
                        s.when,
                        style: AppText.subhead.copyWith(
                          color: tokens.labelSecondary,
                        ),
                      ),
                      if (s.location.isNotEmpty || s.teacher.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.space1),
                        Text(
                          [
                            if (s.location.isNotEmpty) s.location,
                            if (s.teacher.isNotEmpty) s.teacher,
                          ].join(' · '),
                          style: AppText.footnote.copyWith(
                            color: tokens.labelTertiary,
                          ),
                        ),
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
