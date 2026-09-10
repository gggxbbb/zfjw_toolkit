import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/parser/parser.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 从 HTML 文件导入成绩的完整流程（选文件 → 解析 → 入库 → 提示）。
///
/// 供 [ImportEntryButton]（空态大按钮）与 [ImportAppBarAction]（顶部栏
/// 图标按钮）共用——有数据后用户仍可随时重新导入更新成绩。
Future<void> runGradeImport(BuildContext context, WidgetRef ref) async {
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
        if (context.mounted) {
          showAppAlert(context, title: '导入失败', message: '文件中没有成绩行，请确认是成绩查询页。');
        }
        return;
      }
      final repo = ref.read(snapshotRepositoryProvider);
      await repo.saveSnapshot(
        kDefaultProfileId,
        SnapshotSource.file,
        records,
      );
      ref.invalidate(latestSnapshotProvider);
      if (context.mounted) {
        showAppAlert(context, title: '导入成功', message: '共 ${records.length} 条成绩记录。');
      }
    case GradeParseFailure(:final reason):
      if (context.mounted) {
        showAppAlert(
          context,
          title: '解析失败',
          message: '${reason.label}\n\n请确认导入的是成绩查询页。',
        );
      }
  }
}

/// 「导入 HTML」入口按钮：file_picker 选正方成绩页 HTML → DOM 解析 → 存快照。
///
/// WebView 不可用时的完整备用数据通道（ADR-0001 兜底路径）。
class ImportEntryButton extends ConsumerWidget {
  const ImportEntryButton({super.key, this.expand = false});

  /// 是否横向撑满父级。
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppGlassButton(
        label: '导入 HTML',
        icon: CupertinoIcons.doc_plaintext,
        style: AppButtonStyle.regular,
        expand: expand,
        onTap: () => runGradeImport(context, ref),
      );
}

/// 顶部栏图标版导入入口：有数据后的「重新导入/更新」常驻入口。
class ImportAppBarAction extends ConsumerWidget {
  const ImportAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppGlassIconButton(
        icon: CupertinoIcons.doc_plaintext,
        onTap: () => runGradeImport(context, ref),
      );
}
