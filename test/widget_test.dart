import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, NavigationRail;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/app/main_shell.dart';
import 'package:zfjw_toolkit/app/router.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/features/settings/settings_home_page.dart';
import 'package:zfjw_toolkit/features/settings/state/app_version.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

void main() {
  test('底部导航含「成绩」「目标分析」「设置」三个中文 tab', () {
    expect(appTabs, hasLength(3));
    expect(appTabs[0].label, '成绩');
    expect(appTabs[1].label, '目标分析');
    expect(appTabs[2].label, '设置');
  });

  testWidgets('宽屏使用左侧导航，窄屏保留底部标签栏', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            statsProvider.overrideWithValue(const AsyncValue.data(null)),
          ],
          child: const MaterialApp(home: MainShell()),
        ),
      );
      await tester.pump();
    }

    await pumpAt(const Size(1200, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(AppGlassTabBar), findsNothing);

    await pumpAt(const Size(600, 800));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(AppGlassTabBar), findsOneWidget);
  });

  testWidgets('内容卡片按可用宽度切换单列和双列', (tester) async {
    const first = Key('first-card');
    const second = Key('second-card');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 600);

    Future<void> pumpAt(double width) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: width,
            child: const AppResponsiveColumns(
              children: [
                SizedBox(key: first, height: 40),
                SizedBox(key: second, height: 40),
              ],
            ),
          ),
        ),
      ),
    );

    await pumpAt(900);
    expect(
      tester.getTopLeft(find.byKey(first)).dy,
      tester.getTopLeft(find.byKey(second)).dy,
    );
    expect(
      tester.getTopLeft(find.byKey(first)).dx,
      isNot(tester.getTopLeft(find.byKey(second)).dx),
    );

    await pumpAt(700);
    expect(
      tester.getTopLeft(find.byKey(first)).dx,
      tester.getTopLeft(find.byKey(second)).dx,
    );
    expect(
      tester.getTopLeft(find.byKey(second)).dy,
      greaterThan(tester.getTopLeft(find.byKey(first)).dy),
    );
  });

  // 成绩页（空态/统计态）已由 test/features/gpa/gpa_home_page_test.dart 覆盖，
  // 此处不再重复（它需要 ProviderScope + 数据库 override）。

  testWidgets('设置页渲染目标 GPA/规则包分区', (tester) async {
    final title = GlassLargeTitleController();
    addTearDown(title.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: CupertinoApp(home: SettingsHomePage(titleController: title)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('目标与最低 GPA'), findsOneWidget);
    expect(find.text('成绩计算规则'), findsOneWidget);
    expect(find.text('徐医规则包（xzhmu）'), findsOneWidget);
  });

  testWidgets('设置页展示实际安装包版本', (tester) async {
    final title = GlassLargeTitleController();
    addTearDown(title.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue(
            const AsyncValue.data('1.2.3 (45)'),
          ),
        ],
        child: CupertinoApp(home: SettingsHomePage(titleController: title)),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('版本'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('1.2.3 (45)'), findsOneWidget);
    expect(find.text('1.0.0'), findsNothing);
  });
}
