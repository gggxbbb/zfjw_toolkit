import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zfjw_toolkit/capture/teaching_plan_capture.dart';
import 'package:zfjw_toolkit/data/teaching_plan_repository.dart';
import 'package:zfjw_toolkit/features/capture/web_capture_page.dart';
import 'package:zfjw_toolkit/features/target/target_analysis_page.dart';

class PlanCapturePage extends ConsumerWidget {
  const PlanCapturePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => WebCapturePage(
        title: '采集教学计划',
        instruction: '登录后，打开“教学执行计划查看”，选定计划并进入“课程信息”页',
        handlerName: teachingPlanCaptureHandlerName,
        matchesPage: (url) => url?.contains(teachingPlanPageMarker) ?? false,
        script: teachingPlanCaptureScript,
        onPayload: (payload, _) async {
          final plan = teachingPlanFromPayload(payload);
          if (plan == null) return const WebCaptureResult.failure('未能读取教学计划课程，请确认已进入“课程信息”页');
          await TeachingPlanRepository().save(plan);
          ref.invalidate(teachingPlanProvider);
          return WebCaptureResult.success('已采集 ${plan.courses.length} 门计划课程');
        },
        onSuccess: () => Navigator.of(context).pop(),
      );
}
