import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/core/parser/grade_parse_result.dart';
import 'package:zfjw_toolkit/core/parser/grade_parser.dart';

import 'fixtures.dart';

void main() {
  group('parseJqGridJson', () {
    test('正常数组解析为同等数量的有效 CourseRecord', () {
      final result = parseJqGridJson(normalJqGridRows);
      expect(result, isA<GradeParseSuccess>());
      final records = (result as GradeParseSuccess).records;
      // 第三条仅含 kcmc，仍算有效行
      expect(records, hasLength(3));
      expect(records[0].kch, '100101');
      expect(records[0].kcmc, '系统解剖学');
      expect(records[0].sfxwkc, '是');
      expect(records[0].bfzcj, '92');
      expect(records[0].credit, 4.0);
      expect(records[2].kch, isEmpty);
      expect(records[2].kcmc, '体育(一)');
    });

    test('缺 sfxwkc/bfzcj 列返回 incompleteColumns 失败信号', () {
      final result = parseJqGridJson(incompleteColumnRows);
      expect(result, isA<GradeParseFailure>());
      expect(
        (result as GradeParseFailure).reason,
        GradeParseFailureReason.incompleteColumns,
      );
    });

    test('污染字符（U+200B/U+00A0）被清洗，值与正常数据一致', () {
      final result = parseJqGridJson(pollutedJqGridRows);
      expect(result, isA<GradeParseSuccess>());
      final record = (result as GradeParseSuccess).records.single;
      expect(record.kch, '100101');
      expect(record.kcmc, '系统解剖学');
      expect(record.sfxwkc, '是');
    });

    test('空数组返回成功且 0 条记录', () {
      final result = parseJqGridJson([]);
      expect(result, isA<GradeParseSuccess>());
      expect((result as GradeParseSuccess).records, isEmpty);
    });

    test('所有行均缺 kch/kcmc 时成功但 0 条记录', () {
      final result = parseJqGridJson([
        {'xf': '2.0', 'jd': '3.0', 'bfzcj': '80', 'sfxwkc': '否'},
      ]);
      expect(result, isA<GradeParseSuccess>());
      expect((result as GradeParseSuccess).records, isEmpty);
    });
  });

  group('parseGradeHtml', () {
    test('正常 HTML 按 aria-describedby 列名解析（与列顺序无关）', () {
      final result = parseGradeHtml(normalGradeHtml);
      expect(result, isA<GradeParseSuccess>());
      final records = (result as GradeParseSuccess).records;
      expect(records, hasLength(2));
      // 列被打乱，仍按字段名取到正确值
      expect(records[0].kch, '100101');
      expect(records[0].kcmc, '系统解剖学');
      expect(records[0].sfxwkc, '是');
      expect(records[1].kcmc, '组织学与胚胎学');
      expect(records[1].sfxwkc, '否');
      // 缺失列（如 jd）清洗后为空字符串
      expect(records[1].jd, isEmpty);
    });

    test('污染字符 HTML 被清洗', () {
      final result = parseGradeHtml(pollutedGradeHtml);
      expect(result, isA<GradeParseSuccess>());
      final record = (result as GradeParseSuccess).records.single;
      expect(record.kcmc, '系统解剖学');
      expect(record.sfxwkc, '是');
    });

    test('找不到 #tabGrid 返回 noTable 失败信号', () {
      final result = parseGradeHtml(noTableHtml);
      expect(result, isA<GradeParseFailure>());
      expect(
        (result as GradeParseFailure).reason,
        GradeParseFailureReason.noTable,
      );
    });

    test('结构合法但无数据行返回成功且 0 条记录（区别于 noTable）', () {
      final result = parseGradeHtml(emptyTableHtml);
      expect(result, isA<GradeParseSuccess>());
      expect((result as GradeParseSuccess).records, isEmpty);
    });
  });

  group('两条路径语义一致性', () {
    test('JSON 与 HTML 同一条记录清洗后字段一致', () {
      final fromJson = parseJqGridJson(pollutedJqGridRows);
      final fromHtml = parseGradeHtml(pollutedGradeHtml);
      final j = (fromJson as GradeParseSuccess).records.single;
      final h = (fromHtml as GradeParseSuccess).records.single;
      expect(j.kch, h.kch);
      expect(j.kcmc, h.kcmc);
      expect(j.sfxwkc, h.sfxwkc);
    });
  });
}
