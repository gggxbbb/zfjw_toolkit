import 'package:html/parser.dart' show parse;

import '../model/course_record.dart';
import 'grade_parse_result.dart';

/// 正方成绩页解析器（纯 Dart，零 Flutter 依赖）。
///
/// 两条采集路径统一为 [CourseRecord] 列表：
/// - [parseJqGridJson]：WebView 注入 JS 拿到的 jqGrid 原始 `data` 数组；
/// - [parseGradeHtml]：离线存档/文件导入的完整 HTML 文档，回退 DOM 解析。
///
/// 两条路径均按字段名（JSON 键 / `aria-describedby`）取值，与列顺序无关；
/// 文本字段在 [CourseRecord.fromJson] 内统一清洗（剥除 Cf/Zs 不可见字符）。

/// 解析 jqGrid 原始 JSON 数组 → [CourseRecord] 列表。
///
/// 字段完整性校验：数组非空且首行须同时含 `sfxwkc` 与 `bfzcj` 键；
/// 缺列说明该网格原始数据未携带学位/百分制字段（仅由 formatter 渲染进
/// DOM），返回 [GradeParseFailureReason.incompleteColumns]，调用方应回退
/// 到 [parseGradeHtml]。
///
/// 数组为空或所有行均非有效行时返回成功但 0 条记录。
GradeParseResult parseJqGridJson(List<Map<String, dynamic>> data) {
  if (data.isNotEmpty) {
    final first = data.first;
    if (!first.containsKey('sfxwkc') || !first.containsKey('bfzcj')) {
      return const GradeParseFailure(GradeParseFailureReason.incompleteColumns);
    }
  }
  return GradeParseSuccess(_rowsFromRaw(data));
}

/// 解析完整成绩页 HTML → [CourseRecord] 列表。
///
/// 取 `#tabGrid tr.jqgrow` 行，按每个 `td` 的 `aria-describedby`
///（`tabGrid_<字段名>`）取列名与值，与列顺序/列隐藏无关。
///
/// 失败语义区分：
/// - 文档中不存在 `#tabGrid` → [GradeParseFailureReason.noTable]（结构不符）；
/// - `#tabGrid` 存在但无 `tr.jqgrow` 行 → 成功且 0 条记录（页面无数据）。
GradeParseResult parseGradeHtml(String html) {
  final document = parse(html);
  final grid = document.querySelector('#tabGrid');
  if (grid == null) {
    return const GradeParseFailure(GradeParseFailureReason.noTable);
  }
  final rows = grid.querySelectorAll('tr.jqgrow');
  final rawRows = rows.map((tr) {
    final raw = <String, dynamic>{};
    for (final td in tr.querySelectorAll('td')) {
      final describedBy = td.attributes['aria-describedby'];
      if (describedBy == null || !describedBy.startsWith('tabGrid_')) continue;
      final key = describedBy.substring('tabGrid_'.length);
      raw[key] = td.text;
    }
    return raw;
  });
  return GradeParseSuccess(_rowsFromRaw(rawRows));
}

/// 由原始字段表（JSON 行或 HTML 单元格）构造有效 [CourseRecord] 列表。
///
/// 行有效性：`kch` 或 `kcmc` 存在才算有效行（对齐油猴 `row.kch || row.kcmc`）。
/// [CourseRecord.fromJson] 内部完成文本清洗，故污染字符（U+200B/U+00A0 等）
/// 在构造阶段即被剥除。
List<CourseRecord> _rowsFromRaw(Iterable<Map<String, dynamic>> rawRows) {
  final records = <CourseRecord>[];
  for (final raw in rawRows) {
    final record = CourseRecord.fromJson(raw);
    final hasKey = record.kch != null && record.kch!.isNotEmpty;
    final hasName = record.kcmc != null && record.kcmc!.isNotEmpty;
    if (hasKey || hasName) records.add(record);
  }
  return records;
}
