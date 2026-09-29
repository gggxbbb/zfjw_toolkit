import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
        theme: AppTheme.light,
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
    expect(find.textContaining('教师甲', findRichText: true), findsOneWidget);
    expect(find.textContaining('教学班一', findRichText: true), findsOneWidget);
    expect(find.textContaining('第 1 次', findRichText: true), findsNWidgets(2));
    expect(
      find.textContaining('08:00–09:30', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('内科学', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('课程标题：内科学★'), findsOneWidget);
    expect(find.textContaining('【调】', findRichText: true), findsNothing);
    expect(find.textContaining('调课', findRichText: true), findsNothing);
    expect(find.textContaining('原始节次/周次：(1-2节)1-16周'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(390, 844), const Size(1200, 800)]) {
    for (final dark in [false, true]) {
      testWidgets('完整课次适配 $size / dark=$dark', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(top: 80, bottom: 104),
                child: TimetableWeekGrid(
                  term: term,
                  week: 1,
                  sessions: const [
                    s,
                    ClassSession(
                      name: '超长课程名称临床综合实践',
                      week: 1,
                      day: 1,
                      start: 2,
                      end: 2,
                      location: '徐州市中心医院教学楼六号楼三楼304示教室',
                      teacher: '教师甲、教师乙、教师丙',
                      group: '临床综合实践教学班2026-0005',
                      teachingType: TeachingType.clerkship,
                      adjusted: true,
                    ),
                    ClassSession(
                      name: '晚间课程',
                      week: 1,
                      day: 7,
                      start: 13,
                      end: 13,
                      location: '九大（西区）',
                      teacher: '教师丁',
                      group: '教学班一',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final cards = find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('第 1 次'),
        );
        expect(cards, findsNWidgets(3));
        for (final element in cards.evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.size.width);
          expect(
            painter.height,
            lessThanOrEqualTo(paragraph.size.height + .01),
          );
          expect(painter.width, lessThanOrEqualTo(paragraph.size.width + .01));
          painter.dispose();
          expect(
            tester.getRect(find.byWidget(element.widget)).bottom,
            lessThanOrEqualTo(size.height - 104),
          );
        }
        await tester.tap(find.textContaining('晚间课程', findRichText: true));
        await tester.pumpAndSettle();
        expect(find.textContaining('第 1 周 周日 13–13 节'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
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
          theme: AppTheme.light,
          home: Scaffold(body: TimetablePage(titleController: title)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(TimetableWeekGrid)).bottom,
      lessThanOrEqualTo(844 - AppGlassMetrics.tabBarHeight),
    );
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
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
