import 'snapshot.dart';

/// 一名学生的成绩数据容器。
///
/// 当前单档案，但存储格式按多档案设计（持有多个 [Snapshot]）。
class Profile {
  final String id;
  final String name;
  final List<Snapshot> snapshots;

  const Profile({
    required this.id,
    required this.name,
    this.snapshots = const [],
  });

  /// 追加一个快照，返回新实例。
  Profile addSnapshot(Snapshot snapshot) => Profile(
        id: id,
        name: name,
        snapshots: [...snapshots, snapshot],
      );

  Profile copyWith({
    String? id,
    String? name,
    List<Snapshot>? snapshots,
  }) =>
      Profile(
        id: id ?? this.id,
        name: name ?? this.name,
        snapshots: snapshots ?? this.snapshots,
      );

  @override
  String toString() =>
      'Profile(id: $id, name: $name, snapshots: ${snapshots.length})';
}
