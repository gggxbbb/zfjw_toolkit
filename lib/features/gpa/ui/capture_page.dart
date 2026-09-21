import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zfjw_toolkit/capture/capture_flow.dart';
import 'package:zfjw_toolkit/capture/capture_script.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';
import 'package:zfjw_toolkit/features/capture/web_capture_page.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';

/// 成绩领域对通用 Web 采集模块的 Adapter。
class CapturePage extends ConsumerWidget {
  const CapturePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => WebCapturePage(
    title: '成绩采集',
    instruction: '请完成教务登录并打开“学生成绩查询”页面',
    handlerName: zfjwCaptureHandlerName,
    matchesPage: isGradePageUrl,
    script: zfjwCaptureScript,
    onPayload: (payload, controller) async {
      var outcome = handleCapturePayload(payload, fallbackHtml: () => null);
      if (outcome.state == CaptureState.failed &&
          (outcome.error ?? '').contains('无法获取页面 HTML')) {
        final html = await controller.getHtml();
        outcome = handleCapturePayload(payload, fallbackHtml: () => html);
      }
      if (outcome.state != CaptureState.done || outcome.records == null) {
        return WebCaptureResult.failure(outcome.error ?? '采集失败');
      }

      final records = outcome.records!;
      final semesters = records
          .map((record) {
            final year = (record.xnmmc ?? record.xnm ?? '').trim();
            final term = (record.xqmmc ?? record.xqm ?? '').trim();
            return '$year $term'.trim();
          })
          .where((semester) => semester.isNotEmpty)
          .toSet();
      final courses = records
          .map((record) => record.courseKey)
          .where((course) => course.isNotEmpty)
          .toSet();
      final source = payload['path'] == 'dom' ? '页面表格' : 'jqGrid 数据';

      return WebCaptureResult.review(
        '读取完成，请确认本次结果',
        overview: [
          '成绩记录：${records.length} 条',
          '不同课程：${courses.length} 门',
          '覆盖学期：${semesters.length} 个',
          '读取来源：$source',
        ],
        commit: () async {
          await ref
              .read(snapshotRepositoryProvider)
              .saveSnapshot(kDefaultProfileId, SnapshotSource.webview, records);
          ref.invalidate(latestSnapshotProvider);
        },
      );
    },
    onSuccess: () => Navigator.of(context).popUntil((route) => route.isFirst),
  );
}
