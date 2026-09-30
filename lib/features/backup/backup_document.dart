import 'dart:convert';

/// Versioned, explicit export boundary. Never includes arbitrary preferences,
/// database internals or WebView authentication state.
class BackupDocument {
  BackupDocument._(this.json);
  static const format = 'zfjw-toolkit-backup';
  static const version = 1;
  static const sections = ['profiles', 'snapshots', 'terms', 'versions'];
  static const preferenceKeys = [
    'teaching_plan',
    'record_overrides',
    'plan_overrides',
    'jwgpa.targetGPA',
    'jwgpa.targetGPA.degree',
    'jwgpa.minGPA.all',
    'jwgpa.minGPA.degree',
    'jwgpa.feature_flags.timetable',
  ];
  final Map<String, dynamic> json;
  Map<String, dynamic> get data => json['data'] as Map<String, dynamic>;
  Map<String, dynamic> get preferences =>
      data['preferences'] as Map<String, dynamic>;
  List<Map<String, dynamic>> rows(String section) =>
      (data[section] as List).cast<Map<String, dynamic>>();
  String encode() => const JsonEncoder.withIndent('  ').convert(json);

  factory BackupDocument.create(Map<String, dynamic> data, String appVersion) =>
      BackupDocument.parse(
        jsonEncode({
          'format': format,
          'version': version,
          'exportedAt': DateTime.now().toUtc().toIso8601String(),
          'appVersion': appVersion,
          'data': data,
        }),
      );

