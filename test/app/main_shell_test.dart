import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/app/main_shell.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

void main() {
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
          child: const MaterialApp(home: MainShell()),
        ),
      );
      await tester.pump();
    }

    await pumpAt(719);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(AppGlassTabBar), findsOneWidget);

    await pumpAt(720);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
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
}
