import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(
  new URL('../../lib/capture/timetable_capture.dart', import.meta.url),
  'utf8',
);
const extractorMatch = source.match(
  /const timetableExtractFunction = r'''([\s\S]*?)''';/,
);
assert.ok(extractorMatch, 'cannot locate timetableExtractFunction');

function field(label, value, { textContent = true } = {}) {
  return {
    ...(textContent ? { textContent: value } : { innerText: value }),
    querySelector(selector) {
      if (selector !== '[title]') return null;
      return { getAttribute: () => `${label} ` };
    },
  };
}

function timetableDocument({ heading = '2026-2027学年第1学期', rows = [{}], emptyText = '', optionTextContent = true, weekdayText } = {}) {
  const yearOption = optionTextContent ? { textContent: '2026-2027' } : { text: '2026-2027' };
  const termOption = optionTextContent ? { textContent: '1' } : { text: '1' };
  const year = { value: '2026', selectedOptions: [yearOption] };
  const term = { value: '3', selectedOptions: [termOption] };
  const blocks = rows.map((row) => ({
    textContent: row.title ?? '课程★',
    closest: () => ({ id: row.cell ?? '4-11' }),
    querySelector(selector) {
      return selector === '.title' ? { textContent: row.title ?? '课程★' } : null;
    },
    querySelectorAll: () => [
      field('节/周', row.time ?? '(11-13节)7-9周'),
      field('上课地点', row.location ?? '地点'),
      field('教师', row.teacher ?? '教师'),
      field('教学班名称', row.group ?? '教学班'),
    ],
  }));
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  const table = {
    textContent: emptyText,
    rows: [{ cells: weekdays.map((d) => ({ textContent: weekdayText?.(d) ?? `星期${d}` })) }],
    querySelector: (selector) => selector === 'h6' ? { textContent: heading } : null,
    querySelectorAll: (selector) => selector === '.timetable_con' ? blocks : [],
  };
  return {
    querySelector(selector) {
      return { '#kbgrid_table_0': table, '#xnm': year, '#xqm': term }[selector] ?? null;
    },
  };
}

const context = {};
vm.createContext(context);
vm.runInContext(extractorMatch[1], context);

test('extracts weekday from merged-cell id and trims labelled fields', () => {
  const result = context.extractTimetable(timetableDocument());
  assert.equal(result.term, '2026/3');
  assert.equal(result.label, '2026-2027学年第1学期');
  assert.deepEqual(JSON.parse(JSON.stringify(result.rows[0])), {
    day: 4,
    title: '课程★',
    time: '(11-13节)7-9周',
    teacher: '教师',
    location: '地点',
    group: '教学班',
  });
});

test('tolerates WebView text proxies without textContent', () => {
  const doc = timetableDocument({ optionTextContent: false });
  const block = doc.querySelector('#kbgrid_table_0').querySelectorAll('.timetable_con')[0];
  block.querySelectorAll = () => [
    field('节/周', '(11-13节)7-9周', { textContent: false }),
    field('上课地点', '地点'),
    field('教师', '教师'),
    field('教学班名称', '教学班'),
  ];
  const result = context.extractTimetable(doc);
  assert.equal(result.label, '2026-2027学年第1学期');
  assert.equal(result.rows[0].time, '(11-13节)7-9周');
});

test('accepts weekday headers whose markup inserts whitespace and helper text', () => {
  const result = context.extractTimetable(timetableDocument({
    weekdayText: (day) => ` 星\n期 ${day} 课程列 `,
  }));
  assert.equal(result.rows[0].day, 4);
});

test('rejects a stale table whose heading differs from selected term', () => {
  assert.throws(
    () => context.extractTimetable(timetableDocument({ heading: '2025-2026学年第2学期' })),
    /选择的学期与课表不一致/,
  );
});

test('only accepts empty results when the page explicitly says there are no classes', () => {
  assert.throws(
    () => context.extractTimetable(timetableDocument({ rows: [] })),
    /页面也未明确显示本学期无课/,
  );
  const result = context.extractTimetable(
    timetableDocument({ rows: [], emptyText: '本学期无课' }),
  );
  assert.equal(result.explicitEmpty, true);
  assert.deepEqual(JSON.parse(JSON.stringify(result.rows)), []);
});
