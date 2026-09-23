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
  if (window.__zfjwPlanTimer) clearInterval(window.__zfjwPlanTimer);
  var runId = (window.__zfjwPlanRunId || 0) + 1;
  window.__zfjwPlanRunId = runId;
  window.__zfjwPlanExpanded = false;
  window.__zfjwPlanLoaded = false;
  window.__zfjwPlanIncomplete = null;
  function clean(v) { return String(v == null ? '' : v).replace(/[\s\u200b-\u200f\ufeff]/g, '').trim(); }
  function report(p) {
    if (window.__zfjwPlanRunId !== runId) return;
    try { window.flutter_inappwebview.callHandler('zfjwTeachingPlanCapture', p); } catch (_) {}
  }
  var ticks = 0, readyTicks = 0, reloadTicks = 0, sent = false;
  var timer = window.__zfjwPlanTimer = setInterval(function () {
    if (sent) return clearInterval(timer);
    ticks++;
    var $ = window.jQuery;
    var grid = document.getElementById('kcxxGrid');
    var coursePanel = document.getElementById('messages');
    var courseTabIsActive = coursePanel && /(^|\s)active(\s|$)/.test(coursePanel.className);
    if (!grid || !courseTabIsActive || !$ || !$.fn || !$.fn.jqGrid) {
      if (ticks > 600) { clearInterval(timer); report({status:'error', message:'请选定教学计划并打开“课程信息”页'}); }
      return;
    }
    var q = $('#kcxxGrid');
    if (!window.__zfjwPlanExpanded) {
      // 表格 DOM 出现不代表 jqGrid 已初始化；初次请求仍在进行时，
      // jqGrid 会忽略 reloadGrid。必须等它空闲后再标记并发起全量重载。
      if (!grid.p || !grid.grid || !grid.grid.hDiv || grid.grid.hDiv.loading) {
        readyTicks++;
        if (readyTicks > 120) {
          clearInterval(timer);
          report({status:'error', message:'等待课程表初始化或首次加载超时，请重新采集'});
        }
        return;
      }
      window.__zfjwPlanExpanded = true;
      reloadTicks = 0;
      report({status:'progress', message:'正在采集全部课程信息…'});
      q.one('jqGridLoadComplete.zfjwPlanCapture', function () {
        if (window.__zfjwPlanRunId === runId) window.__zfjwPlanLoaded = true;
      });
      q.jqGrid('setGridParam', {rowNum: 5000, page: 1}).trigger('reloadGrid');
      return;
    }
    reloadTicks++;
    if (!window.__zfjwPlanLoaded) {
      if (reloadTicks > 120) {
        clearInterval(timer);
        report({status:'error', message:'等待全量课程加载超时，请重新采集'});
      }
      return;
    }
    var rows = q.jqGrid('getGridParam', 'data') || [];
    var expected = Number(q.jqGrid('getGridParam', 'records')) || 0;
    var lastPage = Number(q.jqGrid('getGridParam', 'lastpage')) || 1;
    if ((expected && rows.length < expected) || lastPage > 1) {
      window.__zfjwPlanIncomplete = {actual: rows.length, expected: expected};
      rows = [];
    }
    // 部分正方版本只渲染 jqGrid DOM，不填充 data 参数；此时按列名回退。
    if (!rows.length) {
      rows = [];
      var domRows = document.querySelectorAll('#kcxxGrid tr.jqgrow');
      if ((expected && domRows.length < expected) || lastPage > 1) {
        window.__zfjwPlanIncomplete = {actual: domRows.length, expected: expected};
        domRows = [];
      }
      for (var i = 0; i < domRows.length; i++) {
        var domRow = {};
        var cells = domRows[i].querySelectorAll('td[aria-describedby^="kcxxGrid_"]');
        for (var j = 0; j < cells.length; j++) {
          var key = cells[j].getAttribute('aria-describedby').slice('kcxxGrid_'.length);
          domRow[key] = clean(cells[j].textContent);
        }
        if (domRow.kch || domRow.kcmc) rows.push(domRow);
      }
    }
    if (!rows.length) {
      if (reloadTicks > 120) {
        var partial = window.__zfjwPlanIncomplete;
        clearInterval(timer);
        report({
          status:'error',
          message:partial
            ? '课程尚未完整加载：已加载 ' + partial.actual + ' / ' + partial.expected + ' 门，请重新采集'
            : '课程表加载完成但无课程数据，请确认已选定教学计划后重新采集'
        });
      }
      return;
    }
    var result = rows.map(function (row) { var out = {}; for (var k in row) out[k] = clean(row[k]); return out; });
    var info = document.body.innerText || '';
    var program = (info.match(/年级：([^\s]+)\s*专业：([^\s]+)/) || []);
    sent = true; clearInterval(timer);
    report({status:'ok', courses:result, programName: program.length ? program[1] + program[2] : '', graduationCredits:''});
  }, 500);
})();
''';
