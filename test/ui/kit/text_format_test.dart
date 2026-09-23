import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/app/theme.dart';
import 'package:zfjw_toolkit/features/capture/web_capture_page.dart';
import 'package:zfjw_toolkit/features/timetable/dialogs.dart';
import 'package:zfjw_toolkit/features/timetable/page.dart';
import 'package:zfjw_toolkit/features/timetable/providers.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [390.0, 1280.0]) {
      testWidgets('文字在 ${dark ? "暗色" : "亮色"} / $width 下不继承错误样式', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final tokens = dark ? AppTokens.dark : AppTokens.light;
        final title = GlassLargeTitleController();
        addTearDown(title.dispose);
        late BuildContext pageContext;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              timetableTermsProvider.overrideWithValue(const AsyncData([])),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: Builder(
                builder: (context) {
                  pageContext = context;
                  // 故意不包 Material/主壳 DefaultTextStyle，暴露遗漏的业务样式。
                  return AppGlassScaffold(
                    body: TimetablePage(titleController: title),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        void check(String label, Color color) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style?.color, color, reason: label);
          expect(text.style?.decoration, TextDecoration.none, reason: label);
          expect(
            text.style?.fontFamilyFallback,
            AppText.body.fontFamilyFallback,
          );
          expect(tester.takeException(), isNull);
        }

        check('把整个学期的课表带到这里', tokens.labelPrimary);
        check('采集后可离线查看，更新前对比变化。', tokens.labelSecondary);

        final settings = editTermSettings(
          pageContext,
          weeks: 20,
          minimumWeeks: 1,
        );
        await tester.pumpAndSettle();
        check('学期设置', tokens.labelPrimary);
        for (final field in tester.widgetList<CupertinoTextField>(
          find.byType(CupertinoTextField),
        )) {
          expect(field.style?.color, tokens.labelPrimary);
          expect(field.style?.decoration, TextDecoration.none);
        }
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        check('日期须为周一（YYYY-MM-DD），总周数须为 1–60', tokens.danger);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(await settings, isNull);

        final choice = chooseTimetableItem(pageContext, '选择教学周', [
          (label: '第 1 周', value: 1),
        ]);
        await tester.pumpAndSettle();
        check('选择教学周', tokens.labelSecondary);
        check('第 1 周', tokens.accent);
        await tester.tap(find.text('第 1 周'));
        await tester.pumpAndSettle();
        expect(await choice, 1);

        final review = showCaptureOverview(
          pageContext,
          WebCaptureResult.review(
            '读取完成',
            overview: const ['成绩记录：40 条'],
            commit: () async {},
          ),
        );
        await tester.pumpAndSettle();
        check('采集概览', tokens.labelPrimary);
        check('读取完成\n成绩记录：40 条', tokens.labelPrimary);
        check('使用本次数据', tokens.accent);
        await tester.tap(find.text('使用本次数据'));
        await tester.pumpAndSettle();
        expect(await review, CaptureReviewAction.accept);
      });
    }
  }
}
