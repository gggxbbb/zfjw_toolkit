import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 目标 GPA 持久化（shared_preferences）。
///
/// 对齐油猴 `jwgpa.targetGPA`：null 表示未设置。设置页写入，
/// 统计页/趋势线读取展示差距与目标虚线。
const String kTargetGpaKey = 'jwgpa.targetGPA';

final targetGpaProvider =
    AsyncNotifierProvider<TargetGpaNotifier, double?>(TargetGpaNotifier.new);

class TargetGpaNotifier extends AsyncNotifier<double?> {
  @override
  Future<double?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(kTargetGpaKey);
    return (v != null && v > 0) ? v : null;
  }

  /// 设定目标 GPA；null 清除。
  Future<void> setTarget(double? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value <= 0) {
      await prefs.remove(kTargetGpaKey);
      state = const AsyncData(null);
    } else {
      await prefs.setDouble(kTargetGpaKey, value);
      state = AsyncData(value);
    }
  }
}