  factory BackupDocument.parse(String text) {
    final root = _map(jsonDecode(text), '备份');
    if (root['format'] != format) _bad('不是本应用的完整备份');
    if (root['version'] != version || root['version'] is! int) {
      _bad('不支持的备份版本，请使用兼容版本的应用');
    }
    _date(root['exportedAt'], '导出时间');
    _string(root['appVersion'], '应用版本', nonempty: true);
    final data = _map(root['data'], '数据');
    _keys(data, [...sections, 'preferences'], '数据');
    for (final section in sections) {
      final ids = <String>{};
      for (final row in _list(data[section], section)) {
        final item = _map(row, section);
        final id = _string(item['id'], '$section.id', nonempty: true);
        if (!ids.add(id)) _bad('$section 中有重复 ID：$id');
      }
    }
    final profiles = (data['profiles'] as List).cast<Map<String, dynamic>>();
    final profileIds = profiles.map((p) => p['id']).toSet();
    for (final p in profiles) {
      _keys(p, ['id', 'name', 'createdAt', 'rulePreset'], '档案');
      _string(p['name'], '档案名称');
      p['createdAt'] = _storedTimestamp(p['createdAt'], '档案创建时间');
      if (p['rulePreset'] != 'xzhmu') _bad('不支持的成绩规则包');
    }
    for (final s in data['snapshots'] as List) {
      _keys(s, ['id', 'profileId', 'source', 'capturedAt', 'records'], '成绩快照');
      if (!profileIds.contains(s['profileId'])) _bad('成绩快照引用了不存在的档案');
      if (!['webview', 'file', 'manual'].contains(s['source'])) _bad('无效的采集来源');
      s['capturedAt'] = _storedTimestamp(s['capturedAt'], '成绩采集时间');
      for (final r in _list(s['records'], '成绩记录')) {
        _record(r);
      }
    }
    final terms = (data['terms'] as List).cast<Map<String, dynamic>>();
    final termIds = terms.map((t) => t['id']).toSet();
    for (final t in terms) {
      _keys(t, ['id', 'label', 'monday', 'weeks', 'checkedAt'], '课表学期');
      _string(t['label'], '学期名称', nonempty: true);
      final monday = _date(t['monday'], '开学日期');
      if (monday.weekday != DateTime.monday) _bad('开学日期必须是周一');
      if (monday.isUtc ||
          monday.hour != 0 ||
          monday.minute != 0 ||
          monday.second != 0 ||
          monday.millisecond != 0 ||
          monday.microsecond != 0) {
        _bad('开学日期须为本地周一零点');
      }
      _integer(t['weeks'], '学期周数', 1, 60);
      t['checkedAt'] = _storedTimestamp(t['checkedAt'], '课表检查时间');
    }
    for (final v in data['versions'] as List) {
      _keys(v, ['id', 'term', 'capturedAt', 'sessions'], '课表快照');
      if (!termIds.contains(v['term'])) _bad('课表快照引用了不存在的学期');
      v['capturedAt'] = _storedTimestamp(v['capturedAt'], '课表采集时间');
      for (final value in _list(v['sessions'], '课次')) {
        final s = _map(value, '课次');
        _keys(s, [
          'name',
          'week',
          'day',
          'start',
          'end',
          'teachingType',
          'teacher',
          'location',
          'adjusted',
          'rawTitle',
          'rawTime',
          'group',
        ], '课次');
        _string(s['name'], '课程名称', nonempty: true);
        for (final k in [
          'teacher',
          'location',
          'rawTitle',
          'rawTime',
          'group',
        ]) {
          _string(s[k], '课次.$k');
        }
        _integer(s['week'], '周次', 1, 60);
        _integer(s['day'], '星期', 1, 7);
        _integer(s['start'], '开始节次', 1, 100);
        _integer(s['end'], '结束节次', s['start'] as int, 100);
        if (s['adjusted'] is! bool) _bad('无效的课表标记');
        if (s['teachingType'] != null) {
          final type = _map(s['teachingType'], '教学类型');
          _keys(type, ['symbol', 'label', 'known'], '教学类型');
          _string(type['symbol'], '教学类型符号');
          _string(type['label'], '教学类型名称');
          if (type['known'] is! bool) _bad('无效的教学类型标记');
        }
      }
    }
    final prefs = _map(data['preferences'], '设置');
    _keys(prefs, preferenceKeys, '设置');
    for (final key in preferenceKeys) {
      final value = prefs[key];
      if (value == null) continue;
      if (key.startsWith('jwgpa.feature_flags.')) {
        if (value is! bool) _bad('功能开关必须为布尔值');
      } else if (key.startsWith('jwgpa.')) {
        _number(value, key);
      } else if (key == 'teaching_plan') {
        final p = _map(value, '教学计划');
        _keys(p, ['programName', 'graduationCredits', 'courses'], '教学计划');
        _string(p['programName'], '培养方案名称');
        _number(p['graduationCredits'], '毕业学分');
        for (final c in _list(p['courses'], '计划课程')) {
          _planned(c);
        }
      } else {
        _overrides(_map(value, key), plan: key == 'plan_overrides');
      }
    }
    return BackupDocument._(root);
  }
}

/// Stable comparison ignores JSON object key order, but preserves list order.
String canonicalJson(Object? value) => jsonEncode(_canonical(value));
Object? _canonical(Object? value) {
  if (value is Map) {
    return {
      for (final k in value.keys.cast<String>().toList()..sort())
        k: _canonical(value[k]),
    };
  }
  if (value is List) return value.map(_canonical).toList();
  if (value is num && value == value.toInt()) return value.toInt();
  return value;
}

Never _bad(String message) => throw FormatException(message);
Map<String, dynamic> _map(Object? v, String name) {
  if (v is! Map<String, dynamic>) _bad('$name 必须为对象');
  return v;
}

List<dynamic> _list(Object? v, String name) {
  if (v is! List) _bad('$name 必须为列表');
  return v;
}

String _string(Object? v, String name, {bool nonempty = false}) {
  if (v is! String || (nonempty && v.trim().isEmpty)) _bad('$name 必须为有效文本');
  return v;
}

void _keys(
  Map<String, dynamic> v,
  List<String> keys,
  String name, {
  List<String> optional = const [],
}) {
  if (keys.any((k) => !v.containsKey(k)) ||
      v.keys.any((k) => !keys.contains(k) && !optional.contains(k))) {
    _bad('$name 缺少字段或含不支持的字段');
  }
}

