import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 稳定 id 同时作为持久化键的一部分，发布后不要重命名。
enum FeatureFlag {
  timetable('timetable', '课表', '启用离线课表与历史快照。关闭后保留已采集的数据。', false);

  const FeatureFlag(this.id, this.label, this.description, this.defaultValue);
  final String id, label, description;
  final bool defaultValue;
  String get storageKey => 'jwgpa.feature_flags.$id';
}

final featureFlagsProvider =
    AsyncNotifierProvider<FeatureFlagsNotifier, Map<FeatureFlag, bool>>(
      FeatureFlagsNotifier.new,
    );

/// 加载完成前不开放受控功能，避免启动时入口闪现。
final featureEnabledProvider = Provider.family<bool, FeatureFlag>((ref, flag) {
  return ref.watch(featureFlagsProvider).value?[flag] ?? false;
});

class FeatureFlagsNotifier extends AsyncNotifier<Map<FeatureFlag, bool>> {
  Future<void> _pending = Future.value();

  @override
  Future<Map<FeatureFlag, bool>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return Map.unmodifiable({
      for (final flag in FeatureFlag.values)
        flag: prefs.get(flag.storageKey) is bool
            ? prefs.getBool(flag.storageKey)!
            : flag.defaultValue,
    });
  }

  /// 串行保存；写入成功后才发布新状态，失败保留原值并通知调用者。
  Future<void> setEnabled(FeatureFlag flag, bool enabled) {
    final operation = _pending.then((_) async {
      await future;
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(flag.storageKey, enabled)) {
        throw StateError('功能开关保存失败');
      }
      state = AsyncData(
        Map.unmodifiable({...state.requireValue, flag: enabled}),
      );
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
