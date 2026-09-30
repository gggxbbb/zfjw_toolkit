import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/data/database.dart';
import 'package:zfjw_toolkit/features/backup/backup_document.dart';
import 'package:zfjw_toolkit/features/backup/backup_service.dart';
import 'package:zfjw_toolkit/features/backup/csv_export.dart';
import 'package:zfjw_toolkit/features/timetable/model.dart';

class MemoryPreferences implements BackupPreferences {
  Map<String, dynamic> values = {
    for (final k in BackupDocument.preferenceKeys) k: null,
  };
  int? failAfter;
  @override
  Future<Map<String, dynamic>> read() async => Map.from(values);
  @override
  Future<void> write(Map<String, dynamic> next) async {
    var count = 0;
    for (final key in BackupDocument.preferenceKeys) {
      values[key] = next[key];
      if (++count == failAfter) {
        failAfter = null;
        throw StateError('injected failure');
      }
    }
  }
}

BackupDocument fixture() => BackupDocument.create({
  'profiles': [
    {
      'id': 'p',
      'name': '学生',
      'createdAt': '2026-09-01T00:00:00.000',
      'rulePreset': 'xzhmu',
    },
  ],
  'snapshots': [
    for (final source in ['webview', 'file', 'manual'])
      {
        'id': source,
        'profileId': 'p',
        'source': source,
        'capturedAt': '2026-09-02T12:00:00.000',
        'records': [
          courseRecordToJson(
            const CourseRecord(kch: '001', kcmc: '内科学', xf: '3', cj: '优秀'),
          ),
        ],
      },
  ],
  'terms': [
    {
      'id': 't',
      'label': '秋季',
      'monday': '2026-09-07T00:00:00.000',
      'weeks': 20,
      'checkedAt': '2026-09-29T12:00:00.000',
    },
  ],
  'versions': [
    {
      'id': 'v',
      'term': 't',
      'capturedAt': '2026-09-02T12:00:00.000',
      'sessions': [
        const ClassSession(
          name: '内科学',
          week: 1,
          day: 1,
          start: 1,
          end: 2,
          teachingType: TeachingType.lecture,
          teacher: '教师',
          location: '教室',
          group: '一班',
          adjusted: true,
        ).toJson(),
      ],
    },
  ],
  'preferences': {
    'teaching_plan': {
      'programName': '医学',
      'graduationCredits': 180,
      'courses': [],
    },
    'record_overrides': {
      'patches': [
        {
          'courseKey': '001',
          'xnm': '',
          'xqm': '',
          'deleted': false,
          'cj': '95',
        },
      ],
      'additions': [],
    },
    'plan_overrides': {'programName': '修改名称', 'patches': [], 'additions': []},
    'jwgpa.targetGPA': 3.5,
    'jwgpa.targetGPA.degree': 3.2,
    'jwgpa.minGPA.all': 2,
    'jwgpa.minGPA.degree': 2,
    'jwgpa.feature_flags.timetable': false,
  },
}, '1.2.0+6');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late MemoryPreferences prefs;
  late BackupService service;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    prefs = MemoryPreferences();
    service = BackupService(db, prefs);
  });
  tearDown(() => db.close());

  test('v2 migration preserves data and installs recovery journal', () async {
    final dir = await Directory.systemTemp.createTemp('backup_migration_');
    final file = File('${dir.path}/v2.sqlite');
    final original = AppDatabase(NativeDatabase(file));
    final originalService = BackupService(original, MemoryPreferences());
    await originalService.restore(
      await originalService.preview(fixture()),
      replace: true,
    );
    await original.close();
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('DROP TABLE backup_restore_journal');
    raw.execute('PRAGMA user_version = 2');
    raw.dispose();
    final migrated = AppDatabase(NativeDatabase(file));
    try {
      final output = await BackupService(
        migrated,
        MemoryPreferences(),
      ).export('test');
      expect(output.rows('snapshots'), hasLength(3));
      expect(output.rows('versions'), hasLength(1));
      expect(
        await migrated
            .customSelect('SELECT * FROM backup_restore_journal')
            .get(),
        isEmpty,
      );
    } finally {
      await migrated.close();
      await dir.delete(recursive: true);
    }
  });

  test(
    'stored history preserves nulls and literal text when exported as CSV',
    () {
      const record = CourseRecord(kcmc: '中 文\n课程', cj: '优秀');
      const converter = CourseRecordListConverter();
      final restored = converter.fromSql(converter.toSql([record])).single;
      expect(courseRecordToJson(restored), courseRecordToJson(record));
      expect(utf8.decode(gradesCsv([restored])), contains('中 文\n课程'));
    },
  );

  test(
    'complete restore/export preserves every field including disabled timetable',
    () async {
      final input = fixture();
      await service.restore(await service.preview(input), replace: true);
      final output = await service.export('test');
      expect(canonicalJson(output.data), canonicalJson(input.data));
      expect(
        (await db.customSelect('SELECT * FROM backup_restore_journal').get()),
        isEmpty,
      );
    },
  );

  test('merge is idempotent; a new snapshot is appended', () async {
    final input = fixture();
    await service.restore(await service.preview(input), replace: false);
    final repeated = await service.preview(input);
    expect(repeated.canMerge, true);
    expect(repeated.added.values.every((n) => n == 0), true);
    expect(repeated.skipped['snapshots'], 3);
    await service.restore(repeated, replace: false);
    final more = fixture();
    more.rows('snapshots').last['id'] = 'new';
    final preview = await service.preview(more);
    expect(preview.added['snapshots'], 1);
    await service.restore(preview, replace: false);
    expect((await service.export('test')).rows('snapshots'), hasLength(4));
  });

  test('same-id conflicts and settings conflicts cause zero writes', () async {
    final input = fixture();
    await service.restore(await service.preview(input), replace: true);
    final changed = fixture();
    changed.rows('profiles').first['name'] = '其他学生';
    changed.preferences['jwgpa.targetGPA'] = 4;
    final preview = await service.preview(changed);
    expect(preview.conflicts, hasLength(2));
    await expectLater(
      service.restore(preview, replace: false),
      throwsStateError,
    );
    expect(
      canonicalJson((await service.export('test')).data),
      canonicalJson(input.data),
    );
  });

  test('preview becomes invalid if local data changes', () async {
    final preview = await service.preview(fixture());
    prefs.values['jwgpa.targetGPA'] = 4;
    await expectLater(
      service.restore(preview, replace: true),
      throwsStateError,
    );
    expect((await db.select(db.profiles).get()), isEmpty);
    expect(prefs.values['jwgpa.targetGPA'], 4);
  });

  for (
    var boundary = 1;
    boundary <= BackupDocument.preferenceKeys.length;
    boundary++
  ) {
    test(
      'preference failure at $boundary rolls back SQL and preferences',
      () async {
        final before = await service.export('before');
        final preview = await service.preview(fixture());
        prefs.failAfter = boundary;
        await expectLater(
          service.restore(preview, replace: true),
          throwsStateError,
        );
        expect(
          canonicalJson((await service.export('after')).data),
          canonicalJson(before.data),
        );
      },
    );
  }

  test(
    'SQL failure after deletion preserves previous tables and settings',
    () async {
      final input = fixture();
      await service.restore(await service.preview(input), replace: true);
      await db.customStatement(
        "CREATE TRIGGER fail_snapshot BEFORE INSERT ON snapshots BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      final changed = fixture();
      changed.rows('profiles').first['name'] = 'new';
      await expectLater(
        service.restore(await service.preview(changed), replace: true),
        throwsA(anything),
      );
      expect(
        canonicalJson((await service.export('test')).data),
        canonicalJson(input.data),
      );
    },
  );

  test('journal cleanup failure rolls back before reporting failure', () async {
    final before = await service.export('before');
    await db.customStatement(
      "CREATE TRIGGER fail_cleanup BEFORE DELETE ON backup_restore_journal BEGIN SELECT RAISE(ABORT, 'cleanup'); END",
    );
    await expectLater(
      service.restore(await service.preview(fixture()), replace: true),
      throwsA(anything),
    );
    expect(await db.select(db.snapshots).get(), isEmpty);
    expect(canonicalJson(prefs.values), canonicalJson(before.preferences));
    await db.customStatement('DROP TRIGGER fail_cleanup');
    await service.recover();
    expect(
      canonicalJson((await service.export('after')).data),
      canonicalJson(before.data),
    );
  });

  for (final committed in [false, true]) {
    test(
      'startup recovery uses durable commit marker $committed and is idempotent',
      () async {
        await service.export('initialize');
        final before = await prefs.read();
        final after = fixture().preferences;
        await db.customStatement(
          'INSERT INTO backup_restore_journal VALUES (1, ?, ?, ?)',
          [committed ? 1 : 0, jsonEncode(before), jsonEncode(after)],
        );
        prefs.values['teaching_plan'] = after['teaching_plan'];
        final restarted = BackupService(db, prefs);
        await restarted.recover();
        expect(
          canonicalJson(prefs.values),
          canonicalJson(committed ? after : before),
        );
        await restarted.recover();
        expect(
          (await db.customSelect('SELECT * FROM backup_restore_journal').get()),
          isEmpty,
        );
      },
    );
  }

  test('failed recovery retains its journal for retry', () async {
    await service.export('initialize');
    final before = await prefs.read();
    await db.customStatement(
      'INSERT INTO backup_restore_journal VALUES (1, 0, ?, ?)',
      [jsonEncode(before), jsonEncode(fixture().preferences)],
    );
    prefs.failAfter = 2;
    await expectLater(service.recover(), throwsStateError);
    expect(
      (await db.customSelect('SELECT * FROM backup_restore_journal').get()),
      hasLength(1),
    );
    await service.recover();
    expect(canonicalJson(prefs.values), canonicalJson(before));
  });

  test(
    'unknown fields, enum values, broken references and malformed data rejected',
    () {
      final mutations = <void Function(Map<String, dynamic>)>[
        (j) => j['version'] = 99,
        (j) => j['data']['preferences']['cookie'] = 'must not import',
        (j) => j['data']['snapshots'][0]['source'] = 'unknown',
        (j) => j['data']['snapshots'][0]['profileId'] = 'missing',
        (j) => j['data']['snapshots'][0]['records'][0]['xf'] = {},
        (j) => j['data']['versions'][0]['sessions'][0]['day'] = 8,
        (j) => j['data']['terms'][0]['monday'] = 'bad',
        (j) => j['data']['preferences']['teaching_plan']['courses'] = null,
        (j) => j['data']['profiles'].add(j['data']['profiles'][0]),
        (j) => j['data'].remove('versions'),
      ];
      for (final mutate in mutations) {
        final j = jsonDecode(fixture().encode()) as Map<String, dynamic>;
        mutate(j);
        expect(
          () => BackupDocument.parse(jsonEncode(j)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'local preference allowlist leaves unrelated and login data untouched',
    () async {
      SharedPreferences.setMockInitialValues({
        'cookie': 'private',
        'other': 'keep',
      });
      final local = LocalBackupPreferences();
      await local.write(fixture().preferences);
      expect(
        canonicalJson(await local.read()),
        canonicalJson(fixture().preferences),
      );
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('cookie'), 'private');
      expect(sp.getString('other'), 'keep');
      expect((await local.read()).containsKey('cookie'), false);
    },
  );

  test('CSV has BOM, CRLF, stable columns, quoting and formula protection', () {
    final bytes = gradesCsv([
      const CourseRecord(kch: '001', kcmc: '中,文"课\n名', cj: '=1+1'),
    ]);
    expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
    final text = utf8.decode(bytes);
    expect(text, startsWith('"课程代码","课程名称","学分"'));
    expect(text, contains('"中,文""课\n名"'));
    expect(text, contains('"\'=1+1"'));
    expect(text, endsWith('\r\n'));
  });
}