DateTime _date(Object? v, String name) {
  final s = _string(v, name, nonempty: true);
  final parsed = DateTime.tryParse(s);
  if (parsed == null ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(s) ||
      parsed.year < 1900 ||
      parsed.year > 2200) {
    _bad('$name 无效');
  }
  // DateTime.parse otherwise normalizes impossible calendar dates silently.
  final rawDate = s.substring(0, 10);
  final dateOnly = DateTime.tryParse(rawDate);
  if (dateOnly == null ||
      dateOnly.toIso8601String().substring(0, 10) != rawDate) {
    _bad('$name 无效');
  }
  final time = RegExp(
    r'T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})?$',
  ).firstMatch(s);
  if (time == null ||
      int.parse(time[1]!) > 23 ||
      int.parse(time[2]!) > 59 ||
      int.parse(time[3]!) > 59) {
    _bad('$name 无效');
  }
  return parsed;
}

String _storedTimestamp(Object? value, String name) {
  final date = _date(value, name);
  if (date.millisecond != 0 || date.microsecond != 0) {
    _bad('$name 须使用数据库支持的秒精度');
  }
  return date.toUtc().toIso8601String();
}

void _integer(Object? v, String name, int min, int max) {
  if (v is! int || v < min || v > max) _bad('$name 超出有效范围');
}

void _number(Object? v, String name) {
  if (v is! num || !v.isFinite || v < 0) _bad('$name 必须为非负数');
}

const recordFields = [
  'kch',
  'kcmc',
  'xf',
  'jd',
  'bfzcj',
  'cj',
  'cjbz',
  'sfxwkc',
  'xnm',
  'xqm',
  'xnmmc',
  'xqmmc',
];
void _record(Object? value) {
  final r = _map(value, '成绩记录');
  _keys(r, recordFields, '成绩记录');
  for (final k in recordFields) {
    if (r[k] != null) _string(r[k], '成绩.$k');
  }
}

void _planned(Object? value) {
  final c = _map(value, '计划课程');
  _keys(c, [
    'code',
    'name',
    'credits',
    'suggestedYear',
    'suggestedTerm',
    'sfxwkc',
  ], '计划课程');
  for (final k in [
    'code',
    'name',
    'suggestedYear',
    'suggestedTerm',
    'sfxwkc',
  ]) {
    _string(c[k], '计划课程.$k');
  }
  _number(c['credits'], '课程学分');
}

void _overrides(Map<String, dynamic> value, {required bool plan}) {
  _keys(
    value,
    ['patches', 'additions'],
    '手动修改',
    optional: plan ? ['programName', 'graduationCredits'] : [],
  );
  if (value.containsKey('programName')) _string(value['programName'], '培养方案名称');
  if (value.containsKey('graduationCredits')) {
    _number(value['graduationCredits'], '毕业学分');
  }
  for (final a in _list(value['additions'], '手动新增')) {
    if (plan) {
      _planned(a);
    } else {
      _record(a);
    }
  }
  final ids = <String>{};
  for (final item in _list(value['patches'], '手动修改')) {
    final p = _map(item, '修改');
    final fields = plan
        ? ['credits', 'sfxwkc', 'suggestedYear', 'suggestedTerm']
        : ['cj', 'bfzcj', 'xf', 'jd', 'sfxwkc'];
    _keys(
      p,
      plan ? ['key', 'deleted'] : ['courseKey', 'xnm', 'xqm', 'deleted'],
      '修改',
      optional: fields,
    );
    _string(p[plan ? 'key' : 'courseKey'], '课程标识', nonempty: true);
    if (!plan) {
      _string(p['xnm'], '学年');
      _string(p['xqm'], '学期');
    }
    final id = canonicalJson(
      plan ? p['key'] : [p['courseKey'], p['xnm'], p['xqm']],
    );
    if (!ids.add(id)) _bad('重复的课程修改');
    if (p['deleted'] is! bool) _bad('删除标记必须为布尔值');
    for (final k in fields) {
      if (!p.containsKey(k)) continue;
      if (k == 'credits') {
        _number(p[k], '学分');
      } else {
        _string(p[k], '修改.$k');
      }
    }
  }
}
