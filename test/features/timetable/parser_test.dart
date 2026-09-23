import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/features/timetable/parser.dart';
import 'package:zfjw_toolkit/features/timetable/diff.dart';
import 'package:zfjw_toolkit/features/timetable/model.dart';

void main() {
  test('实页脱敏样本全部解析，不遗漏155个安排块', () {
    final payload =
        jsonDecode(
              File(
                'test/features/timetable/fixtures/live_capture_anonymized.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final result = parseTimetablePayload(payload);
    expect((payload['rows'] as List), hasLength(155));
    expect(result.sessions.length, greaterThanOrEqualTo(155));
    expect(result.sessions.map((s) => s.day).toSet(), {1, 2, 3, 4, 5, 6, 7});
    expect(result.sessions.any((s) => s.type == '见习'), isTrue);
    expect(result.sessions.any((s) => s.start == 11 && s.end == 13), isTrue);
  });
  Map<String, dynamic> payload(String time) => {
    'status': 'ok',
    'term': '2026/3',
    'label': '2026–2027 第1学期',
    'rows': [
      {
        'title': '【调】内科学★',
        'time': time,
        'day': 1,
        'teacher': '教师甲',
        'location': '教室一',
      },
    ],
  };
  test('跨周展开为课次，连堂课不拆分，解析教学类型和调课', () {
    final data = parseTimetablePayload(payload('(1-2节)2-8周'));
    expect(data.sessions, hasLength(7));
    expect(data.sessions.first.name, '内科学');
    expect(data.sessions.first.type, '讲课');
    expect(data.sessions.first.rawTime, '(1-2节)2-8周');
    expect(data.sessions.first.adjusted, isTrue);
    expect(data.sessions.first.end, 2);
  });
  test('未知教学类型符号独立保留，不污染课程名称', () {
    final p = payload('(1-2节)2周');
    (p['rows'] as List).first['title'] = '内科学☆';
    final session = parseTimetablePayload(p).sessions.single;
    expect(session.name, '内科学');
    expect(session.teachingType?.symbol, '☆');
    expect(session.teachingType?.known, isFalse);
    expect(session.rawTitle, '内科学☆');
  });
  test('单双周与离散周严格解析，残缺不能静默遗漏', () {
    expect(parseWeeks('1-7周(单),10周'), [1, 3, 5, 7, 10]);
    expect(() => parseWeeks('1-7周,未知'), throwsFormatException);
    expect(
      () => parseTimetablePayload(payload('(1-2节)待定')),
      throwsFormatException,
    );
  });
  test('必须明确无课才能接受空结果', () {
    final p = payload('');
    p['rows'] = [];
    expect(() => parseTimetablePayload(p), throwsFormatException);
    p['explicitEmpty'] = true;
    expect(parseTimetablePayload(p).sessions, isEmpty);
  });
  ClassSession session(int week, {String room = '甲', bool adjusted = false}) =>
      ClassSession(
        name: '课程',
        week: week,
        day: 1,
        start: 1,
        end: 2,
        teachingType: TeachingType.lecture,
        location: room,
        adjusted: adjusted,
      );
  test('中间取消不导致后续课次序号配错', () {
    final changes = diffTimetable(
      [session(1), session(2), session(3)],
      [session(1), session(3)],
    );
    expect(changes, hasLength(1));
    expect(changes.single.before!.week, 2);
    expect(changes.single.after, isNull);
  });
  test('单次教室变化和调课标记变化均可识别', () {
    final changes = diffTimetable(
      [session(1)],
      [session(1, room: '乙', adjusted: true)],
    );
    expect(changes, hasLength(1));
    expect(changes.single.description, contains('地点：甲 → 乙'));
    expect(changes.single.description, contains('平台调课标记'));
  });
  test('多次同名课程整体移动时按时间顺序配对', () {
    final changes = diffTimetable(
      [session(1), session(2)],
      [session(3), session(4)],
    );
    expect(changes, hasLength(2));
    expect(changes.every((c) => c.before != null && c.after != null), isTrue);
    expect(changes.map((c) => c.before!.week), [1, 2]);
    expect(changes.map((c) => c.after!.week), [3, 4]);
  });
  test('无变化与输入顺序无关，保留重复记录数量', () {
    expect(
      timetableFingerprint([session(1), session(2)]),
      timetableFingerprint([session(2), session(1)]),
    );
    expect(diffTimetable([session(1), session(1)], [session(1)]), hasLength(1));
  });
  test('作息正确覆盖昼夜三个时段', () {
    expect(periodTime(5, end: true), '12:00');
    expect(periodTime(6), '14:00');
    expect(periodTime(13, end: true), '21:20');
    expect(periodTime(16, end: true), '23:50');
  });
}
