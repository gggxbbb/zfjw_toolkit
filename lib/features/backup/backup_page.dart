import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/model/course_record.dart';
import '../../core/model/snapshot.dart';
import '../../data/snapshot_repository.dart';
import '../../ui/kit/kit.dart';
import '../gpa/state/gpa_providers.dart';
import '../manage/data_management_page.dart';
import '../settings/state/app_version.dart';
import '../timetable/dialogs.dart' show timestampLabel;
import 'backup_document.dart';
import 'backup_service.dart';
import 'csv_export.dart';
import 'providers.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false, _failed = false, _recoveryBlocked = false;
  String? _message;
  ImportPreview? _preview;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = '操作失败：$e';
          _failed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

  void _result(bool saved) {
    if (mounted) setState(() => _message = saved ? '文件已保存' : '已取消保存');
  }

  Future<void> _exportBackup() => _run(() async {
    if (!await _confirm(
      context,
      '导出完整备份',
      '备份包含成绩、课表和个人设置，请保存在自己控制的位置。登录密码、Cookie 和 WebView 数据不会导出。',
      '选择保存位置',
    )) {
      return;
    }
    final version = await ref.read(appVersionProvider.future);
    final document = await ref.read(backupServiceProvider).export(version);
    _result(
      await ref
          .read(documentGatewayProvider)
          .save(
            'zfjw-backup-${DateTime.now().millisecondsSinceEpoch}.json',
            Uint8List.fromList(utf8.encode(document.encode())),
            'application/json',
          ),
    );
  });

  Future<void> _importBackup() => _run(() async {
    final text = await ref.read(documentGatewayProvider).openBackup();
    if (text == null) return;
    final document = BackupDocument.parse(text);
    final preview = await ref.read(backupServiceProvider).preview(document);
    if (mounted) setState(() => _preview = preview);
  });

  Future<void> _restore(bool replace) => _run(() async {
    final preview = _preview!;
    if (replace &&
        !await _confirm(
          context,
          '替换本机全部学业数据？',
          '将移除本机现有成绩与课表历史，并用备份中的教学计划、手动修改、GPA 目标和功能开关替换本机内容。此操作不能撤销，建议先导出本机备份。',
          '确认替换',
          destructive: true,
        )) {
      return;
    }
    final service = ref.read(backupServiceProvider);
    try {
      await service.restore(preview, replace: replace);
    } catch (_) {
      try {
        await service.recover();
      } catch (_) {
        _recoveryBlocked = true;
      }
      if (mounted && !_recoveryBlocked) refreshRestoredData(ref);
      rethrow;
    }
    if (!mounted) return;
    refreshRestoredData(ref);
    setState(() {
      _preview = null;
      _message = replace ? '已完成替换恢复' : '已完成合并导入';
    });
  });

  Future<void> _recover() => _run(() async {
    await ref.read(backupServiceProvider).recover();
    if (!mounted) return;
    refreshRestoredData(ref);
    setState(() {
      _recoveryBlocked = false;
      _preview = null;
      _message = '数据恢复完成，请重新核对后操作';
    });
  });

  Future<void> _csv({required bool history}) => _run(() async {
    List<CourseRecord>? records;
    if (history) {
      final repo = ref.read(snapshotRepositoryProvider);
      final snapshots = await repo.listSnapshots(kDefaultProfileId);
      if (!mounted) return;
      if (snapshots.isEmpty) {
        setState(() => _message = '暂无成绩历史快照');
        return;
      }
      final selected = await Navigator.push<Snapshot>(
        context,
        CupertinoPageRoute(
          builder: (_) => _SnapshotPicker(snapshots: snapshots),
        ),
      );
      if (selected == null) return;
      records = selected.records;
    } else {
      records = await ref.read(effectiveRecordsProvider.future);
    }
    if (!mounted) return;
    if (records == null || records.isEmpty) {
      setState(() => _message = '没有可导出的成绩记录');
      return;
    }
    if (!await _confirm(
      context,
      '导出成绩 CSV',
      '${history ? '历史原始成绩，不应用当前修改' : '当前成绩，包含手动修改'}，共 ${records.length} 条。CSV 仅供表格分析，不能恢复完整应用数据。请妥善保管个人成绩。',
      '选择保存位置',
    )) {
      return;
    }
    _result(
      await ref
          .read(documentGatewayProvider)
          .save(
            'grades-${history ? 'history' : 'current'}-${DateTime.now().millisecondsSinceEpoch}.csv',
            gradesCsv(records),
            'text/csv',
          ),
    );
  });

  Widget _text(String text, {bool secondary = false, bool danger = false}) =>
      Text(
        text,
        style: AppText.body.copyWith(
          color: danger
              ? AppTokens.of(context).danger
              : secondary
              ? AppTokens.of(context).labelSecondary
              : AppTokens.of(context).labelPrimary,
        ),
      );

  Widget _card(String title, String detail, List<Widget> actions) =>
      AppGlassGroupedCard(
        title: title,
        glass: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _text(detail, secondary: true),
            const SizedBox(height: AppTokens.space4),
            Wrap(
              spacing: AppTokens.space2,
              runSpacing: AppTokens.space2,
              children: actions,
            ),
          ],
        ),
      );
  AppGlassButton _button(String label, VoidCallback action) => AppGlassButton(
    label: label,
    onTap: _busy || _recoveryBlocked ? null : action,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final preview = _preview;
    return PopScope(
      canPop: !_busy && !_recoveryBlocked,
      child: AppGlassScaffold(
        extendBody: false,
        appBar: AppGlassAppBar(
          title: Text(
            '数据与备份',
            style: AppText.title.copyWith(color: tokens.labelPrimary),
          ),
          leading: AppGlassIconButton(
            icon: CupertinoIcons.back,
            onTap: _busy || _recoveryBlocked
                ? null
                : () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: AppContentFrame(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(AppTokens.space4),
              children: [
                if (_busy) ...[
                  const Center(child: AppGlassProgress()),
                  const SizedBox(height: AppTokens.space3),
                ],
                if (_message != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: _text(_message!, danger: _failed),
                  ),
                  const SizedBox(height: AppTokens.space4),
                ],
                if (_recoveryBlocked)
                  _card('需要完成恢复', '恢复记录已保留。完成恢复前暂不能离开此页。', [
                    AppGlassButton(
                      label: '重试恢复',
                      onTap: _busy ? null : _recover,
                    ),
                  ])
                else if (preview != null) ...[
                  _card(
                    '导入预览',
                    '备份版本 ${preview.incoming.json['appVersion']} · ${timestampLabel(DateTime.parse(preview.incoming.json['exportedAt'] as String).toLocal())}\n核对内容后选择合并或替换。',
                    [_button('取消导入', () => setState(() => _preview = null))],
                  ),
                  const SizedBox(height: AppTokens.space4),
                  AppGlassGroupedCard(
                    title: '备份内容',
                    glass: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in const {
                          'profiles': '档案',
                          'snapshots': '成绩快照',
                          'terms': '课表学期',
                          'versions': '课表快照',
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTokens.space2,
                            ),
                            child: _text(
                              '${entry.value}：${preview.incoming.rows(entry.key).length} · 合并新增 ${preview.added[entry.key]} / 跳过 ${preview.skipped[entry.key]}',
                            ),
                          ),
                        _text(
                          '教学计划：${preview.incoming.preferences['teaching_plan'] == null ? '无' : '有'}',
                        ),
                        _text(
                          '成绩修改：${preview.incoming.preferences['record_overrides'] == null ? '无' : '有'}',
                        ),
                        _text(
                          '计划修改：${preview.incoming.preferences['plan_overrides'] == null ? '无' : '有'}',
                        ),
                        _text('规则包：徐医 · GPA 目标及功能开关随备份恢复', secondary: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space4),
                  if (!preview.canMerge) ...[
                    AppGlassGroupedCard(
                      title: '存在 ${preview.conflicts.length} 项冲突，无法合并',
                      glass: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final conflict in preview.conflicts.take(20))
                            _text(conflict, danger: true),
                          if (preview.conflicts.length > 20)
                            _text(
                              '另有 ${preview.conflicts.length - 20} 项冲突',
                              danger: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTokens.space4),
                  ],
                  _card('确认导入', '合并保留本机已有数据，同标识但内容不同会阻止合并。替换将使本机数据与备份一致。', [
                    AppGlassButton(
                      label: '确认合并',
                      onTap: _busy || !preview.canMerge
                          ? null
                          : () => _restore(false),
                    ),
                    _button('替换本机数据', () => _restore(true)),
                  ]),
                ] else
                  AppResponsiveColumns(
                    children: [
                      _card('完整备份', '保存全部成绩历史、教学计划、手动修改、课表历史与个人设置，用于迁移或恢复。', [
                        _button('导出完整备份', _exportBackup),
                        _button('导入完整备份', _importBackup),
                      ]),
                      _card('成绩 CSV', '导出供 Excel 等表格工具分析的成绩。历史模式保留原始采集内容。', [
                        _button('导出当前成绩', () => _csv(history: false)),
                        _button('导出历史成绩', () => _csv(history: true)),
                      ]),
                      _card('数据管理', '查看、修改或隐藏成绩和教学计划课程。', [
                        _button(
                          '管理与编辑数据',
                          () => Navigator.push(
                            context,
                            CupertinoPageRoute<void>(
                              builder: (_) => const DataManagementPage(),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
  String action, {
  bool destructive = false,
}) async =>
    await showCupertinoDialog<bool>(
      context: context,
      builder: (c) {
        final tokens = AppTokens.of(c);
        return CupertinoAlertDialog(
          title: Text(
            title,
            style: AppText.title.copyWith(color: tokens.labelPrimary),
          ),
          content: Text(
            message,
            style: AppText.body.copyWith(color: tokens.labelSecondary),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(c, false),
              child: Text(
                '取消',
                style: AppText.body.copyWith(color: tokens.accent),
              ),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              onPressed: () => Navigator.pop(c, true),
              child: Text(
                action,
                style: AppText.body.copyWith(
                  color: destructive ? tokens.danger : tokens.accent,
                ),
              ),
            ),
          ],
        );
      },
    ) ??
    false;

class _SnapshotPicker extends StatelessWidget {
  const _SnapshotPicker({required this.snapshots});
  final List<Snapshot> snapshots;
  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: Text(
          '选择历史成绩',
          style: AppText.title.copyWith(color: tokens.labelPrimary),
        ),
        leading: AppGlassIconButton(
          icon: CupertinoIcons.back,
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: AppContentFrame(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppTokens.space4),
            itemCount: snapshots.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTokens.space3),
            itemBuilder: (context, i) {
              final snapshot = snapshots[i];
              return AppGlassCard(
                glass: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timestampLabel(snapshot.capturedAt),
                      style: AppText.title.copyWith(color: tokens.labelPrimary),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Text(
                      '${snapshot.records.length} 条 · ${switch (snapshot.source) {
                        SnapshotSource.webview => '网页采集',
                        SnapshotSource.file => '文件采集',
                        SnapshotSource.manual => '手动录入',
                      }}',
                      style: AppText.body.copyWith(
                        color: tokens.labelSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space3),
                    AppGlassButton(
                      label: '导出此快照',
                      onTap: () => Navigator.pop(context, snapshot),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
