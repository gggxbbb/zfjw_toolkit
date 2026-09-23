import 'model.dart';

final teachingSymbols = {
  for (final type in TeachingType.values) type.symbol: type,
};

final _unknownTeachingSymbol = RegExp(r'[\u25a0-\u27ff]$');

/// 严格解析完整周次表达式，不能只截取成功匹配的部分。
List<int> parseWeeks(String raw) {
  var text = raw
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('，', ',')
      .replaceAll('、', ',');
  final weeks = <int>{};
  for (var part in text.split(',')) {
    if (part.isEmpty) throw FormatException('无法解析周次：$raw');
    final match = RegExp(
      r'^(\d+)(?:-(\d+))?(?:周)?(?:\(([单双])(?:周)?\))?$',
    ).firstMatch(part);
    if (match == null) throw FormatException('无法解析周次：$raw');
    final first = int.parse(match[1]!);
    final last = int.parse(match[2] ?? match[1]!);
    if (first < 1 || last < first || last > 60) {
      throw FormatException('周次范围无效：$raw');
    }
    for (var w = first; w <= last; w++) {
      if (match[3] == null || (match[3] == '单' ? w.isOdd : w.isEven)) {
        weeks.add(w);
      }
    }
  }
  if (weeks.isEmpty) throw FormatException('周次为空：$raw');
  return weeks.toList()..sort();
}

TimetableCapture parseTimetablePayload(Map<String, dynamic> payload) {
  if (payload['status'] != 'ok') {
    throw FormatException(payload['message']?.toString() ?? '课表未完整加载');
  }
  final term = payload['term']?.toString() ?? '';
  final label = payload['label']?.toString() ?? '';
  if (term.isEmpty || label.isEmpty) throw const FormatException('缺少学期信息');
  final rows = payload['rows'];
  if (rows is! List || (rows.isEmpty && payload['explicitEmpty'] != true)) {
    throw const FormatException('未找到课次，且页面未明确显示无课');
  }
  final sessions = <ClassSession>[];
  final failures = <String>[];
  for (final raw in rows) {
    try {
      if (raw is! Map) throw const FormatException('课次结构无效');
      final title = raw['title']?.toString().trim() ?? '';
      var name = title.replaceAll('【调】', '').trim();
      TeachingType? teachingType;
      for (final entry in teachingSymbols.entries) {
        if (name.endsWith(entry.key)) {
          teachingType = entry.value;
          name = name.substring(0, name.length - entry.key.length).trim();
          break;
        }
      }
      if (teachingType == null) {
        final symbol = _unknownTeachingSymbol.stringMatch(name);
        if (symbol != null) {
          teachingType = TeachingType(symbol, '未知类型 $symbol', known: false);
          name = name.substring(0, name.length - symbol.length).trim();
        }
      }
      final time = raw['time']?.toString().trim() ?? '';
      final match = RegExp(
        r'^[（(](\d+)(?:-(\d+))?节[）)]\s*(.+)$',
      ).firstMatch(time);
      final day = int.tryParse('${raw['day']}');
      if (name.isEmpty || match == null || day == null || day < 1 || day > 7) {
        throw FormatException('无法解析课程、星期或节次：$title $time');
      }
      final start = int.parse(match[1]!);
      final end = int.parse(match[2] ?? match[1]!);
      if (start < 1 || end < start || end > 16) {
        throw FormatException('节次范围无效：$title $time');
      }
      for (final week in parseWeeks(match[3]!)) {
        sessions.add(
          ClassSession(
            name: name,
            week: week,
            day: day,
            start: start,
            end: end,
            teachingType: teachingType,
            teacher: '${raw['teacher'] ?? ''}'.trim(),
            location: '${raw['location'] ?? ''}'.trim(),
            group: '${raw['group'] ?? ''}'.trim(),
            adjusted: title.contains('【调】'),
            rawTitle: title,
            rawTime: time,
          ),
        );
      }
    } on FormatException catch (e) {
      failures.add(e.message);
    }
  }
  if (failures.isNotEmpty) throw FormatException(failures.join('\n'));
  sessions.sort(compareSessions);
  return TimetableCapture(term, label, sessions);
}
