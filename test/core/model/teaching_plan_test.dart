import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';

void main() {
  group('PlannedCourse.fromJson', () {
    test('从教学计划 grid 行读取 zyzgkcbj 学位课标记', () {
      // 正方教学执行计划课程信息 grid 的字段名是 zyzgkcbj（列名"是否学位课程"）。
      final c = PlannedCourse.fromJson(const {
        'kch': 'A001',
        'kcmc': '系统解剖学',
        'xf': '4',
        'jynj': '2023-2024',
        'jyxq': '1',
        'zyzgkcbj': '是',
      });
      expect(c.code, 'A001');
      expect(c.name, '系统解剖学');
      expect(c.credits, 4);
      expect(c.sfxwkc, '是');
    });

    test('兼容成绩单风格的 sfxwkc 字段，zyzgkcbj 为否时保留否', () {
      final a = PlannedCourse.fromJson(const {
        'kch': 'A001',
        'kcmc': '甲',
        'xf': '2',
        'sfxwkc': '是',
      });
      expect(a.sfxwkc, '是');
      final b = PlannedCourse.fromJson(const {
        'kch': 'B002',
        'kcmc': '乙',
        'xf': '2',
        'zyzgkcbj': '否',
      });
      expect(b.sfxwkc, '否');
      // 两个字段都缺省 → 空串
      final c = PlannedCourse.fromJson(const {
        'kch': 'C003',
        'kcmc': '丙',
        'xf': '2',
      });
      expect(c.sfxwkc, '');
    });

    test('存档往返保留学位课标记', () {
      const c = PlannedCourse(
        code: 'A001',
        name: '甲',
        credits: 4,
        suggestedYear: '',
        suggestedTerm: '',
        sfxwkc: '是',
      );
      final restored = PlannedCourse.fromStoredJson(c.toJson());
      expect(restored.sfxwkc, '是');
      // 旧存档没有 sfxwkc 键 → 空串
      final legacy = PlannedCourse.fromStoredJson(const {
        'code': 'B',
        'name': '乙',
        'credits': 2,
      });
      expect(legacy.sfxwkc, '');
    });
  });
}
