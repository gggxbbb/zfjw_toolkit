import 'dart:convert';

class TeachingType {
  const TeachingType(this.symbol, this.label, {this.known = true});

  final String symbol, label;
  final bool known;

  static const lecture = TeachingType('★', '讲课');
  static const lab = TeachingType('○', '实验');
  static const practice = TeachingType('●', '实践');
  static const discussion = TeachingType('◆', '讨论');
  static const clerkship = TeachingType('※', '见习');
  static const online = TeachingType('△', '线上自学');
  static const values = [lecture, lab, practice, discussion, clerkship, online];

  factory TeachingType.fromJson(Map<String, dynamic> json) => TeachingType(
    json['symbol'] as String? ?? '',
    json['label'] as String? ?? '',
    known: json['known'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'label': label,
    'known': known,
  };
}

/// 一次上课安排；连续节次属于同一课次。
class ClassSession {
  const ClassSession({
    required this.name,
    required this.week,
    required this.day,
    required this.start,
    required this.end,
    this.teacher = '',
    this.location = '',
    this.teachingType,
    this.adjusted = false,
    this.rawTitle = '',
    this.rawTime = '',
    this.group = '',
  });

  final String name, teacher, location, rawTitle, rawTime, group;
  final TeachingType? teachingType;
  final int week, day, start, end;
  final bool adjusted;

  String get type => teachingType?.label ?? '';
  String get courseKey =>
      jsonEncode([name, teachingType?.symbol ?? '', teachingType?.label ?? '']);
  String get slotKey => '$week/$day/$start/$end';
  String get semanticKey => jsonEncode([
    name,
    teachingType?.symbol ?? '',
    teachingType?.label ?? '',
    week,
    day,
    start,
    end,
    teacher,
    location,
    adjusted,
    group,
  ]);
  String get when => '第 $week 周 周${'一二三四五六日'[day - 1]} $start–$end 节';

  Map<String, dynamic> toJson() => {
    'name': name,
    'week': week,
    'day': day,
    'start': start,
    'end': end,
    'teachingType': teachingType?.toJson(),
    'teacher': teacher,
    'location': location,
    'adjusted': adjusted,
    'rawTitle': rawTitle,
    'rawTime': rawTime,
    'group': group,
  };

  factory ClassSession.fromJson(Map<String, dynamic> j) => ClassSession(
    name: j['name'] as String,
    week: j['week'] as int,
    day: j['day'] as int,
    start: j['start'] as int,
    end: j['end'] as int,
    teachingType: j['teachingType'] is Map
        ? TeachingType.fromJson(
            Map<String, dynamic>.from(j['teachingType'] as Map),
          )
        : (j['type'] as String?)?.isNotEmpty == true
        ? TeachingType('', j['type'] as String)
        : null,
    teacher: j['teacher'] as String? ?? '',
    location: j['location'] as String? ?? '',
    adjusted: j['adjusted'] == true,
    rawTitle: j['rawTitle'] as String? ?? '',
    rawTime: j['rawTime'] as String? ?? '',
    group: j['group'] as String? ?? '',
  );
}

int lastSessionWeek(Iterable<ClassSession> sessions) =>
    sessions.fold(1, (n, s) => s.week > n ? s.week : n);

int compareSessions(ClassSession a, ClassSession b) {
  for (final pair in [
    (a.week, b.week),
    (a.day, b.day),
    (a.start, b.start),
    (a.end, b.end),
  ]) {
    final result = pair.$1.compareTo(pair.$2);
    if (result != 0) return result;
  }
  return a.semanticKey.compareTo(b.semanticKey);
}

String timetableFingerprint(List<ClassSession> sessions) =>
    jsonEncode(sessions.map((s) => s.semanticKey).toList()..sort());

class TimetableCapture {
  const TimetableCapture(this.term, this.label, this.sessions);
  final String term, label;
  final List<ClassSession> sessions;
  int get lastWeek => lastSessionWeek(sessions);
}

class TimetableSnapshot {
  const TimetableSnapshot({
    required this.id,
    required this.term,
    required this.capturedAt,
    required this.sessions,
  });
  final String id, term;
  final DateTime capturedAt;
  final List<ClassSession> sessions;
  int get lastWeek => lastSessionWeek(sessions);
}

class TimetableTerm {
  const TimetableTerm({
    required this.id,
    required this.label,
    required this.monday,
    required this.weeks,
    required this.checkedAt,
  });
  final String id, label;
  final DateTime monday, checkedAt;
  final int weeks;
  int weekAt(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final first = DateTime.utc(monday.year, monday.month, monday.day);
    return (day.difference(first).inDays / 7).floor() + 1;
  }

  DateTime dateFor(int week, int day) => DateTime(
    monday.year,
    monday.month,
    monday.day + (week - 1) * 7 + day - 1,
  );
}

/// 学校作息：上午、下午各五节，晚间从第十一节开始。
String periodTime(int period, {bool end = false}) {
  final minute = period <= 5
      ? 480 + (period - 1) * 50
      : period <= 10
      ? 840 + (period - 6) * 50
      : 1140 + (period - 11) * 50;
  final value = minute + (end ? 40 : 0);
  return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}
