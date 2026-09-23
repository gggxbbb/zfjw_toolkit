const timetablePageMarker = 'xskbcx_cxXskbcxIndex.html';
const timetableHandler = 'zfjwTimetableCapture';

// A read-only DOM extractor, shared by the injected polling loop and JS tests.
const timetableExtractFunction = r'''
function extractTimetable(doc) {
  function textOf(node) {
    return String(node?.textContent ?? node?.innerText ?? node?.text ?? '').trim();
  }
  const table = doc.querySelector('#kbgrid_table_0');
  const year = doc.querySelector('#xnm');
  const term = doc.querySelector('#xqm');
  if (!table || !year || !term) throw new Error('未找到完整课表，请先查询学期');
  const yearText = textOf(year.selectedOptions?.[0]);
  const termText = textOf(term.selectedOptions?.[0]);
  const heading = textOf(table.querySelector('h6')).replace(/\s/g, '');
  const expected = `${yearText}学年第${termText}学期`;
  if (!heading || heading !== expected) throw new Error('选择的学期与课表不一致，请点击查询并等待加载');
  const headerRow = Array.from(table.rows).find(r =>
    Array.from(r.cells).some(c => textOf(c) === '星期一'));
  if (!headerRow || !['一','二','三','四','五','六','日'].every(d =>
      Array.from(headerRow.cells).some(c => textOf(c) === `星期${d}`))) {
    throw new Error('无法确认课表星期表头');
  }
  const rows = Array.from(table.querySelectorAll('.timetable_con')).map(block => {
    const cell = block.closest('td');
    const match = /^([1-7])-(\d+)$/.exec(cell?.id || '');
    if (!match) throw new Error('无法识别星期：' + textOf(block));
    const fields = {};
    for (const p of block.querySelectorAll('p')) {
      const label = p.querySelector('[title]')?.getAttribute('title')?.trim();
      if (label) fields[label] = textOf(p);
    }
    return {day: Number(match[1]), title: textOf(block.querySelector('.title')),
      time: fields['节/周'] || '', teacher: fields['教师'] || '',
      location: fields['上课地点'] || '', group: fields['教学班名称'] || ''};
  });
  const explicitEmpty = rows.length === 0 && /(?:本学期无课|本学期暂无课表|暂无课表|无课程安排)/.test(textOf(table));
  if (!rows.length && !explicitEmpty) throw new Error('未找到课次，页面也未明确显示本学期无课');
  return {status: 'ok', term: `${year.value}/${term.value}`, label: expected, rows, explicitEmpty};
}
''';

const timetableCaptureScript =
    '''
(function() {
  $timetableExtractFunction
'''
    r'''
  if (window.__timetableCaptureCancel) window.__timetableCaptureCancel();
  let cancelled = false;
  window.__timetableCaptureCancel = () => { cancelled = true; };
  let previous = '', stable = 0, attempts = 0, lastError = '页面仍在加载';
  function send(payload) {
    if (!cancelled) window.flutter_inappwebview.callHandler('zfjwTimetableCapture', payload);
  }
  function poll() {
    if (cancelled) return;
    attempts++;
    try {
      if (document.readyState !== 'complete' ||
          (window.jQuery && window.jQuery.active > 0) ||
          document.querySelector('[aria-busy="true"]')) throw new Error('页面仍在加载，请稍候');
      const result = extractTimetable(document);
      const current = JSON.stringify(result);
      stable = current === previous ? stable + 1 : 0;
      previous = current;
      if (stable >= 3) { send(result); return; }
    } catch (error) { lastError = error.message; stable = 0; previous = ''; }
    if (attempts >= 30) { send({status:'error', message:lastError}); return; }
    setTimeout(poll, 500);
  }
  poll();
})();
''';
