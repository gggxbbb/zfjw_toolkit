import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 编译 release 包时通过 `--dart-define` 注入的源码与时间信息。
class BuildMetadata {
  const BuildMetadata({required this.gitHash, required this.buildTime});

  const BuildMetadata.fromEnvironment()
    : gitHash = const String.fromEnvironment('APP_GIT_HASH'),
      buildTime = const String.fromEnvironment('APP_BUILD_TIME');

  final String gitHash;
  final String buildTime;

  String get _normalizedGitHash => gitHash.trim();
  DateTime? get _parsedBuildTime => DateTime.tryParse(buildTime)?.toUtc();

  bool get isAvailable =>
      _normalizedGitHash.isNotEmpty && _parsedBuildTime != null;

  String get displayGitHash =>
      _normalizedGitHash.isEmpty ? '—' : _normalizedGitHash;

  String get displayBuildTime {
    final buildTime = _parsedBuildTime;
    if (buildTime == null) return '—';

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${buildTime.year.toString().padLeft(4, '0')}-'
        '${twoDigits(buildTime.month)}-${twoDigits(buildTime.day)} '
        '${twoDigits(buildTime.hour)}:${twoDigits(buildTime.minute)}:'
        '${twoDigits(buildTime.second)} UTC';
  }
}

final buildMetadataProvider = Provider<BuildMetadata>(
  (ref) => const BuildMetadata.fromEnvironment(),
);
