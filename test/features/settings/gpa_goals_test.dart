import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zfjw_toolkit/core/stats/target_analysis.dart';
import 'package:zfjw_toolkit/features/settings/state/gpa_goals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GpaGoalsNotifier> makeNotifier() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(gpaGoalsProvider.notifier);
    await container.read(gpaGoalsProvider.future);
    return notifier;
  }

  group('GpaGoals', () {
    test('默认：目标 GPA 均为 3.0，最低 GPA 均为 2.0', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final goals = await container.read(gpaGoalsProvider.future);
      expect(goals.targetAll, 3.0);
      expect(goals.targetDegree, 3.0);
      expect(goals.minAll, 2.0);
      expect(goals.minDegree, 2.0);
      expect(goals.targetFor(TargetScope.all), 3.0);
      expect(goals.targetFor(TargetScope.degree), 3.0);
      expect(goals.minFor(TargetScope.all), 2.0);
      expect(goals.minFor(TargetScope.degree), 2.0);
    });

    test('旧版 jwgpa.targetGPA 键作为全部课程目标迁移读取', () async {
      SharedPreferences.setMockInitialValues({'jwgpa.targetGPA': 3.3});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final goals = await container.read(gpaGoalsProvider.future);
      expect(goals.targetAll, 3.3);
      expect(goals.targetDegree, 3.0);
    });

    test('分范围设置目标与最低 GPA 并持久化', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = await makeNotifier();
      await notifier.setTarget(TargetScope.all, 3.5);
      await notifier.setTarget(TargetScope.degree, 3.0);
      await notifier.setMin(TargetScope.all, 1.5);
      await notifier.setMin(TargetScope.degree, 2.5);

      final goals = notifier.state.value!;
      expect(goals.targetAll, 3.5);
      expect(goals.targetDegree, 3.0);
      expect(goals.minAll, 1.5);
      expect(goals.minDegree, 2.5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('jwgpa.targetGPA'), 3.5);
      expect(prefs.getDouble('jwgpa.targetGPA.degree'), 3.0);
      expect(prefs.getDouble('jwgpa.minGPA.all'), 1.5);
      expect(prefs.getDouble('jwgpa.minGPA.degree'), 2.5);
    });

    test('目标留空恢复默认 3.0、最低 GPA 留空恢复默认 2.0', () async {
      SharedPreferences.setMockInitialValues({
        'jwgpa.targetGPA': 3.5,
        'jwgpa.minGPA.degree': 2.8,
      });
      final notifier = await makeNotifier();
      await notifier.setTarget(TargetScope.all, null);
      await notifier.setMin(TargetScope.degree, null);

      final goals = notifier.state.value!;
      expect(goals.targetAll, 3.0);
      expect(goals.minDegree, 2.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('jwgpa.targetGPA'), isNull);
      expect(prefs.getDouble('jwgpa.minGPA.degree'), isNull);
    });
  });
}
