import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/overrides.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';
import 'package:zfjw_toolkit/data/override_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OverrideRepository（成绩）', () {
    test('空存储读回空 overrides', () async {
      SharedPreferences.setMockInitialValues({});
      final o = await OverrideRepository().loadRecords();
      expect(o.isEmpty, isTrue);
    });

    test('补丁 + 新增记录往返保持字段', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = OverrideRepository();
      final original = RecordOverrides(
        patches: const [
          RecordPatch(
            courseKey: 'A01',
            xnm: '2024',
            xqm: '1',
            cj: '95',
            jd: '4.5',
            sfxwkc: '否',
          ),
          RecordPatch(courseKey: 'A02', xnm: '2024', xqm: '2', deleted: true),
        ],
        additions: [
          CourseRecord.fromRaw(
              kch: 'M01', kcmc: '校外课程', xf: '2', bfzcj: '88', cj: '88'),
        ],
      );
      await repo.saveRecords(original);
      final restored = await repo.loadRecords();

      expect(restored.patches, hasLength(2));
      final p = restored.patches.first;
      expect(p.courseKey, 'A01');
      expect(p.cj, '95');
      expect(p.jd, '4.5');
      expect(p.sfxwkc, '否');
      expect(p.bfzcj, isNull); // 未覆盖字段保持 null
      expect(restored.patches.last.deleted, isTrue);
      expect(restored.additions.single.kcmc, '校外课程');
      expect(restored.additions.single.bfzcj, '88');
    });

    test('保存空 overrides 清除存储', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = OverrideRepository();
      await repo.saveRecords(const RecordOverrides(patches: [
        RecordPatch(courseKey: 'A01', deleted: true),
      ]));
      await repo.saveRecords(const RecordOverrides());
      expect((await repo.loadRecords()).isEmpty, isTrue);
    });

    test('损坏 JSON 读回空 overrides 而不是抛异常', () async {
      SharedPreferences.setMockInitialValues({'record_overrides': '{broken'});
      final o = await OverrideRepository().loadRecords();
      expect(o.isEmpty, isTrue);
    });
  });

  group('OverrideRepository（教学计划）', () {
    test('计划信息 + 课程补丁 + 新增课程往返', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = OverrideRepository();
      await repo.savePlan(const PlanOverrides(
        programName: '自定义计划',
        graduationCredits: 200,
        patches: [
          PlanCoursePatch(key: 'B01', credits: 5, sfxwkc: '否'),
          PlanCoursePatch(key: 'B02', deleted: true),
        ],
        additions: [
          PlannedCourse(
              code: 'M01',
              name: '第二课堂',
              credits: 1,
              suggestedYear: '2025-2026',
              suggestedTerm: '1',
              sfxwkc: '是'),
        ],
      ));
      final restored = await repo.loadPlan();

      expect(restored.programName, '自定义计划');
      expect(restored.graduationCredits, 200);
      expect(restored.patches, hasLength(2));
      expect(restored.patches.first.credits, 5);
      expect(restored.patches.first.sfxwkc, '否');
      expect(restored.patches.last.deleted, isTrue);
      expect(restored.additions.single.name, '第二课堂');
      expect(restored.additions.single.sfxwkc, '是');
    });

    test('空存储读回空 overrides', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await OverrideRepository().loadPlan()).isEmpty, isTrue);
    });
  });
}
