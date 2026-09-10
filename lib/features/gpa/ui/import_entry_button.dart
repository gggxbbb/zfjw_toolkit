import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/parser/parser.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/ui/glass/glass.dart';

/// 「导入 HTML」入口按钮：file_picker 选正方成绩页 HTML → DOM 解析 → 存快照。
///
/// WebView 不可用时的完整备用数据通道（ADR-0001 兜底路径）。
class ImportEntryButton extends ConsumerWidget {
  const ImportEntryButton({super.key});

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
    );
    if (files.isEmpty) return; // 用户取消

    final bytes = await files.single.readAsBytes();

    final html = utf8.decode(bytes, allowMalformed: true);
    final outcome = parseGradeHtml(html);
    switch (outcome) {
      case GradeParseSuccess(:final records):
        if (records.isEmpty) {
          if (context.mounted) _toast(context, '文件中没有成绩行，请确认是成绩查询页');
          return;
        }
        final repo = ref.read(snapshotRepositoryProvider);
        await repo.saveSnapshot(kDefaultProfileId, SnapshotSource.file, records);
        ref.invalidate(latestSnapshotProvider);
        if (context.mounted) _toast(context, '导入成功：${records.length} 条记录');
      case GradeParseFailure(:final reason):
        if (context.mounted) _toast(context, '解析失败：$reason，请确认是成绩查询页');
    }
  }

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context, WidgetRef ref) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: GestureDetector(
          onTap: () => _import(context, ref),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file_outlined, size: 20),
              SizedBox(width: 8),
              Text('导入 HTML', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}
