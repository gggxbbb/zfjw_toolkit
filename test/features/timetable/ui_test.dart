import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/app/theme.dart';
import 'package:zfjw_toolkit/features/timetable/dialogs.dart';
import 'package:zfjw_toolkit/features/timetable/diff.dart';
import 'package:zfjw_toolkit/features/timetable/history_page.dart';
import 'package:zfjw_toolkit/features/timetable/model.dart';
import 'package:zfjw_toolkit/features/timetable/page.dart';
import 'package:zfjw_toolkit/features/timetable/providers.dart';
import 'package:zfjw_toolkit/features/timetable/week_grid.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

void main() {
  test('课程配色稳定且适配明暗主题', () {
    final first = AppTokens.light.courseColors('内科学');
    expect(first, AppTokens.light.courseColors(' 内科学 '));
    expect(first, isNot(AppTokens.light.courseColors('儿科学')));
    expect(first.background.computeLuminance(), greaterThan(.65));
    expect(
      AppTokens.dark.courseColors('内科学').background.computeLuminance(),
      lessThan(.15),
    );
  });
  final term = TimetableTerm(
    id: 't',
    label: '测试学期',
    monday: DateTime(2026, 9, 7),
    weeks: 20,
    checkedAt: DateTime(2026, 9, 22),
  );
  const s = ClassSession(
    name: '内科学',
    week: 1,
    day: 1,
    start: 1,
    end: 2,
    teachingType: TeachingType.lecture,
    adjusted: true,
    rawTitle: '【调】内科学★',
    rawTime: '(1-2节)1-16周',
    location: '教室一',
    teacher: '教师甲',
    group: '教学班一',
  );
  test('冲突布局分组、并排、独立课次不挤占宽度', () {
    final items = layoutDay([
      s,
      const ClassSession(name: '见习课', week: 1, day: 1, start: 2, end: 4),
      const ClassSession(name: '独立课', week: 1, day: 1, start: 6, end: 7),
    ]);
    expect(items.map((p) => p.lanes), [2, 2, 1]);
    expect(items.map((p) => p.lane), [0, 1, 0]);
  });
  testWidgets('窄屏完整七列、晚课延长、课次详情', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimetableWeekGrid(
              term: term,
              week: 1,
              sessions: const [
                s,
                ClassSession(name: '晚课', week: 1, day: 7, start: 14, end: 15),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('一\n9/7'), findsOneWidget);
    expect(find.text('日\n9/13'), findsOneWidget);
    expect(find.text('15\n22:20\n23:00'), findsOneWidget);
    expect(find.text('教师甲'), findsOneWidget);
    expect(find.text('教学班一'), findsOneWidget);
    expect(find.text('第 1 次'), findsNWidgets(2));
    expect(find.text('08:00–09:30'), findsOneWidget);
    await tester.tap(find.text('内科学'));
    await tester.pumpAndSettle();
    expect(find.textContaining('原始标题：【调】内科学★'), findsOneWidget);
    expect(find.textContaining('原始节次/周次：(1-2节)1-16周'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('课表首页窄屏显示周导航和历史入口无溢出', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final title = GlassLargeTitleController();
    addTearDown(title.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timetableTermsProvider.overrideWithValue(AsyncData([term])),
          timetableHistoryProvider('t').overrideWithValue(
            AsyncData([
              TimetableSnapshot(
                id: 'v',
                term: 't',
                capturedAt: DateTime(2026, 9, 22),
                sessions: const [s],
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: TimetablePage(titleController: title)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('历史快照'), findsOneWidget);
    expect(find.text('刷新课表'), findsOneWidget);
  });
  testWidgets('差异页使用正式排版并合并连续周的同类课次', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ClassSession added(int week) => ClassSession(
      name: '临床技能学1',
      week: week,
      day: 1,
      start: 6,
      end: 8,
      location: '实验中心',
      teacher: '教师甲',
    );
    const subtitle = '2026-2027学年第1学期 · 3 次课 · 首次采集';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TimetableDiffPage(
          subtitle: subtitle,
          confirm: true,
          changes: [
            for (var week = 2; week <= 4; week++)
              SessionChange(after: added(week)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('3 新增'), findsOneWidget);
    expect(find.text('临床技能学1'), findsOneWidget);
    expect(find.text('第 2–4 周 · 周一 · 6–8 节'), findsOneWidget);
    expect(find.text('使用新课表'), findsOneWidget);
    final subtitleText = tester.widget<Text>(find.text(subtitle));
    expect(subtitleText.style?.decoration, TextDecoration.none);
    expect(subtitleText.style?.color, AppTokens.light.labelPrimary);
  });
  testWidgets('历史页使用正式排版展示版本摘要', (tester) async {
    final snapshot = TimetableSnapshot(
      id: 'v',
      term: term.id,
      capturedAt: DateTime(2026, 9, 22, 8, 30),
      sessions: const [s],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timetableHistoryProvider(
            term.id,
          ).overrideWithValue(AsyncData([snapshot])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: TimetableHistoryPage(term: term),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('当前仅保留 1 个版本'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('1 次课'), findsOneWidget);
    final termText = tester.widget<Text>(find.text(term.label));
    expect(termText.style?.decoration, TextDecoration.none);
    expect(termText.style?.color, AppTokens.light.labelPrimary);
  });
}
