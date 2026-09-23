import 'model.dart';

class SessionChange {
  const SessionChange({this.before, this.after});
  final ClassSession? before, after;
  String get description {
    final a = before;
    final b = after;
    if (a == null) return '新增 ${b!.name} · ${b.when}';
    if (b == null) return '取消 ${a.name} · ${a.when}';
    final changes = <String>[
      if (a.slotKey != b.slotKey) '时间：${a.when} → ${b.when}',
      if (a.teacher != b.teacher) '教师：${a.teacher} → ${b.teacher}',
      if (a.location != b.location) '地点：${a.location} → ${b.location}',
      if (a.group != b.group) '教学班：${a.group} → ${b.group}',
      if (a.adjusted != b.adjusted) '平台调课标记：${b.adjusted ? '新增' : '移除'}',
    ];
    return '${b.name} · ${b.when}\n${changes.join('\n')}';
  }
}

/// 完全相同的课次优先消去；同一时间仅有唯一候选时配对。
/// 剩余课次仅在两侧顺序锚点一致且均为单个候选时配对。
List<SessionChange> diffTimetable(
  List<ClassSession> before,
  List<ClassSession> after,
) {
  final result = <SessionChange>[];
  final keys = {
    ...before.map((s) => s.courseKey),
    ...after.map((s) => s.courseKey),
  }.toList()..sort();
  for (final key in keys) {
    final old = before.where((s) => s.courseKey == key).toList()
      ..sort(compareSessions);
    final next = after.where((s) => s.courseKey == key).toList()
      ..sort(compareSessions);
    final pairs = <int, int>{};
    final used = <int>{};
    for (var i = 0; i < old.length; i++) {
      final j = next.indexWhere((s) => s.semanticKey == old[i].semanticKey);
      // Duplicate occurrences are matched as a multiset, not collapsed.
      final available = j < 0
          ? -1
          : Iterable<int>.generate(next.length)
                .where(
                  (n) =>
                      !used.contains(n) &&
                      next[n].semanticKey == old[i].semanticKey,
                )
                .firstOrNull;
      if (available != null && available >= 0) {
        pairs[i] = available;
        used.add(available);
      }
    }
    for (var i = 0; i < old.length; i++) {
      if (pairs.containsKey(i)) continue;
      final candidates = Iterable<int>.generate(next.length)
          .where((j) => !used.contains(j) && old[i].slotKey == next[j].slotKey)
          .toList();
      final oldCount = Iterable<int>.generate(old.length)
          .where(
            (n) => !pairs.containsKey(n) && old[n].slotKey == old[i].slotKey,
          )
          .length;
      if (candidates.length == 1 && oldCount == 1) {
        pairs[i] = candidates.single;
        used.add(candidates.single);
      }
    }
    // Only monotone anchors can establish a trustworthy interval.
    final anchors = pairs.keys.toList()..sort();
    final monotone = Iterable<int>.generate(
      anchors.isNotEmpty ? anchors.length - 1 : 0,
    ).every((i) => pairs[anchors[i]]! < pairs[anchors[i + 1]]!);
    if (monotone) {
      final boundaries = [-1, ...anchors, old.length];
      for (var n = 0; n < boundaries.length - 1; n++) {
        final left = boundaries[n], right = boundaries[n + 1];
        final newLeft = left < 0 ? -1 : pairs[left]!;
        final newRight = right == old.length ? next.length : pairs[right]!;
        final a = [
          for (var i = left + 1; i < right; i++)
            if (!pairs.containsKey(i)) i,
        ];
        final b = [
          for (var j = newLeft + 1; j < newRight; j++)
            if (!used.contains(j)) j,
        ];
        if (a.isNotEmpty && a.length == b.length) {
          // Equal, monotone intervals with the same source details are the
          // chronological occurrences of one course moving together.
          final trustworthy = Iterable<int>.generate(a.length).every((i) {
            final x = old[a[i]], y = next[b[i]];
            return x.teacher == y.teacher &&
                x.location == y.location &&
                x.group == y.group;
          });
          if (trustworthy) {
            for (var i = 0; i < a.length; i++) {
              pairs[a[i]] = b[i];
              used.add(b[i]);
            }
          }
        }
      }
    }
    for (var i = 0; i < old.length; i++) {
      final j = pairs[i];
      if (j == null) {
        result.add(SessionChange(before: old[i]));
      } else if (old[i].semanticKey != next[j].semanticKey) {
        result.add(SessionChange(before: old[i], after: next[j]));
      }
    }
    for (var j = 0; j < next.length; j++) {
      if (!used.contains(j)) result.add(SessionChange(after: next[j]));
    }
  }
  return result;
}
