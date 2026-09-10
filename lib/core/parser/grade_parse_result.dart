import '../model/course_record.dart';

/// 成绩解析结果：成功携带 [CourseRecord] 列表，失败携带可区分的失败原因。
///
/// 与油猴 `parseRows` 对齐——两条解析路径（jqGrid 原始 JSON / 成绩页 HTML）
/// 都返回此类型，调用方据此决定回退或直接展示。
sealed class GradeParseResult {
  const GradeParseResult();
}

/// 解析成功。可能含 0 条记录（页面无数据，但结构合法）。
final class GradeParseSuccess extends GradeParseResult {
  final List<CourseRecord> records;

  const GradeParseSuccess(this.records);
}

/// 解析失败，结构或字段不符合预期。
final class GradeParseFailure extends GradeParseResult {
  final GradeParseFailureReason reason;

  const GradeParseFailure(this.reason);
}

/// 失败原因，供调用方区分并选择回退策略。
enum GradeParseFailureReason {
  /// jqGrid 原始 JSON 首行缺失 `sfxwkc`/`bfzcj` 列——仅由 formatter 渲染进
  /// DOM，此时应回退到 HTML/DOM 解析路径。
  incompleteColumns,

  /// HTML 文档中找不到 `#tabGrid`（结构不符），无法解析。
  noTable;

  /// 面向用户的中文说明。
  String get label => switch (this) {
        GradeParseFailureReason.incompleteColumns => '页面缺少成绩列（sfxwkc/bfzcj），无法解析',
        GradeParseFailureReason.noTable => '未找到成绩表格（#tabGrid）',
      };
}
