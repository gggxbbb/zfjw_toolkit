import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/rules/presets/xzhmu.dart';
import 'package:zfjw_toolkit/core/stats/aggregate.dart';

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
  group('aggregate', () {
    test('混合学分绩点 GPA', () {
      // A: 4 学分 × 绩点 3.5 (=85)；B: 2 学分 × 绩点 4.0 (=90)
      // GPA = (4·3.5 + 2·4.0) / 6 = 22/6 ≈ 3.6667
      // 加权 = (4·85 + 2·90) / 6 = 520/6 ≈ 86.6667；算术 = (85+90)/2 = 87.5
      final rows = [
        rec(kch: 'A', kcmc: '高数', xf: '4', jd: '3.5', bfzcj: '85'),
        rec(kch: 'B', kcmc: '英语', xf: '2', jd: '4.0', bfzcj: '90'),
      ];
      final a = aggregate(rows, preset);
      expect(a.count, 2);
      expect(a.gpa, closeTo(3.6667, 1e-3));
      expect(a.weightedAvg, closeTo(86.6667, 1e-3));
      expect(a.arithAvg, closeTo(87.5, 1e-9));
      expect(a.earnedCredits, 6);
      expect(a.totalCredits, 6);
      expect(a.failCount, 0);
      expect(a.nonNumeric, 0);
      expect(a.maxScore, 90);
      expect(a.maxCourse, '英语');
      expect(a.minScore, 85);
      expect(a.minCourse, '高数');
      expect(a.distribution, [1, 1, 0, 0, 0]);
    });

    test('无有效绩点时 gpa 为 null', () {
      // 仅文本及格、无分数也无 jd → gradePoint 返回 null
      final rows = [rec(kch: 'A', xf: '3', cj: '及格')];
      final a = aggregate(rows, preset);
      expect(a.gpa, isNull);
      expect(a.weightedAvg, isNull);
      expect(a.arithAvg, isNull);
      expect(a.earnedCredits, 3); // 文本通过仍记已获学分
      expect(a.totalCredits, 3);
      expect(a.nonNumeric, 1);
      expect(a.distribution, [0, 0, 0, 0, 0]);
    });

    test('非百分制（文本及格）不进分布但记已获学分', () {
      final rows = [
        rec(kch: 'A', xf: '2', cj: '及格'),
        rec(kch: 'B', xf: '3', bfzcj: '82'),
      ];
      final a = aggregate(rows, preset);
      expect(a.nonNumeric, 1);
      expect(a.earnedCredits, 5);
      expect(a.weightedAvg, closeTo(82, 1e-9)); // 仅 B 有分数
      expect(a.distribution, [0, 1, 0, 0, 0]);
    });

    test('五档分数分布', () {
      // 100→[90-100], 95→[90-100], 85→[80-89], 75→[70-79],
      // 65→[60-69], 55→[<60]
      final rows = [
        rec(kch: 'A', xf: '1', bfzcj: '100'),
        rec(kch: 'B', xf: '1', bfzcj: '95'),
        rec(kch: 'C', xf: '1', bfzcj: '85'),
        rec(kch: 'D', xf: '1', bfzcj: '75'),
        rec(kch: 'E', xf: '1', bfzcj: '65'),
        rec(kch: 'F', xf: '1', bfzcj: '55'),
      ];
      final a = aggregate(rows, preset);
      expect(a.distribution, [2, 1, 1, 1, 1]);
      expect(a.maxScore, 100);
      expect(a.minScore, 55);
    });

    test('空输入', () {
      final a = aggregate(const [], preset);
      expect(a.count, 0);
      expect(a.gpa, isNull);
      expect(a.weightedAvg, isNull);
      expect(a.arithAvg, isNull);
      expect(a.earnedCredits, 0);
      expect(a.totalCredits, 0);
      expect(a.failCount, 0);
      expect(a.nonNumeric, 0);
      expect(a.maxScore, isNull);
      expect(a.minScore, isNull);
      expect(a.distribution, [0, 0, 0, 0, 0]);
    });
  });
}
