import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/ui/kit/kit.dart';

void main() {
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
}
