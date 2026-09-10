import '../model/course_record.dart';

/// 规则包抽象接口：一套学校特定的计算规则集合。
///
/// 首发内置徐医规则包（见 [XzhmuRulePreset]）。新增学校只需实现本接口，
/// 统计层与 UI 层经由该接口协作，无需感知具体规则。
abstract class RulePreset {
  const RulePreset();

  /// 预设标识（如 `'xzhmu'`），用于持久化与设置展示。
  String get id;

  /// 单条记录的绩点：官方 jd 优先，缺失回退校规公式。
  double? gradePoint(CourseRecord record);

  /// 是否学位课程（参与学位 GPA）。
  bool isDegreeCourse(CourseRecord record);

  /// 是否免修（学分认定，非考试结果，不参与成绩统计）。
  bool isExempt(CourseRecord record);

  /// 是否通过（合格）。语义：jd>0 → 分数≥60 → 等级文本匹配。
  bool isPass(CourseRecord record);

  /// 同一课程多次修读去重，返回有效记录列表（顺序保持首次出现）。
  List<CourseRecord> dedupe(List<CourseRecord> records);
}
