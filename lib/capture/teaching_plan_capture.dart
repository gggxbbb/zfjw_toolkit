import '../core/model/teaching_plan.dart';

const teachingPlanCaptureHandlerName = 'zfjwTeachingPlanCapture';
const teachingPlanPageMarker = 'jxzxjhck_cxJxzxjhckIndex.html';

TeachingPlan? teachingPlanFromPayload(Map<String, dynamic> payload) {
  if (payload['status'] != 'ok' || payload['courses'] is! List) return null;
  final courses = (payload['courses'] as List)
      .whereType<Map>()
      .map((e) => PlannedCourse.fromJson(Map<String, dynamic>.from(e)))
      .where((e) => e.code.isNotEmpty || e.name.isNotEmpty)
      .toList();
  if (courses.isEmpty) return null;
  final stated = double.tryParse('${payload['graduationCredits'] ?? ''}');
  return TeachingPlan(
    programName: '${payload['programName'] ?? ''}',
    graduationCredits: stated != null && stated > 0
        ? stated
        : courses.fold(0, (sum, course) => sum + course.credits),
    courses: courses,
  );
}

/// 注入后持续监听：用户选定自己的计划、切换到「课程信息」页后，自动把
/// jqGrid 扩为单页并回传全部课程。不会点击查询、提交或修改教务数据。
const teachingPlanCaptureScript = r'''
(function () {
  if (window.__zfjwPlanCapture) return;
  window.__zfjwPlanCapture = true;
  function clean(v) { return String(v == null ? '' : v).replace(/[\s\u200b-\u200f\ufeff]/g, '').trim(); }
  function report(p) { try { window.flutter_inappwebview.callHandler('zfjwTeachingPlanCapture', p); } catch (_) {} }
  var ticks = 0, sent = false;
  var timer = setInterval(function () {
    if (sent) return clearInterval(timer);
    ticks++;
    var $ = window.jQuery;
    var grid = document.getElementById('kcxxGrid');
    if (!grid || !$ || !$.fn.jqGrid) {
      if (ticks > 600) { clearInterval(timer); report({status:'error', message:'请选定教学计划并打开“课程信息”页'}); }
      return;
    }
    var q = $('#kcxxGrid');
    if (!window.__zfjwPlanExpanded) {
      window.__zfjwPlanExpanded = true;
      q.jqGrid('setGridParam', {rowNum: 5000, page: 1}).trigger('reloadGrid');
      return;
    }
    var rows = q.jqGrid('getGridParam', 'data') || [];
    if (!rows.length) return;
    var result = rows.map(function (row) { var out = {}; for (var k in row) out[k] = clean(row[k]); return out; });
    var info = document.body.innerText || '';
    var program = (info.match(/年级：([^\s]+)\s*专业：([^\s]+)/) || []);
    sent = true; clearInterval(timer);
    report({status:'ok', courses:result, programName: program.length ? program[1] + program[2] : '', graduationCredits:''});
  }, 500);
})();
''';
