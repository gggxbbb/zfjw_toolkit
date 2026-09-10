import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/profile.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/database.dart';

/// 默认档案标识（固定 uuid，保证幂等创建）。
const String kDefaultProfileId = '00000000-0000-0000-0000-000000000000';

/// 成绩快照仓储：保存采集快照、按档案列出/取最新快照、确保默认档案存在。
class SnapshotRepository {
  final AppDatabase _db;

  SnapshotRepository(this._db);

  /// 保证存在默认档案：无则创建，有则原样返回。幂等。
  Future<Profile> ensureDefaultProfile() async {
    final existing = await (_db.select(_db.profiles)
          ..where((p) => p.id.equals(kDefaultProfileId)))
        .getSingleOrNull();
    if (existing != null) {
      return Profile(id: existing.id, name: existing.name);
    }
    final createdAt = DateTime.now();
    await _db.into(_db.profiles).insert(
          ProfilesCompanion.insert(
            id: kDefaultProfileId,
            name: '默认档案',
            createdAt: createdAt,
          ),
        );
    return Profile(id: kDefaultProfileId, name: '默认档案');
  }

  /// 保存一次采集快照，返回含生成 id/时间戳的 [Snapshot]。
  Future<Snapshot> saveSnapshot(
    String profileId,
    SnapshotSource source,
    List<CourseRecord> records,
  ) async {
    final id = const Uuid().v4();
    final capturedAt = DateTime.now();
    await _db.into(_db.snapshots).insert(
          SnapshotsCompanion.insert(
            id: id,
            profileId: profileId,
            source: source,
            capturedAt: capturedAt,
            records: records,
          ),
        );
    return Snapshot(
      id: id,
      source: source,
      capturedAt: capturedAt,
      records: records,
    );
  }

  /// 列出某档案全部快照，按采集时间倒序。
  Future<List<Snapshot>> listSnapshots(String profileId) async {
    final rows = await (_db.select(_db.snapshots)
          ..where((s) => s.profileId.equals(profileId))
          ..orderBy([(s) => OrderingTerm.desc(s.capturedAt)]))
        .get();
    return rows.map(_toSnapshot).toList();
  }

  /// 取某档案最新快照（含完整记录列表）。无快照返回 null。
  Future<Snapshot?> latestSnapshot(String profileId) async {
    final row = await (_db.select(_db.snapshots)
          ..where((s) => s.profileId.equals(profileId))
          ..orderBy([(s) => OrderingTerm.desc(s.capturedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toSnapshot(row);
  }

  Snapshot _toSnapshot(SnapshotRow row) => Snapshot(
        id: row.id,
        source: row.source,
        capturedAt: row.capturedAt,
        records: row.records,
      );
}
