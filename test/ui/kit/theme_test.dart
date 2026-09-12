import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/app/theme.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

void main() {
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
