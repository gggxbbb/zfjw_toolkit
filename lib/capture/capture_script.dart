/// 注入到正方教务成绩查询页的采集脚本（JS 源码常量）。
///
/// 油猴 `jwpt-gpa.user.js` 采集逻辑的注入版：
/// 等待 jqGrid 就绪 → 全范围自动查询 → 优先原始 JSON，缺列回退 DOM →
/// 经 `window.flutter_inappwebview.callHandler('zfjwCapture', payload)` 回传一次。
///
/// payload 形态：
/// - `{status:'ok', path:'data'|'dom', rows:[{kch,...}]}`
/// - `{status:'error', message:'...'}`
///
/// 本文件为纯 Dart 常量，内容完整性可单测（见 test/capture/）。
const String zfjwCaptureHandlerName = 'zfjwCapture';

/// 成绩查询页 URL 特征（命中即注入脚本）。
const String zfjwGradePageMarker = 'cjcx_cxDgXscj.html';

/// 教务系统入口 URL（默认徐医网上办事大厅，经统一认证后才能进教务；
/// 直连 jwpt 域名无法完成登录）。
const String zfjwDefaultEntryUrl = 'https://ehall.xzhmu.edu.cn/';

const String zfjwCaptureScript = r'''
(function () {
  'use strict';
  if (window.__zfjwCaptureLoaded) return;
  window.__zfjwCaptureLoaded = true;

  function report(payload) {
    try {
      window.flutter_inappwebview.callHandler('zfjwCapture', payload);
    } catch (e) { /* 桥未就绪则静默 */ }
  }

  function clean(v) {
    return String(v == null ? '' : v).replace(/[\p{Cf}\p{Zs}]/gu, '').trim();
  }

  // 与油猴一致：优先 jqGrid 原始 JSON（不受列顺序/渲染时序影响），
  // 缺关键列（sfxwkc/bfzcj 仅由 formatter 渲染）时回退 DOM 解析。
  function extract() {
    try {
      var jq = window.jQuery;
      if (jq && jq.fn && jq.fn.jqGrid) {
        var data = jq('#tabGrid').jqGrid('getGridParam', 'data');
        if (data && data.length) {
          var rows = [];
          for (var i = 0; i < data.length; i++) {
            var row = {};
            for (var k in data[i]) {
              if (data[i][k] != null) row[k] = clean(data[i][k]);
            }
            if (row.kch || row.kcmc) rows.push(row);
          }
          if (rows.length &&
              rows[0].sfxwkc !== undefined &&
              rows[0].bfzcj !== undefined) {
            return { status: 'ok', path: 'data', rows: rows };
          }
        }
      }
    } catch (e) { /* 落回 DOM */ }

    var trs = document.querySelectorAll('#tabGrid tr.jqgrow');
    if (!trs.length) return null;
    var domRows = [];
    for (var t = 0; t < trs.length; t++) {
      var cells = trs[t].querySelectorAll('td[aria-describedby^="tabGrid_"]');
      var drow = {};
      for (var c = 0; c < cells.length; c++) {
        var key = cells[c].getAttribute('aria-describedby').slice('tabGrid_'.length);
        drow[key] = clean(cells[c].textContent);
      }
      if (drow.kch || drow.kcmc) domRows.push(drow);
    }
    if (!domRows.length) return null;
    return { status: 'ok', path: 'dom', rows: domRows };
  }

  var tries = 0;
  var reported = false;

  // 自动全范围查询：学年/学期/课程标记全部 + 一次取回全部记录（对齐油猴 init）。
  function configureAndQuery() {
    var jq = window.jQuery;
    try {
      var ids = ['xnm', 'xqm', 'kcbjdm_cx'];
      for (var i = 0; i < ids.length; i++) {
        var sel = document.getElementById(ids[i]);
        if (sel) {
          sel.value = '';
          try { jq('#' + ids[i]).trigger('chosen:updated'); } catch (e) {}
        }
      }
      if (jq && jq.fn && jq.fn.jqGrid) {
        jq('#tabGrid').jqGrid('setGridParam', { rowNum: 10000, page: 1 });
      }
      var btn = document.getElementById('search_go');
      if (btn) btn.click();
      else if (jq) jq('#tabGrid').trigger('reloadGrid');
    } catch (e) { /* 配置失败不阻断监听 */ }
  }

  var timer = setInterval(function () {
    if (reported) { clearInterval(timer); return; }
    tries++;

    var grid = document.getElementById('tabGrid');
    var hasRows = !!document.querySelector('#tabGrid tr.jqgrow');

    if (!grid && !hasRows) {
      if (tries > 50) {
        clearInterval(timer);
        report({ status: 'error', message: '等待成绩表格超时：请确认已登录并进入成绩查询页' });
      }
      return;
    }

    // 网格出现：先触发一次全范围查询，再从下一轮开始尝试提取。
    if (tries === 1 || !window.__zfjwQueried) {
      window.__zfjwQueried = true;
      configureAndQuery();
      return;
    }

    var result = extract();
    if (result) {
      reported = true;
      clearInterval(timer);
      report(result);
    } else if (tries > 50) {
      clearInterval(timer);
      report({ status: 'error', message: '成绩表格存在但无数据行，请先在页面完成查询' });
    }
  }, 300);
})();
''';
