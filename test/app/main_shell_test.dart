import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zfjw_toolkit/app/theme.dart';
import 'package:zfjw_toolkit/core/feature_flags/feature_flags.dart';
import 'package:zfjw_toolkit/features/settings/settings_home_page.dart';

import 'package:zfjw_toolkit/app/main_shell.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('导航在 720 断点切换，并在 1100 断点展开', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    Future<void> pumpAt(double width) async {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            statsProvider.overrideWithValue(const AsyncValue.data(null)),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const MainShell()),
        ),
      );
      await tester.pump();
    }

    await pumpAt(719);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(AppGlassTabBar), findsOneWidget);

    await pumpAt(720);
    final compactRail = tester.widget<NavigationRail>(
      find.byType(NavigationRail),
    );
    expect(compactRail.extended, isFalse);
    expect(compactRail.indicatorColor, AppTokens.light.accent);
    expect(compactRail.selectedIconTheme?.color, Colors.white);
    expect(find.byType(AppGlassTabBar), findsNothing);

    await pumpAt(1099);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );

    await pumpAt(1100);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
  });
  for (final width in [390.0, 1200.0]) {
    for (final dark in [false, true]) {
      testWidgets('开关更新导航但保留设置页 $width dark=$dark', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [statsProvider.overrideWithValue(const AsyncData(null))],
        );
        addTearDown(container.dispose);
        await container.read(featureFlagsProvider.future);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: const MainShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        int tabCount() => width < 720
            ? tester
                  .widget<AppGlassTabBar>(find.byType(AppGlassTabBar))
                  .tabs
                  .length
            : tester
                  .widget<NavigationRail>(find.byType(NavigationRail))
                  .destinations
                  .length;
        expect(tabCount(), 3);
        if (width < 720) {
          tester
              .widget<AppGlassTabBar>(find.byType(AppGlassTabBar))
              .onTabSelected(2);
        } else {
          tester
              .widget<NavigationRail>(find.byType(NavigationRail))
              .onDestinationSelected!(2);
        }
        await tester.pumpAndSettle();
        expect(find.byType(SettingsHomePage), findsOneWidget);
        final toggle = find.byType(AppGlassSwitch);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tabCount(), 4);
        expect(find.byType(SettingsHomePage), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tabCount(), 3);
        expect(find.byType(SettingsHomePage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
