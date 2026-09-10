import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';
import 'package:zfjw_toolkit/core/rules/presets/xzhmu.dart';
import 'package:zfjw_toolkit/core/stats/stats_engine.dart';

CourseRecord rec({
  String? kch,
  String? kcmc,
  String? xf,
  String? jd,
  String? bfzcj,
  String? cj,
  String? cjbz,
  String? sfxwkc,
  String? xnm,
  String? xqm,
  String? xnmmc,
  String? xqmmc,
}) =>
    CourseRecord.fromRaw(
      kch: kch,
      kcmc: kcmc,
      xf: xf,
      jd: jd,
      bfzcj: bfzcj,
      cj: cj,
      cjbz: cjbz,
      sfxwkc: sfxwkc,
      xnm: xnm,
      xqm: xqm,
      xnmmc: xnmmc,
      xqmmc: xqmmc,
    );

const preset = XzhmuRulePreset();

void main() {
  group('computeStats', () {
    test('免修剥离前后对比', () {
      final raw = [
        rec(kch: 'E001', kcmc: '军事理论', xf: '2', cj: '免修'),
        rec(kch: 'A001', kcmc: '高数', xf: '4', bfzcj: '85'), // jd 3.5
        rec(kch: 'B002', kcmc: '英语', xf: '3', bfzcj: '90'), // jd 4.0
      ];
      final s = computeStats(raw, preset);
      // 免修单独汇总
      expect(s.exempt.count, 1);
      expect(s.exempt.credits, 2);
      expect(s.exempt.list.first.name, '军事理论');
      // 总体已剥离免修：仅 A+B，GPA = (4·3.5+3·4.0)/7 = 26/7 ≈ 3.7143
      expect(s.attempts, 3);
      expect(s.overall.count, 2);
      expect(s.overall.totalCredits, 7);
      expect(s.overall.gpa, closeTo(3.7143, 1e-3));
    });

    test('重修去重影响', () {
      final raw = [
        rec(kch: 'C001', kcmc: '物理', xf: '3', bfzcj: '60'), // jd 1.0
        rec(kch: 'C001', kcmc: '物理', xf: '3', bfzcj: '90'), // jd 4.0（取最高）
        rec(kch: 'D002', kcmc: '化学', xf: '2', bfzcj: '80'), // jd 3.0
      ];
      final s = computeStats(raw, preset);
      // 去重后 2 门；GPA = (3·4.0 + 2·3.0)/5 = 18/5 = 3.6
      expect(s.overall.count, 2);
      expect(s.overall.gpa, closeTo(3.6, 1e-9));
      // 若不去重则为 (3·1.0+3·4.0+2·3.0)/8 = 2.625，此处应不同
      expect(s.overall.gpa, isNot(closeTo(2.625, 1e-9)));
    });

    test('学位课子集', () {
      final raw = [
        rec(kch: 'A001', kcmc: '核心A', xf: '4', bfzcj: '90', sfxwkc: '是'), // jd 4.0
        rec(kch: 'B002', kcmc: '选修B', xf: '3', bfzcj: '80', sfxwkc: '否'), // jd 3.0
      ];
      final s = computeStats(raw, preset);
      expect(s.overall.count, 2);
      // 总体 GPA = (4·4.0+3·3.0)/7 = 25/7 ≈ 3.5714
      expect(s.overall.gpa, closeTo(3.5714, 1e-3));
      // 学位 GPA = 4·4.0/4 = 4.0
      expect(s.degree.count, 1);
      expect(s.degree.gpa, closeTo(4.0, 1e-9));
    });

    test('学期分组排序', () {
      final raw = [
        rec(
          kch: 'A', kcmc: 'a', xf: '3', bfzcj: '90',
          xnm: '2020', xqm: '1', xnmmc: '2020-2021', xqmmc: '1',
        ),
        rec(
          kch: 'B', kcmc: 'b', xf: '2', bfzcj: '80',
          xnm: '2021', xqm: '1', xnmmc: '2021-2022', xqmmc: '1',
        ),
        rec(
          kch: 'C', kcmc: 'c', xf: '1', bfzcj: '70',
          xnm: '2021', xqm: '2', xnmmc: '2021-2022', xqmmc: '2',
        ),
      ];
      final s = computeStats(raw, preset);
      expect(s.semesters, hasLength(3));
      // 排序值：202001, 202101, 202102 升序
      expect(s.semesters[0].key, '2020-2021 第1学期');
      expect(s.semesters[1].key, '2021-2022 第1学期');
      expect(s.semesters[2].key, '2021-2022 第2学期');
      expect(s.semesters[0].gpa, closeTo(4.0, 1e-9)); // 90→jd4.0
      expect(s.semesters[1].gpa, closeTo(3.0, 1e-9)); // 80→jd3.0
      expect(s.semesters[2].gpa, closeTo(2.0, 1e-9)); // 70→jd2.0
      expect(s.semesters[0].credits, 3);
      expect(s.semesters[0].count, 1);
    });

    test('挂科与疑似误输入', () {
      final raw = [
        rec(kch: 'F001', kcmc: '挂科', xf: '2', bfzcj: '50'), // 不及格
        rec(kch: 'G001', kcmc: '误输入', xf: '1', bfzcj: '5'), // <10 分
        rec(kch: 'H002', kcmc: '正常', xf: '3', bfzcj: '85'),
      ];
      final s = computeStats(raw, preset);
      expect(s.overall.failCount, 2);
      expect(s.failing, hasLength(2));
      expect(s.failing.any((f) => f.name == '挂科' && f.score == 50), isTrue);
      expect(s.suspicious, hasLength(1));
      expect(s.suspicious.first.name, '误输入');
      expect(s.suspicious.first.score, 5);
    });

    test('空输入', () {
      final s = computeStats(const [], preset);
      expect(s.attempts, 0);
      expect(s.overall.count, 0);
      expect(s.overall.gpa, isNull);
      expect(s.degree.count, 0);
      expect(s.semesters, isEmpty);
      expect(s.failing, isEmpty);
      expect(s.suspicious, isEmpty);
      expect(s.exempt.count, 0);
      expect(s.exempt.credits, 0);
      expect(s.rows, isEmpty);
    });
  });

  group('simulateAll (What-If)', () {
    test('替换单门成绩后新旧 GPA 对比', () {
      // A001 学位课 60分(jd1.0, xf4)；B002 非学位 90分(jd4.0, xf2)
      // 原总体 GPA = (4·1.0+2·4.0)/6 = 12/6 = 2.0
      // 原学位 GPA = 4·1.0/4 = 1.0
      final raw = [
        rec(kch: 'A001', kcmc: '核心', xf: '4', bfzcj: '60', sfxwkc: '是'),
        rec(kch: 'B002', kcmc: '选修', xf: '2', bfzcj: '90', sfxwkc: '否'),
      ];
      final s = computeStats(raw, preset);
      expect(s.overall.gpa, closeTo(2.0, 1e-9));
      expect(s.degree.gpa, closeTo(1.0, 1e-9));

      // 假设 A001 考到 90（jd 重估为 4.0）
      // 新总体 GPA = (4·4.0+2·4.0)/6 = 24/6 = 4.0
      // 新学位 GPA = 4·4.0/4 = 4.0
      final r = simulateAll(s, {'A001': 90});
      expect(r.oldOverall.gpa, closeTo(2.0, 1e-9));
      expect(r.newOverall.gpa, closeTo(4.0, 1e-9));
      expect(r.oldDegree.gpa, closeTo(1.0, 1e-9));
      expect(r.newDegree.gpa, closeTo(4.0, 1e-9));
      // 原结果不被修改（不可变）
      expect(s.overall.gpa, closeTo(2.0, 1e-9));
    });

    test('多门同时假设：已修课改分 + 计划未修课预估', () {
      final raw = [
        rec(kch: 'A001', kcmc: '核心', xf: '4', bfzcj: '60', sfxwkc: '是'),
        rec(kch: 'B002', kcmc: '选修', xf: '2', bfzcj: '90', sfxwkc: '否'),
      ];
      final s = computeStats(raw, preset);
      const planned = [
        PlannedCourse(
          code: 'C003',
          name: '未来的课',
          credits: 3,
          suggestedYear: '',
          suggestedTerm: '',
          sfxwkc: '是',
        ),
      ];
      // A001→90(jd4.0)，C003 预估 80(jd3.0, xf3, 学位)
      // 新总体 GPA = (4·4.0+2·4.0+3·3.0)/9 = 33/9 ≈ 3.667
      // 新学位 GPA = (4·4.0+3·3.0)/7 = 25/7 ≈ 3.571
      final r = simulateAll(s, {'A001': 90, 'C003': 80}, planned: planned);
      expect(r.newOverall.gpa, closeTo(33 / 9, 1e-9));
      expect(r.newDegree.gpa, closeTo(25 / 7, 1e-9));
      // 未知键被忽略
      final r2 = simulateAll(s, {'UNKNOWN': 100}, planned: planned);
      expect(r2.newOverall.gpa, closeTo(2.0, 1e-9));
    });

    test('空统计下模拟安全返回', () {
      final s = computeStats(const [], preset);
      final r = simulateAll(s, {'X': 90});
      expect(r.oldOverall.gpa, isNull);
      expect(r.newOverall.gpa, isNull);
    });
  });
}
