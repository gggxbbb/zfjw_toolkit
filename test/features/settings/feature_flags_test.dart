import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zfjw_toolkit/core/feature_flags/feature_flags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('默认关闭，选择持久化且不触碰其他数据', () async {
    SharedPreferences.setMockInitialValues({'unrelated': 'keep'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      (await container.read(
        featureFlagsProvider.future,
      ))[FeatureFlag.timetable],
      false,
    );
    await container
        .read(featureFlagsProvider.notifier)
        .setEnabled(FeatureFlag.timetable, true);
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    expect(
      (await restarted.read(
        featureFlagsProvider.future,
      ))[FeatureFlag.timetable],
      true,
    );
    await container
        .read(featureFlagsProvider.notifier)
        .setEnabled(FeatureFlag.timetable, false);
    expect(
      (await SharedPreferences.getInstance()).getString('unrelated'),
      'keep',
    );
  });

  test('连续写入按调用顺序保存', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(featureFlagsProvider.future);
    final notifier = container.read(featureFlagsProvider.notifier);
    await Future.wait([
      notifier.setEnabled(FeatureFlag.timetable, true),
      notifier.setEnabled(FeatureFlag.timetable, false),
    ]);
    expect(
      container.read(featureEnabledProvider(FeatureFlag.timetable)),
      false,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool(
        FeatureFlag.timetable.storageKey,
      ),
      false,
    );
  });
}
