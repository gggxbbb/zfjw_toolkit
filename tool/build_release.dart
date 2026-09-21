import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exitCode = args.isEmpty ? 64 : 0;
    return;
  }

  if (args.contains('--debug') || args.contains('--profile')) {
    stderr.writeln('build_release.dart 仅用于 release 构建。');
    exitCode = 64;
    return;
  }

  if (!await _isWorkingTreeClean()) {
    stderr.writeln(
      '工作树存在未提交更改，无法生成可追溯的 release 包。'
      '请先提交或处理这些更改。',
    );
    exitCode = 1;
    return;
  }
  final gitHash = await _readGitHash();
  final buildTime = DateTime.now().toUtc().toIso8601String();
  final flutterExecutable = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final forwardedArgs = args.skip(1).where((arg) => arg != '--release');
  final flutterArgs = <String>[
    'build',
    args.first,
    ...forwardedArgs,
    '--release',
    '--dart-define=APP_GIT_HASH=$gitHash',
    '--dart-define=APP_BUILD_TIME=$buildTime',
  ];

  stdout.writeln('Git hash: $gitHash');
  stdout.writeln('Build time: $buildTime');
  stdout.writeln('Running: $flutterExecutable ${flutterArgs.join(' ')}');

  final process = await Process.start(
    flutterExecutable,
    flutterArgs,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  exitCode = await process.exitCode;
}

Future<bool> _isWorkingTreeClean() async {
  final result = await Process.run('git', const ['status', '--porcelain']);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw StateError('无法检查 Git 工作树状态。');
  }

  return (result.stdout as String).trim().isEmpty;
}

Future<String> _readGitHash() async {
  final result = await Process.run('git', const [
    'rev-parse',
    '--short=12',
    'HEAD',
  ]);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw StateError('无法读取当前 Git 提交。');
  }

  final hash = (result.stdout as String).trim();
  if (hash.isEmpty) throw StateError('当前 Git 提交为空。');
  return hash;
}

void _printUsage() {
  stdout.writeln(
    '用法: dart run tool/build_release.dart <flutter-build-target> [build options]\n'
    '示例: dart run tool/build_release.dart apk --split-per-abi\n'
    '      dart run tool/build_release.dart windows',
  );
}
