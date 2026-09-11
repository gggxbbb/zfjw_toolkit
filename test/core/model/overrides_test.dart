import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/overrides.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';

CourseRecord _record({
  String kch = 'A01',
  String kcmc = '高等数学',
  String xf = '4',
  String jd = '4.0',
  String bfzcj = '90',
  String cj = '90',
  String sfxwkc = '是',
  String xnm = '2024',
  String xqm = '1',
}) =>
    CourseRecord.fromRaw(
      kch: kch,
      kcmc: kcmc,
      xf: xf,
      jd: jd,
      bfzcj: bfzcj,
      cj: cj,
      sfxwkc: sfxwkc,
      xnm: xnm,
      xqm: xqm,
      xnmmc: '2024-2025',
      xqmmc: '1',
    );

void main() {
  group('applyRecordOverrides', () {
    test('无 overrides 时原样返回', () {
      final raw = [_record()];
      final out = applyRecordOverrides(raw, const RecordOverrides());
      expect(out, hasLength(1));
      expect(out.single, equals(raw.single));
    });

    test('补丁只覆盖非 null 字段，其余保留采集值', () {
      final raw = [_record()];
      final out = applyRecordOverrides(
        raw,
        const RecordOverrides(patches: [
          RecordPatch(courseKey: 'A01', xnm: '2024', xqm: '1', bfzcj: '95'),
        ]),
      );
      expect(out.single.bfzcj, '95');
      expect(out.single.cj, '90'); // 未覆盖字段保留
      expect(out.single.jd, '4.0');
      expect(out.single.xf, '4');
    });

    test('删除补丁隐藏整条记录', () {
      final raw = [_record(), _record(kch: 'A02', kcmc: '大学英语')];
      final out = applyRecordOverrides(
        raw,
        const RecordOverrides(patches: [
          RecordPatch(courseKey: 'A01', xnm: '2024', xqm: '1', deleted: true),
        ]),
      );
      expect(out, hasLength(1));
      expect(out.single.kch, 'A02');
    });

    test('同课程不同学期的补丁互不串扰', () {
      final raw = [_record(), _record(xqm: '2')];
      final out = applyRecordOverrides(
        raw,
        const RecordOverrides(patches: [
          RecordPatch(courseKey: 'A01', xnm: '2024', xqm: '2', cj: '61'),
        ]),
      );
      expect(out[0].cj, '90');
      expect(out[1].cj, '61');
    });

    test('未命中的补丁保留但在本次结果中不生效', () {
      final raw = [_record(kch: 'A02', kcmc: '大学英语', sfxwkc: '否')];
      final out = applyRecordOverrides(
        raw,
        const RecordOverrides(patches: [
          RecordPatch(courseKey: 'A01', xnm: '2024', xqm: '1', bfzcj: '95'),
        ]),
      );
      expect(out.single.bfzcj, '90');
    });

    test('手动新增记录追加到结果末尾', () {
      final raw = [_record()];
      final added = _record(kch: 'M01', kcmc: '校外课程', xnm: '2025', xqm: '1');
      final out = applyRecordOverrides(
        raw,
        RecordOverrides(additions: [added]),
      );
      expect(out, hasLength(2));
      expect(out.last.kcmc, '校外课程');
    });

    test('无快照时新增记录也能生效', () {
      final added = _record(kch: 'M01', kcmc: '校外课程');
      final out = applyRecordOverrides(
        const [],
        RecordOverrides(additions: [added]),
      );
      expect(out.single.kcmc, '校外课程');
    });
  });

  group('RecordOverrides 增删改', () {
    test('upsertPatch 同键替换，空补丁移除', () {
      const base = RecordOverrides(patches: [
        RecordPatch(courseKey: 'A01', xnm: '2024', xqm: '1', cj: '80'),
      ]);
      final replaced = base.upsertPatch(
          const RecordPatch(courseKey: 'A01', xnm: '2024', xqm: '1', cj: '85'));
      expect(replaced.patches.single.cj, '85');

      final removed =
          replaced.removePatch('A01', '2024', '1');
      expect(removed.patches, isEmpty);
    });

    test('upsertAddition 同课程同学期后写覆盖，removeAddition 精确移除', () {
      final a = _record(kch: 'M01', kcmc: '旧名');
      final b = _record(kch: 'M01', kcmc: '新名');
      var o = const RecordOverrides().upsertAddition(a);
      o = o.upsertAddition(b);
      expect(o.additions, hasLength(1));
      expect(o.additions.single.kcmc, '新名');

      o = o.removeAddition('M01', '2024', '1');
      expect(o.additions, isEmpty);
    });
  });

  group('applyPlanOverrides', () {
    const plan = TeachingPlan(
      programName: '2023级临床医学',
      graduationCredits: 220,
      courses: [
        PlannedCourse(
            code: 'B01',
            name: '系统解剖学',
            credits: 4,
            suggestedYear: '2023-2024',
            suggestedTerm: '1',
            sfxwkc: '是'),
        PlannedCourse(
            code: 'B02',
            name: '大学英语',
            credits: 2,
            suggestedYear: '2023-2024',
            suggestedTerm: '1'),
      ],
    );

    test('课程补丁覆盖学分/学位标记，删除补丁隐藏课程', () {
      final out = applyPlanOverrides(
        plan,
        const PlanOverrides(patches: [
          PlanCoursePatch(key: 'B01', credits: 5, sfxwkc: '否'),
          PlanCoursePatch(key: 'B02', deleted: true),
        ]),
      );
      expect(out.courses, hasLength(1));
      expect(out.courses.single.credits, 5);
      expect(out.courses.single.sfxwkc, '否');
      expect(out.courses.single.suggestedYear, '2023-2024'); // 未覆盖字段保留
    });

    test('计划信息覆盖与手动新增课程', () {
      final out = applyPlanOverrides(
        plan,
        const PlanOverrides(
          programName: '自定义计划',
          graduationCredits: 200,
          additions: [
            PlannedCourse(
                code: 'M01',
                name: '第二课堂',
                credits: 1,
                suggestedYear: '2025-2026',
                suggestedTerm: '1'),
          ],
        ),
      );
      expect(out.programName, '自定义计划');
      expect(out.graduationCredits, 200);
      expect(out.courses, hasLength(3));
      expect(out.courses.last.name, '第二课堂');
    });

    test('空 overrides 返回原计划', () {
      final out = applyPlanOverrides(plan, const PlanOverrides());
      expect(identical(out, plan), isTrue);
    });
  });

  group('PlanOverrides 增删改', () {
    test('upsertPatch 同键替换，空补丁移除；copyWithPlanInfo 可清空覆盖', () {
      const base = PlanOverrides(
        programName: '自定义',
        patches: [PlanCoursePatch(key: 'B01', credits: 5)],
      );
      final removed = base.removePatch('B01');
      expect(removed.patches, isEmpty);
      expect(removed.programName, '自定义'); // 计划信息不受课程补丁影响

      final cleared = removed.copyWithPlanInfo(
          programName: () => null, graduationCredits: () => null);
      expect(cleared.programName, isNull);
      expect(cleared.isEmpty, isTrue);
    });

    test('upsertAddition 同键后写覆盖', () {
      const a = PlannedCourse(
          code: 'M01',
          name: '旧名',
          credits: 1,
          suggestedYear: '',
          suggestedTerm: '');
      const b = PlannedCourse(
          code: 'M01',
          name: '新名',
          credits: 2,
          suggestedYear: '',
          suggestedTerm: '');
      var o = const PlanOverrides().upsertAddition(a);
      o = o.upsertAddition(b);
      expect(o.additions.single.name, '新名');
      expect(o.removeAddition('M01').additions, isEmpty);
    });
  });
}
