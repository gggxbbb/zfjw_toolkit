import 'dart:convert';
import 'dart:typed_data';
import '../../core/model/course_record.dart';
import '../../data/database.dart';
import 'backup_document.dart';

Uint8List gradesCsv(List<CourseRecord> records) {
  const headers = [
    '课程代码',
    '课程名称',
    '学分',
    '绩点',
    '百分制成绩',
    '成绩',
    '成绩备注',
    '是否学位课',
    '学年码',
    '学期码',
    '学年名称',
    '学期名称',
  ];
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    // Spreadsheet programs can evaluate formulas even inside quoted CSV cells.
    if (RegExp(r'^\s*[=+@\-]').hasMatch(text) && num.tryParse(text) == null) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  final lines = <String>[
    headers.map(cell).join(','),
    for (final record in records)
      recordFields
          .map((key) => cell(courseRecordToJson(record)[key]))
          .join(','),
  ];
  return Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\r\n')}\r\n'));
}
