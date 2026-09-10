import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zfjw_toolkit/core/stats/target_analysis.dart';

/// 目标/最低 GPA 设置（分「全部课程」与「学位课」两个范围）。
///
/// - 目标 GPA：个人期望刷到的绩点，未设置时界面按 3.0 展示差距。
/// - 最低 GPA：学校毕业/学位授与的硬性要求（如学位课 2.0），默认 2.0。
class GpaGoals {
  const GpaGoals({
    this.targetAll,
    this.targetDegree,
    this.minAll = kDefaultMinGpa,
    this.minDegree = kDefaultMinGpa,
  });

  static const double kDefaultMinGpa = 2.0;

  final double? targetAll;
  final double? targetDegree;
  final double minAll;
  final double minDegree;

  /// 范围对应的目标 GPA（未设置为 null，由界面决定回退值）。
  double? targetFor(TargetScope scope) =>
      scope == TargetScope.all ? targetAll : targetDegree;

  /// 范围对应的最低 GPA。
  double minFor(TargetScope scope) =>
      scope == TargetScope.all ? minAll : minDegree;

  GpaGoals copyWith({
    double? Function()? targetAll,
    double? Function()? targetDegree,
    double? minAll,
    double? minDegree,
  }) =>
      GpaGoals(
        targetAll: targetAll == null ? this.targetAll : targetAll(),
        targetDegree:
            targetDegree == null ? this.targetDegree : targetDegree(),
        minAll: minAll ?? this.minAll,
        minDegree: minDegree ?? this.minDegree,
      );
}

const String _kTargetAllKey = 'jwgpa.targetGPA';
const String _kTargetDegreeKey = 'jwgpa.targetGPA.degree';
const String _kMinAllKey = 'jwgpa.minGPA.all';
const String _kMinDegreeKey = 'jwgpa.minGPA.degree';

final gpaGoalsProvider =
    AsyncNotifierProvider<GpaGoalsNotifier, GpaGoals>(GpaGoalsNotifier.new);

class GpaGoalsNotifier extends AsyncNotifier<GpaGoals> {
  @override
  Future<GpaGoals> build() async {
    final prefs = await SharedPreferences.getInstance();
    double? target(String key) {
      final v = prefs.getDouble(key);
      return (v != null && v > 0) ? v : null;
    }

    return GpaGoals(
      targetAll: target(_kTargetAllKey),
      targetDegree: target(_kTargetDegreeKey),
      minAll: prefs.getDouble(_kMinAllKey) ?? GpaGoals.kDefaultMinGpa,
      minDegree: prefs.getDouble(_kMinDegreeKey) ?? GpaGoals.kDefaultMinGpa,
    );
  }

  /// 设定范围目标 GPA；null 或非法值清除。
  Future<void> setTarget(TargetScope scope, double? value) =>
      _write(scope == TargetScope.all ? _kTargetAllKey : _kTargetDegreeKey,
          value, isMin: false);

  /// 设定范围最低 GPA；null 或非法值恢复默认 2.0。
  Future<void> setMin(TargetScope scope, double? value) =>
      _write(scope == TargetScope.all ? _kMinAllKey : _kMinDegreeKey, value,
          isMin: true);

  Future<void> _write(String key, double? value, {required bool isMin}) async {
    final prefs = await SharedPreferences.getInstance();
    final valid = value != null && value > 0;
    if (valid) {
      await prefs.setDouble(key, value);
    } else {
      await prefs.remove(key);
    }
    final current = state.value ?? const GpaGoals();
    GpaGoals next;
    if (key == _kTargetAllKey) {
      next = current.copyWith(targetAll: () => valid ? value : null);
    } else if (key == _kTargetDegreeKey) {
      next = current.copyWith(targetDegree: () => valid ? value : null);
    } else if (key == _kMinAllKey) {
      next = current.copyWith(
          minAll: valid ? value : GpaGoals.kDefaultMinGpa);
    } else {
      next = current.copyWith(
          minDegree: valid ? value : GpaGoals.kDefaultMinGpa);
    }
    state = AsyncData(next);
  }
}
