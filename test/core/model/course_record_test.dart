import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';

void main() {
  group('cleanField', () {
    test('剥除 Unicode Cf 类零宽字符后 trim', () {
      // U+200B 零宽空格、U+200E 方向标记、U+00AD 软连字符 均属 Cf
      const polluted = ' \u200B是\u200E ';
      expect(cleanField(polluted), '是');
    });

    test('剥除 Zs 类不间断空格与全角空格', () {
      // U+00A0 不间断空格、U+3000 全角空格 均属 Zs
      const polluted = ' \u00A0计算机\u3000';
      expect(cleanField(polluted), '计算机');
    });

    test('null 与空串归为清洁空串', () {
      expect(cleanField(null), '');
      expect(cleanField('   '), '');
    });
  });

  group('parseNum', () {
    test('清洗后解析整数与小数', () {
      expect(parseNum('85'), 85);
      expect(parseNum('85.5'), 85.5);
      expect(parseNum(' \u00A090.0 '), 90);
    });

    test('无法解析返回 null', () {
      expect(parseNum('免修'), isNull);
      expect(parseNum(''), isNull);
      expect(parseNum(null), isNull);
    });
  });

  group('CourseRecord.fromRaw 清洗', () {
    test('原始字段不可见字符被剥除', () {
      final r = CourseRecord.fromRaw(
        kch: ' \u200BA001',
        kcmc: ' \u3000高等数学',
        sfxwkc: ' \u200B是\u200E',
      );
      expect(r.kch, 'A001');
      expect(r.kcmc, '高等数学');
      expect(r.sfxwkc, '是');
    });

    test('直接构造不清洗（fromRaw 才是清洗入口）', () {
      final r = CourseRecord(kch: ' \u200BX');
      expect(r.kch, ' \u200BX');
    });
  });

  group('CourseRecord 数值访问器', () {
    test('numericScore 优先 bfzcj，回退 cj', () {
      final r = CourseRecord.fromRaw(bfzcj: '88', cj: '77');
      expect(r.numericScore, 88);
      final r2 = CourseRecord.fromRaw(cj: '77');
      expect(r2.numericScore, 77);
      final r3 = CourseRecord.fromRaw(cj: '免修', bfzcj: '');
      expect(r3.numericScore, isNull);
    });

    test('credit 与 officialGradePoint 解析', () {
      final r = CourseRecord.fromRaw(xf: '4.0', jd: '3.8');
      expect(r.credit, 4.0);
      expect(r.officialGradePoint, 3.8);
    });

    test('courseKey 取 kch，缺失回退 kcmc', () {
      expect(CourseRecord.fromRaw(kch: 'A1').courseKey, 'A1');
      expect(CourseRecord.fromRaw(kcmc: '物理').courseKey, '物理');
    });
  });

  group('CourseRecord 相等性', () {
    test('同字段相等、异字段不等', () {
      final a = CourseRecord.fromRaw(kch: 'A1', xf: '3');
      final b = CourseRecord.fromRaw(kch: 'A1', xf: '3');
      final c = CourseRecord.fromRaw(kch: 'A1', xf: '4');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
