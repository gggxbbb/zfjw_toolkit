import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/kit/kit.dart';
import 'capture_page.dart';
import 'dialogs.dart';
import 'history_page.dart';
import 'providers.dart';
import 'week_grid.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key, required this.titleController});
  final GlassLargeTitleController titleController;
  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  String? selectedTerm;
  int? selectedWeek;
  Future<void> capture() async {
    final term = await Navigator.of(context).push<String>(
      CupertinoPageRoute(builder: (_) => const TimetableCapturePage()),
    );
    if (mounted && term != null) {
      setState(() {
        selectedTerm = term;
        selectedWeek = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final terms = ref.watch(timetableTermsProvider);
    return CustomScrollView(
      controller: widget.titleController.scrollController,
      slivers: [
        AppGlassLargeTitle(text: '课表', controller: widget.titleController),
        SliverPadding(
          padding: AppPagePadding.body(context),
          sliver: SliverToBoxAdapter(
            child: terms.when(
              loading: () => const Center(child: AppGlassProgress()),
              error: (e, _) => Column(
                children: [
                  Text(
                    '课表加载失败：$e',
                    style: AppText.body.copyWith(
                      color: AppTokens.of(context).danger,
                    ),
                  ),
                  AppGlassButton(
                    label: '重试',
                    onTap: () => ref.invalidate(timetableTermsProvider),
                  ),
                ],
              ),
              data: (all) {
                if (all.isEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: 64),
                      const Icon(CupertinoIcons.calendar, size: 56),
                      const SizedBox(height: 20),
                      Text(
                        '把整个学期的课表带到这里',
                        style: AppText.title.copyWith(
                          color: AppTokens.of(context).labelPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '采集后可离线查看，更新前对比变化。',
                        style: AppText.subhead.copyWith(
                          color: AppTokens.of(context).labelSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppGlassButton(label: '采集课表', onTap: capture),
                    ],
                  );
                }
                final term =
                    all.where((t) => t.id == selectedTerm).firstOrNull ??
                    all.first;
                final actualWeek = term.weekAt(DateTime.now());
                final week = (selectedWeek ?? actualWeek).clamp(1, term.weeks);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppGlassButton(
                          label: term.label,
                          onTap: () async {
                            final id = await chooseTimetableItem(
                              context,
                              '选择学期',
                              all
                                  .map((t) => (label: t.label, value: t.id))
                                  .toList(),
                            );
                            if (mounted && id != null) {
                              setState(() {
                                selectedTerm = id;
                                selectedWeek = null;
                              });
                            }
                          },
                        ),
                        AppGlassButton(
                          label: '刷新课表',
                          icon: CupertinoIcons.refresh,
                          onTap: capture,
                        ),
                        AppGlassButton(
                          label: '历史快照',
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute<void>(
                              builder: (_) => TimetableHistoryPage(term: term),
                            ),
                          ),
                        ),
                        AppGlassButton(
                          label: '学期设置',
                          onTap: () async {
                            try {
                              final versions = await ref
                                  .read(timetableRepositoryProvider)
                                  .history(term.id);
                              final minWeeks =
                                  versions.firstOrNull?.lastWeek ?? 1;
                              if (!context.mounted) return;
                              final setting = await editTermSettings(
                                context,
                                monday: term.monday,
                                weeks: term.weeks,
                                minimumWeeks: minWeeks,
                              );
                              if (setting == null) return;
                              await ref
                                  .read(timetableRepositoryProvider)
                                  .settings(term, setting.$1, setting.$2);
                              ref.invalidate(timetableTermsProvider);
                            } catch (e) {
                              if (context.mounted) {
                                await showTimetableMessage(
                                  context,
                                  '设置未保存',
                                  '$e',
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '最后检查 ${timestampLabel(term.checkedAt)}',
                      style: AppText.footnote.copyWith(
                        color: AppTokens.of(context).labelSecondary,
                      ),
                    ),
                    if (actualWeek < 1 || actualWeek > term.weeks)
                      Text(
                        actualWeek < 1 ? '本学期尚未开始' : '本学期已结束',
                        style: AppText.footnote.copyWith(
                          color: AppTokens.of(context).labelSecondary,
                        ),
                      ),
                    Row(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: week > 1
                              ? () => setState(() => selectedWeek = week - 1)
                              : null,
                          child: const Icon(CupertinoIcons.chevron_left),
                        ),
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FittedBox(
                              child: Text(
                                '第 $week / ${term.weeks} 周',
                                style: AppText.body.copyWith(
                                  color: AppTokens.of(context).accent,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              final w =
                                  await chooseTimetableItem(context, '选择教学周', [
                                    for (var i = 1; i <= term.weeks; i++)
                                      (label: '第 $i 周', value: i),
                                  ]);
                              if (mounted && w != null) {
                                setState(() => selectedWeek = w);
                              }
                            },
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => setState(() => selectedWeek = null),
                          child: Text(
                            '本周',
                            style: AppText.body.copyWith(
                              color: AppTokens.of(context).accent,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: week < term.weeks
                              ? () => setState(() => selectedWeek = week + 1)
                              : null,
                          child: const Icon(CupertinoIcons.chevron_right),
                        ),
                      ],
                    ),
                    ref
                        .watch(timetableHistoryProvider(term.id))
                        .when(
                          loading: () =>
                              const Center(child: AppGlassProgress()),
                          error: (e, _) => Text(
                            '课表读取失败：$e',
                            style: AppText.body.copyWith(
                              color: AppTokens.of(context).danger,
                            ),
                          ),
                          data: (versions) => Column(
                            children: [
                              if (!(versions.firstOrNull?.sessions.any(
                                    (s) => s.week == week,
                                  ) ??
                                  false))
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    '本周没有课程',
                                    style: AppText.subhead.copyWith(
                                      color: AppTokens.of(
                                        context,
                                      ).labelSecondary,
                                    ),
                                  ),
                                ),
                              TimetableWeekGrid(
                                term: term,
                                week: week,
                                sessions: versions.firstOrNull?.sessions ?? [],
                              ),
                            ],
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
