import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/app/theme.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

void main() {
  test('全局文字样式优先使用 Windows 中文 UI 字体回退', () {
    for (final style in [
      AppText.largeTitle,
      AppText.title,
      AppText.body,
      AppText.subhead,
      AppText.footnote,
    ]) {
      expect(style.fontFamilyFallback?.first, 'Microsoft YaHei UI');
    }
  });

  testWidgets('玻璃页面背景跟随应用暗色主题', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const AppGlassScaffold(body: SizedBox()),
      ),
    );

    final wallpaper = find.byType(AppWallpaper);
    final background = tester.widget<ColoredBox>(
      find.descendant(of: wallpaper, matching: find.byType(ColoredBox)),
    );
    expect(background.color, AppTokens.dark.canvas);
  });
}
