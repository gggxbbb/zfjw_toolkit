import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/parser/parser.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/features/gpa/ui/capture_page.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 从 HTML 文件导入成绩的完整流程（选文件 → 解析 → 入库 → 提示）。
///
/// 供 [ImportEntryButton]（空态大按钮）与统计页底部的并排入口共用——
/// 有数据后用户仍可随时重新导入更新成绩。
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
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(builder: (_) => const GradeImportPage()),
        ),
      );
}

/// 成绩导入页：把在线采集与 HTML 文件导入放在一个清晰的入口中。
///
/// 页面采用底部 [SafeArea]，使主操作与说明在 iPhone Home Indicator 上方。
class GradeImportPage extends ConsumerWidget {
  const GradeImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: const Text('导入成绩'),
        leading: AppGlassIconButton(
          icon: CupertinoIcons.back,
          onTap: () => Navigator.of(context).pop(),
          style: AppButtonStyle.plain,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space4,
            AppTokens.space5,
            AppTokens.space4,
            AppTokens.space5,
          ),
          children: [
            const SizedBox(height: AppTokens.space2),
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.accentSubtle,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                CupertinoIcons.chart_bar_alt_fill,
                color: tokens.accent,
                size: 30,
              ),
            ),
            const SizedBox(height: AppTokens.space4),
            Text('把成绩带进来', style: AppText.largeTitle.copyWith(color: tokens.labelPrimary)),
            const SizedBox(height: AppTokens.space2),
            Text(
              '选择一种方式创建成绩快照。数据只保存在本机，随时可以重新导入更新。',
              style: AppText.subhead.copyWith(color: tokens.labelSecondary),
            ),
            const SizedBox(height: AppTokens.space6),
            _ImportMethodCard(
              icon: CupertinoIcons.cloud_download_fill,
              iconColor: tokens.accent,
              title: '在线采集',
              detail: '在校方教务页面登录并打开成绩查询页，应用会自动读取结果。',
              actionLabel: '打开教务系统',
              prominent: true,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(builder: (_) => const CapturePage()),
              ),
            ),
            const SizedBox(height: AppTokens.space3),
            _ImportMethodCard(
              icon: CupertinoIcons.doc_text_fill,
              iconColor: tokens.success,
              title: '导入 HTML 文件',
              detail: '选择已保存的正方成绩查询页面（.html 或 .htm）。',
              actionLabel: '选择文件',
              onTap: () => runGradeImport(context, ref),
            ),
            const SizedBox(height: AppTokens.space5),
            Text('使用提示', style: AppText.sectionHeader.copyWith(color: tokens.labelTertiary)),
            const SizedBox(height: AppTokens.space2),
            AppGlassCard(
              glass: false,
              child: Text(
                '请仅采集或导入自己的成绩信息。若文件无法识别，请确认它来自成绩查询结果页，而不是登录页或截图。',
                style: AppText.footnote.copyWith(color: tokens.labelSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportMethodCard extends StatelessWidget {
  const _ImportMethodCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return AppGlassCard(
      padding: const EdgeInsets.all(AppTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconColor.withAlpha(28), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: AppTokens.space3),
          Text(title, style: AppText.title.copyWith(color: tokens.labelPrimary)),
          const SizedBox(height: AppTokens.space1),
          Text(detail, style: AppText.footnote.copyWith(color: tokens.labelSecondary)),
          const SizedBox(height: AppTokens.space4),
          AppGlassButton(
            label: actionLabel,
            icon: CupertinoIcons.arrow_right,
            style: prominent ? AppButtonStyle.prominent : AppButtonStyle.regular,
            expand: true,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}
