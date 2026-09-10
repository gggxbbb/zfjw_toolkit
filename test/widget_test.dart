import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/app/router.dart';
import 'package:zfjw_toolkit/features/settings/settings_home_page.dart';

void main() {
  test('底部导航含「成绩」「设置」两个中文 tab', () {
    expect(appTabs, hasLength(2));
    expect(appTabs[0].label, '成绩');
    expect(appTabs[1].label, '设置');
  });

  // 成绩页（空态/统计态）已由 test/features/gpa/gpa_home_page_test.dart 覆盖，
  // 此处不再重复（它需要 ProviderScope + 数据库 override）。

  testWidgets('设置页渲染目标 GPA/规则包分区', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SettingsHomePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('目标 GPA'), findsOneWidget);
    expect(find.text('规则包'), findsOneWidget);
    expect(find.text('徐医规则包（xzhmu）'), findsOneWidget);
  });
}
