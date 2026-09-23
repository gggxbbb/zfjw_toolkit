import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/database.dart' hide TimetableTerm;
import 'model.dart';

class TimetableRepository {
  TimetableRepository(this.db);
  final AppDatabase db;

  Future<List<TimetableTerm>> terms() async =>
      (await (db.select(
            db.timetableTerms,
          )..orderBy([(t) => OrderingTerm.desc(t.id)])).get())
          .map(
            (r) => TimetableTerm(
              id: r.id,
              label: r.label,
              monday: r.monday,
              weeks: r.weeks,
              checkedAt: r.checkedAt,
            ),
          )
          .toList();

  Future<List<TimetableSnapshot>> history(String term) async =>
      (await (db.select(db.timetableVersions)
                ..where((v) => v.term.equals(term))
                ..orderBy([
                  (v) => OrderingTerm.desc(v.capturedAt),
                  (v) =>
                      OrderingTerm.desc(const CustomExpression<int>('rowid')),
                ]))
              .get())
          .map(
            (v) => TimetableSnapshot(
              id: v.id,
              term: v.term,
              capturedAt: v.capturedAt,
              sessions: (jsonDecode(v.sessions) as List)
                  .map(
                    (s) => ClassSession.fromJson(
                      Map<String, dynamic>.from(s as Map),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();

  Future<void> settings(TimetableTerm term, DateTime monday, int weeks) async {
    _validate(monday, weeks);
    final versions = await history(term.id);
    final lastWeek = versions.firstOrNull?.lastWeek ?? 1;
    if (weeks < lastWeek) throw ArgumentError('总周数不能少于当前课表的最晚周次 $lastWeek');
    await (db.update(
      db.timetableTerms,
    )..where((t) => t.id.equals(term.id))).write(
      TimetableTermsCompanion(monday: Value(monday), weeks: Value(weeks)),
    );
  }

  /// 只能在用户确认后调用。事务内再次去重，重复保存不产生版本。
  Future<bool> accept(TimetableCapture capture, DateTime monday, int weeks) =>
      db.transaction(() async {
        _validate(monday, weeks);
        if (weeks < capture.lastWeek) throw ArgumentError('总周数少于课表实际周次');
        final versions = await history(capture.term);
        final now = DateTime.now();
        await db
            .into(db.timetableTerms)
            .insertOnConflictUpdate(
              TimetableTermsCompanion.insert(
                id: capture.term,
                label: capture.label,
                monday: monday,
                weeks: weeks,
                checkedAt: now,
              ),
            );
        if (versions.isNotEmpty &&
            timetableFingerprint(versions.first.sessions) ==
                timetableFingerprint(capture.sessions)) {
          return false;
        }
        await db
            .into(db.timetableVersions)
            .insert(
              TimetableVersionsCompanion.insert(
                id: const Uuid().v4(),
                term: capture.term,
                capturedAt: now,
                sessions: jsonEncode(
                  capture.sessions.map((s) => s.toJson()).toList(),
                ),
              ),
            );
        return true;
      });

  Future<void> checked(String term) async =>
      (db.update(db.timetableTerms)..where((t) => t.id.equals(term))).write(
        TimetableTermsCompanion(checkedAt: Value(DateTime.now())),
      );

  void _validate(DateTime monday, int weeks) {
    if (monday.weekday != DateTime.monday || weeks < 1 || weeks > 60) {
      throw ArgumentError('请选择周一，学期总周数须为 1–60');
    }
  }
}
