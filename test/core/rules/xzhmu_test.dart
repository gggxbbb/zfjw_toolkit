import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/rules/presets/xzhmu.dart';

CourseRecord rec({
  String? kch,
  String? kcmc,
  String? xf,
  String? jd,
  String? bfzcj,
  String? cj,
  String? cjbz,
  String? sfxwkc,
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
    );

void main() {
  const preset = XzhmuRulePreset();

  group('gradePoint', () {
    test('优先使用教务官方 jd', () {
      // 官方 jd=4.0 直接返回，不重算
      expect(preset.gradePoint(rec(kch: 'A', jd: '4.0', bfzcj: '85')), 4.0);
    });

    test('缺失 jd 回退 (score-50)/10', () {
      // 85 -> 3.5；60 -> 1.0；100 -> 5.0；95 -> 4.5（手算 literal）
      expect(preset.gradePoint(rec(kch: 'A', bfzcj: '85')), 3.5);
      expect(preset.gradePoint(rec(kch: 'A', bfzcj: '60')), 1.0);
      expect(preset.gradePoint(rec(kch: 'A', bfzcj: '100')), 5.0);
      expect(preset.gradePoint(rec(kch: 'A', bfzcj: '95')), 4.5);
    });

    test('<60 回退记 0', () {
      expect(preset.gradePoint(rec(kch: 'A', bfzcj: '59')), 0);
      expect(preset.gradePoint(rec(kch: 'A', bfzcj: '0')), 0);
    });

    test('无任何分数返回 null', () {
      expect(preset.gradePoint(rec(kch: 'A', cj: '免修')), isNull);
    });
  });

  group('isDegreeCourse', () {
    test('sfxwkc 含「是」', () {
      expect(preset.isDegreeCourse(rec(kch: 'A', sfxwkc: '是')), isTrue);
      expect(preset.isDegreeCourse(rec(kch: 'A', sfxwkc: '否')), isFalse);
    });

    test('「是」被不可见字符污染仍识别', () {
      expect(preset.isDegreeCourse(rec(kch: 'A', sfxwkc: ' \u200B是\u200E ')), isTrue);
    });

    test('编码值 1/true/Y/y/yes 兜底为学位课', () {
      for (final v in const ['1', 'true', 'Y', 'y', 'yes']) {
        expect(preset.isDegreeCourse(rec(kch: 'A', sfxwkc: v)), isTrue);
      }
      expect(preset.isDegreeCourse(rec(kch: 'A', sfxwkc: '0')), isFalse);
      expect(preset.isDegreeCourse(rec(kch: 'A', sfxwkc: 'N')), isFalse);
    });
  });

  group('isExempt', () {
    test('cj 含「免修」', () {
      expect(preset.isExempt(rec(kch: 'A', cj: '免修')), isTrue);
    });
    test('cjbz 含「免修」', () {
      expect(preset.isExempt(rec(kch: 'A', cjbz: '免修')), isTrue);
    });
    test('普通成绩非免修', () {
      expect(preset.isExempt(rec(kch: 'A', cj: '88')), isFalse);
      expect(preset.isExempt(rec(kch: 'A')), isFalse);
    });
  });

  group('isPass', () {
    test('官方 jd>0 通过，jd==0 不通过', () {
      expect(preset.isPass(rec(kch: 'A', jd: '3.0')), isTrue);
      expect(preset.isPass(rec(kch: 'A', jd: '0')), isFalse);
    });
    test('分数 >=60 通过，<60 不通过', () {
      expect(preset.isPass(rec(kch: 'A', bfzcj: '60')), isTrue);
      expect(preset.isPass(rec(kch: 'A', bfzcj: '59')), isFalse);
    });
    test('等级文本匹配', () {
      for (final t in const ['合格', '通过', '优秀', '良好', '中等', '及格']) {
        expect(preset.isPass(rec(kch: 'A', cj: t)), isTrue);
      }
      expect(preset.isPass(rec(kch: 'A', cj: '不及格')), isFalse);
    });
  });

  group('dedupe 去重', () {
    test('同课程代码取历次最高分', () {
      final rows = [
        rec(kch: 'A001', kcmc: '高数', bfzcj: '70'),
        rec(kch: 'A001', kcmc: '高数', bfzcj: '90'),
        rec(kch: 'A001', kcmc: '高数', bfzcj: '85'),
      ];
      final out = preset.dedupe(rows);
      expect(out, hasLength(1));
      expect(out.first.numericScore, 90);
    });

    test('免修记录优先于一切考试记录', () {
      final rows = [
        rec(kch: 'B002', kcmc: '英语', bfzcj: '95'),
        rec(kch: 'B002', kcmc: '英语', cj: '免修'),
      ];
      final out = preset.dedupe(rows);
      expect(out, hasLength(1));
      expect(preset.isExempt(out.first), isTrue);
    });

    test('0 分重修不影响已通过的有效记录', () {
      final rows = [
        rec(kch: 'C003', kcmc: '物理', bfzcj: '80'),
        rec(kch: 'C003', kcmc: '物理', bfzcj: '0'),
      ];
      final out = preset.dedupe(rows);
      expect(out.first.numericScore, 80);
    });

    test('不同课程代码各自保留', () {
      final rows = [
        rec(kch: 'A', bfzcj: '80'),
        rec(kch: 'B', bfzcj: '70'),
      ];
      expect(preset.dedupe(rows), hasLength(2));
    });
  });
}
