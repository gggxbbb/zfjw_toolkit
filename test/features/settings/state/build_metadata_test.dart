import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/features/settings/state/build_metadata.dart';

void main() {
  test('格式化 UTC 构建时间', () {
    const metadata = BuildMetadata(
      gitHash: '0123456789ab',
      buildTime: '2026-09-21T03:04:05.678Z',
    );

    expect(metadata.displayGitHash, '0123456789ab');
    expect(metadata.displayBuildTime, '2026-09-21 03:04:05 UTC');
    expect(metadata.isAvailable, isTrue);
  });

  test('未注入或无效的构建信息显示占位符', () {
    const missing = BuildMetadata(gitHash: '', buildTime: '');
    const invalid = BuildMetadata(gitHash: '', buildTime: 'not-a-date');

    expect(missing.displayGitHash, '—');
    expect(missing.displayBuildTime, '—');
    expect(missing.isAvailable, isFalse);
    expect(invalid.displayBuildTime, '—');
    expect(invalid.isAvailable, isFalse);
  });
}
