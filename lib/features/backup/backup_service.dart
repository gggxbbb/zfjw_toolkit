import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database.dart';
import 'backup_document.dart';

abstract interface class BackupPreferences {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> values);
}

class LocalBackupPreferences implements BackupPreferences {
  @override
  Future<Map<String, dynamic>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final key in BackupDocument.preferenceKeys)
        key: _decode(key, prefs.get(key)),
    };
  }

  Object? _decode(String key, Object? value) =>
      !key.startsWith('jwgpa.') && value is String ? jsonDecode(value) : value;

  @override
  Future<void> write(Map<String, dynamic> values) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in BackupDocument.preferenceKeys) {
      final value = values[key];
      final success = value == null
          ? await prefs.remove(key)
          : value is bool
          ? await prefs.setBool(key, value)
          : value is num
          ? await prefs.setDouble(key, value.toDouble())
          : await prefs.setString(key, jsonEncode(value));
      if (!success) throw StateError('保存失败：$key');
    }
  }
}

class ImportPreview {
  ImportPreview(
    this.incoming,
    this.local,
    this.merged,
    this.conflicts,
    this.added,
    this.skipped,
  );
  final BackupDocument incoming, local, merged;
  final List<String> conflicts;
  final Map<String, int> added, skipped;
  bool get canMerge => conflicts.isEmpty;
}

/// SQLite commit marker and compensating preference journal form one recovery
/// boundary. No consumers are started until [recover] has completed.
class BackupService {
  BackupService(this.db, this.preferences);
  final AppDatabase db;
  final BackupPreferences preferences;
  bool _busy = false;

