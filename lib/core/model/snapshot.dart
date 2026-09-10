import 'course_record.dart';

/// 成绩快照来源。
enum SnapshotSource {
  /// WebView 注入采集（主路径）。
  webview,

  /// HTML/文件导入。
  file,

  /// 手动编辑录入。
  manual,
}

/// 某次采集得到的完整成绩记录集合，携带来源与时间戳。
///
/// 档案可持有多个快照；当前单档案，但存储按多档案设计。
class Snapshot {
  final String id;
  final SnapshotSource source;
  final DateTime capturedAt;
  final List<CourseRecord> records;

  const Snapshot({
    required this.id,
    required this.source,
    required this.capturedAt,
    required this.records,
  });

  Snapshot copyWith({
    String? id,
    SnapshotSource? source,
    DateTime? capturedAt,
    List<CourseRecord>? records,
  }) =>
      Snapshot(
        id: id ?? this.id,
        source: source ?? this.source,
        capturedAt: capturedAt ?? this.capturedAt,
        records: records ?? this.records,
      );

  @override
  String toString() =>
      'Snapshot(id: $id, source: $source, capturedAt: $capturedAt, '
      'records: ${records.length})';
}
