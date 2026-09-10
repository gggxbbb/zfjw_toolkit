/// 采集状态机：WebView 采集页的驱动逻辑。
///
/// 流转：loading → awaitingLogin（用户登录）→ navigating（导航至成绩页）
/// → capturing（注入脚本等待回传）→ done(records) / failed(reason)。
///
/// 纯 Dart 可测：URL 检测与 payload 处理与 WebView 解耦。
library;

import '../core/parser/parser.dart';
import '../core/model/course_record.dart';
import 'capture_script.dart';

/// 采集状态。
enum CaptureState {
  /// 页面加载中。
  loading,

  /// 等待用户完成教务登录（CAS/验证码由用户在 WebView 内自行完成）。
  awaitingLogin,

  /// 已登录，正在导航至成绩查询页。
  navigating,

  /// 已注入采集脚本，等待 JS 桥回传。
  capturing,

  /// 采集成功，携带解析后的记录。
  done,

  /// 采集失败（超时/解析失败/网络错误）。
  failed,
}

/// 采集结果。
class CaptureOutcome {
  final CaptureState state;
  final List<CourseRecord>? records;
  final String? error;

  const CaptureOutcome(this.state, {this.records, this.error});
}

/// URL 是否命中成绩查询页（命中即应注入采集脚本）。
bool isGradePageUrl(String? url) =>
    url != null && url.contains(zfjwGradePageMarker);

/// 采集完成链路：JS 桥 payload → JSON 解析 → 缺列回退 HTML → 结果。
///
/// [payload] 为注入脚本回传的 `{status, path, rows|message}`；
/// [fallbackHtml] 为 JSON 解析报 [GradeParseFailureReason.incompleteColumns]
/// 时的页面 HTML（由调用方经 controller.getHtml() 取得）。
CaptureOutcome handleCapturePayload(
  Map<String, dynamic> payload, {
  String? Function()? fallbackHtml,
}) {
  final status = payload['status'];
  if (status == 'error') {
    return CaptureOutcome(
      CaptureState.failed,
      error: (payload['message'] as String?) ?? '采集脚本报告未知错误',
    );
  }
  if (status != 'ok') {
    return CaptureOutcome(
      CaptureState.failed,
      error: '采集脚本回传了无法识别的状态：$status',
    );
  }

  final rawRows = payload['rows'];
  if (rawRows is! List || rawRows.isEmpty) {
    return CaptureOutcome(CaptureState.failed, error: '采集到 0 条记录');
  }
  final maps = <Map<String, dynamic>>[
    for (final r in rawRows)
      if (r is Map) Map<String, dynamic>.from(r),
  ];
  if (maps.isEmpty) {
    return CaptureOutcome(CaptureState.failed, error: '采集到 0 条记录');
  }

  return switch (parseJqGridJson(maps)) {
    GradeParseSuccess(:final records) => records.isEmpty
        ? CaptureOutcome(CaptureState.failed, error: '解析后无有效成绩行')
        : CaptureOutcome(CaptureState.done, records: records),
    GradeParseFailure(:final reason) =>
      reason == GradeParseFailureReason.incompleteColumns
          ? _fallbackToHtml(fallbackHtml)
          : CaptureOutcome(CaptureState.failed, error: '解析失败：$reason'),
  };
}

CaptureOutcome _fallbackToHtml(String? Function()? fallbackHtml) {
  final html = fallbackHtml?.call();
  if (html == null) {
    return CaptureOutcome(
      CaptureState.failed,
      error: 'JSON 缺关键列且无法获取页面 HTML 回退',
    );
  }
  return switch (parseGradeHtml(html)) {
    GradeParseSuccess(:final records) => records.isEmpty
        ? CaptureOutcome(CaptureState.failed, error: 'HTML 解析无成绩行')
        : CaptureOutcome(CaptureState.done, records: records),
    GradeParseFailure(:final reason) => CaptureOutcome(
        CaptureState.failed,
        error: 'HTML 解析失败：$reason',
      ),
  };
}