  static const _tables = {
    'profiles': (
      'profiles',
      {
        'id': 'id',
        'name': 'name',
        'createdAt': 'created_at',
        'rulePreset': 'rule_preset',
      },
    ),
    'snapshots': (
      'snapshots',
      {
        'id': 'id',
        'profileId': 'profile_id',
        'source': 'source',
        'capturedAt': 'captured_at',
        'records': 'records',
      },
    ),
    'terms': (
      'timetable_terms',
      {
        'id': 'id',
        'label': 'label',
        'monday': 'monday',
        'weeks': 'weeks',
        'checkedAt': 'checked_at',
      },
    ),
    'versions': (
      'timetable_versions',
      {
        'id': 'id',
        'term': 'term',
        'capturedAt': 'captured_at',
        'sessions': 'sessions',
      },
    ),
  };
  static const _dates = ['createdAt', 'capturedAt', 'monday', 'checkedAt'];
  static const _jsonFields = ['records', 'sessions'];

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_busy) throw StateError('数据操作正在进行，请稍后重试');
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }

  Future<BackupDocument> export(String appVersion) => _exclusive(() async {
    await _recover();
    return _export(appVersion);
  });

  Future<BackupDocument> _export(String appVersion) => db.transaction(() async {
    final data = <String, dynamic>{};
    for (final entry in _tables.entries) {
      final rows = await db
          .customSelect('SELECT * FROM ${entry.value.$1} ORDER BY rowid')
          .get();
      data[entry.key] = [
        for (final row in rows)
          {
            for (final field in entry.value.$2.entries)
              field.key: _dates.contains(field.key)
                  ? DateTime.fromMillisecondsSinceEpoch(
                      (row.data[field.value] as int) * 1000,
                    ).toIso8601String()
                  : _jsonFields.contains(field.key)
                  ? jsonDecode(row.data[field.value] as String)
                  : row.data[field.value],
          },
      ];
    }
    data['preferences'] = await preferences.read();
    return BackupDocument.create(data, appVersion);
  });

  Future<ImportPreview> preview(BackupDocument incoming) =>
      _exclusive(() async {
        await _recover();
        return _preview(incoming, await _export('preview'));
      });

  ImportPreview _preview(BackupDocument incoming, BackupDocument local) {
    final conflicts = <String>[];
    final added = <String, int>{}, skipped = <String, int>{};
    final merged = <String, dynamic>{};
    const labels = {
      'profiles': '档案',
      'snapshots': '成绩快照',
      'terms': '课表学期',
      'versions': '课表快照',
    };
    for (final section in BackupDocument.sections) {
      added[section] = 0;
      skipped[section] = 0;
      final rows = {for (final row in local.rows(section)) row['id']: row};
      for (final row in incoming.rows(section)) {
        final existing = rows[row['id']];
        if (existing == null) {
          rows[row['id']] = row;
          added[section] = added[section]! + 1;
        } else if (_sameRow(existing, row)) {
          skipped[section] = skipped[section]! + 1;
        } else {
          conflicts.add('${labels[section]} ${row['id']} 内容不同');
        }
      }
      merged[section] = rows.values.toList();
    }
    final prefs = Map<String, dynamic>.from(local.preferences);
    const prefLabels = {
      'teaching_plan': '教学计划',
      'record_overrides': '成绩修改',
      'plan_overrides': '教学计划修改',
      'jwgpa.targetGPA': '总 GPA 目标',
      'jwgpa.targetGPA.degree': '学位 GPA 目标',
      'jwgpa.minGPA.all': '总 GPA 最低要求',
      'jwgpa.minGPA.degree': '学位 GPA 最低要求',
      'jwgpa.feature_flags.timetable': '课表功能开关',
    };
    for (final key in BackupDocument.preferenceKeys) {
      final value = incoming.preferences[key];
      if (value == null) continue;
      if (prefs[key] == null) {
        prefs[key] = value;
      } else if (canonicalJson(prefs[key]) != canonicalJson(value)) {
        conflicts.add('${prefLabels[key]}与本机不同');
      }
    }
    merged['preferences'] = prefs;
    return ImportPreview(
      incoming,
      local,
      BackupDocument.create(merged, 'merge'),
      conflicts,
      added,
      skipped,
    );
  }

  bool _sameRow(Map<String, dynamic> a, Map<String, dynamic> b) {
    Map<String, dynamic> normalize(Map<String, dynamic> row) => {
      for (final e in row.entries)
        e.key: _dates.contains(e.key)
            ? DateTime.parse(e.value as String).millisecondsSinceEpoch
            : e.value,
    };
    return canonicalJson(normalize(a)) == canonicalJson(normalize(b));
  }

  Future<void> restore(
    ImportPreview preview, {
    required bool replace,
  }) => _exclusive(() async {
    await _recover();
    final current = await _export('check');
    if (canonicalJson(current.data) != canonicalJson(preview.local.data)) {
      throw StateError('本机数据已变化，请重新选择备份并核对预览');
    }
    // Revalidate at the write boundary; callers cannot bypass the codec.
    final incoming = BackupDocument.parse(preview.incoming.encode());
    final checked = _preview(incoming, current);
    if (!replace && !checked.canMerge) throw StateError('存在冲突，无法合并');
    final target = replace ? incoming : checked.merged;
    await db.customStatement(
      'INSERT INTO backup_restore_journal (id, committed, before_json, after_json) VALUES (1, 0, ?, ?)',
      [jsonEncode(current.preferences), jsonEncode(target.preferences)],
    );
    try {
      await db.transaction(() async {
        await _replaceRows(target);
        await preferences.write(target.preferences);
        await db.customStatement(
          'UPDATE backup_restore_journal SET committed = 1 WHERE id = 1',
        );
        // Journal cleanup is part of the same commit. If cleanup fails, SQL
        // rolls back and the prepared journal still restores old preferences.
        await db.customStatement(
          'DELETE FROM backup_restore_journal WHERE id = 1',
        );
      });
    } catch (_) {
      // SQLite rolled back. Leave the durable journal if compensation fails.
      await _recover();
      rethrow;
    }
  });

  Future<void> _replaceRows(BackupDocument target) async {
    for (final section in ['snapshots', 'versions', 'profiles', 'terms']) {
      await db.customStatement('DELETE FROM ${_tables[section]!.$1}');
    }
    for (final entry in _tables.entries) {
      final columns = entry.value.$2;
      for (final row in target.rows(entry.key)) {
        await db.customStatement(
          'INSERT INTO ${entry.value.$1} (${columns.values.join(', ')}) VALUES (${List.filled(columns.length, '?').join(', ')})',
          [
            for (final field in columns.keys)
              _dates.contains(field)
                  ? DateTime.parse(
                          row[field] as String,
                        ).millisecondsSinceEpoch ~/
                        1000
                  : _jsonFields.contains(field)
                  ? jsonEncode(row[field])
                  : row[field],
          ],
        );
      }
    }
  }

  Future<void> recover() => _exclusive(_recover);
  Future<void> _recover() async {
    final rows = await db
        .customSelect('SELECT * FROM backup_restore_journal WHERE id = 1')
        .get();
    if (rows.isEmpty) return;
    final row = rows.single;
    final committed = row.read<int>('committed') == 1;
    final values =
        jsonDecode(row.read<String>(committed ? 'after_json' : 'before_json'))
            as Map<String, dynamic>;
    await preferences.write(values);
    await db.customStatement('DELETE FROM backup_restore_journal WHERE id = 1');
  }
}
