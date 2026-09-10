import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zfjw_toolkit/capture/capture_script.dart';
import 'package:zfjw_toolkit/capture/teaching_plan_capture.dart';
import 'package:zfjw_toolkit/data/teaching_plan_repository.dart';
import 'package:zfjw_toolkit/features/target/target_analysis_page.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

class PlanCapturePage extends ConsumerStatefulWidget { const PlanCapturePage({super.key}); @override ConsumerState<PlanCapturePage> createState() => _PlanCapturePageState(); }
class _PlanCapturePageState extends ConsumerState<PlanCapturePage> {
  final String _status = '登录后，打开“教学执行计划查看”，选定计划并进入“课程信息”页';
  @override Widget build(BuildContext context) => AppGlassScaffold(
    extendBody: false, appBar: AppGlassAppBar(title: const Text('采集教学计划'), leading: AppGlassIconButton(icon: CupertinoIcons.back, onTap: () => Navigator.pop(context))),
    body: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space4, vertical: AppTokens.space3),
        decoration: BoxDecoration(
          color: AppTokens.of(context).accentSubtle,
          border: Border(bottom: BorderSide(color: AppTokens.of(context).separator, width: .5)),
        ),
        child: Row(children: [
          const SizedBox(width: 14, height: 14, child: AppGlassProgress(size: 14)),
          const SizedBox(width: AppTokens.space2),
          Expanded(child: Text(_status, style: AppText.footnote.copyWith(color: AppTokens.of(context).labelPrimary, fontWeight: FontWeight.w500))),
        ]),
      ),
      Expanded(child: InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(zfjwDefaultEntryUrl)), initialSettings: InAppWebViewSettings(javaScriptEnabled: true, thirdPartyCookiesEnabled: true),
      onWebViewCreated: (c) => c.addJavaScriptHandler(handlerName: teachingPlanCaptureHandlerName, callback: (args) async { final plan = args.isEmpty || args.first is! Map ? null : teachingPlanFromPayload(Map<String,dynamic>.from(args.first as Map)); if (plan == null) return null; await TeachingPlanRepository().save(plan); ref.invalidate(teachingPlanProvider); if (mounted) Navigator.of(this.context).pop(); return null; }),
      onLoadStop: (c, url) async { if ((url?.toString() ?? '').contains(teachingPlanPageMarker)) { await c.evaluateJavascript(source: teachingPlanCaptureScript); } },
    ))]),
    ]),
  );
}
