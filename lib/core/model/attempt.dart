import 'course_record.dart';

/// 同一课程的一次修读（初修/重修/补考各算一条 Attempt）。
///
/// 包装一条 [CourseRecord]，并携带其在同课程多次修读中的次序 [index]，
/// 供规则引擎的「修读去重」与统计层使用。
class Attempt {
  final CourseRecord record;

  /// 该课程内的修读次序：1 = 初修，2+ = 重修/补考。由去重聚合层填充。
  final int index;

  const Attempt(this.record, {this.index = 1});

  String get courseKey => record.courseKey;
  String? get courseName => record.kcmc;
  double? get numericScore => record.numericScore;

  @override
  String toString() => 'Attempt(index: $index, record: $record)';
}
