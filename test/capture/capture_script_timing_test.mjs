import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const dartSource = readFileSync(
  new URL('../../lib/capture/capture_script.dart', import.meta.url),
  'utf8',
);
const scriptMatch = dartSource.match(
  /const String zfjwCaptureScript = r'''([\s\S]*?)''';/,
);
assert.ok(scriptMatch, 'cannot locate zfjwCaptureScript');
const captureScript = scriptMatch[1];
const teachingPlanSource = readFileSync(
  new URL('../../lib/capture/teaching_plan_capture.dart', import.meta.url),
  'utf8',
);
const teachingPlanMatch = teachingPlanSource.match(
  /const teachingPlanCaptureScript = r'''([\s\S]*?)''';/,
);
assert.ok(teachingPlanMatch, 'cannot locate teachingPlanCaptureScript');
const teachingPlanScript = teachingPlanMatch[1];

function gradeRow(index) {
  return {
    kch: `C${index}`,
    kcmc: `Course ${index}`,
    sfxwkc: '否',
    bfzcj: '80',
  };
}

function createHarness() {
  const reports = [];
  const timers = [];
  let loadComplete;
  let data = Array.from({ length: 15 }, (_, index) => gradeRow(index));
  let records = 15;
  const params = { rowNum: 15, page: 1 };

  const grid = {
    jqGrid(method, arg) {
      if (method === 'setGridParam') {
        Object.assign(params, arg);
        return grid;
      }
      if (method === 'getGridParam') {
        if (arg === 'data') return data;
        if (arg === 'records') return records;
        if (arg === 'reccount') return data.length;
        if (arg === 'lastpage') return 1;
        return params[arg];
      }
      throw new Error(`unexpected jqGrid call: ${method}`);
    },
    one(event, callback) {
      assert.match(event, /jqGridLoadComplete/);
      loadComplete = callback;
      return grid;
    },
    trigger() {
      return grid;
    },
  };

  function jquery() {
    return grid;
  }
  jquery.fn = { jqGrid() {} };

  const context = {
    window: {
      jQuery: jquery,
      flutter_inappwebview: {
        callHandler(_name, payload) {
          reports.push(payload);
        },
      },
    },
    document: {
      getElementById(id) {
        if (id === 'tabGrid') return {};
        if (id === 'search_go') return { click() {} };
        return null;
      },
      querySelector(selector) {
        return selector === '#tabGrid tr.jqgrow' ? {} : null;
      },
      querySelectorAll() {
        return [];
      },
    },
    setInterval(callback) {
      timers.push(callback);
      return timers.length;
    },
    clearInterval() {},
  };
  context.window.window = context.window;
  context.window.document = context.document;
  context.window.setInterval = context.setInterval;
  context.window.clearInterval = context.clearInterval;

  vm.runInNewContext(captureScript, context);

  return {
    reports,
    tick() {
      assert.ok(timers.length, 'capture script did not start a timer');
      timers.at(-1)();
    },
    completeReload(nextCount) {
      data = Array.from({ length: nextCount }, (_, index) => gradeRow(index));
      records = nextCount;
      assert.ok(loadComplete, 'script did not subscribe to jqGridLoadComplete');
      loadComplete();
    },
  };
}

test('waits for the full-range jqGrid reload before reporting rows', () => {
  const harness = createHarness();

  harness.tick();
  harness.tick();
  assert.equal(
    harness.reports.filter((payload) => payload.status === 'ok').length,
    0,
    'reported the stale first page before jqGrid finished reloading',
  );

  harness.completeReload(40);
  harness.tick();
  const success = harness.reports.find((payload) => payload.status === 'ok');
  assert.ok(success, 'did not report after jqGrid finished reloading');
  assert.equal(success.rows.length, 40);
});

function createTeachingPlanHarness({
  initiallyReady = true,
  initiallyLoading = false,
  initiallyInitialized = true,
} = {}) {
  const reports = [];
  const timers = [];
  let loadComplete;
  let data = Array.from({ length: 15 }, (_, index) => ({
    kch: `P${index}`,
    kcmc: `Plan ${index}`,
  }));
  let records = 15;
  let coursePageReady = initiallyReady;
  let lastPage = 1;
  const params = { rowNum: 15, page: 1 };
  const element = { p: params, grid: { hDiv: { loading: initiallyLoading } } };
  if (!initiallyInitialized) delete element.grid;
  const requests = [];

  const grid = {
    jqGrid(method, arg) {
      if (method === 'setGridParam') {
        Object.assign(params, arg);
        return grid;
      }
      if (method === 'getGridParam') {
        if (arg === 'data') return data;
        if (arg === 'records') return records;
        if (arg === 'reccount') return data.length;
        if (arg === 'lastpage') return lastPage;
        return params[arg];
      }
      throw new Error(`unexpected jqGrid call: ${method}`);
    },
    one(event, callback) {
      assert.match(event, /jqGridLoadComplete/);
      loadComplete = callback;
      return grid;
    },
    trigger(event) {
      assert.equal(event, 'reloadGrid');
      // jqGrid populate() ignores reloads while an earlier request is running.
      if (element.grid && !element.grid.hDiv.loading) {
        requests.push({ ...params });
        element.grid.hDiv.loading = true;
      }
      return grid;
    },
  };
  function jquery() {
    return grid;
  }
  jquery.fn = { jqGrid() {} };

  const context = {
    window: {
      jQuery: jquery,
      flutter_inappwebview: {
        callHandler(_name, payload) {
          reports.push(payload);
        },
      },
    },
    document: {
      body: { innerText: '' },
      getElementById(id) {
        if (id === 'kcxxGrid') return coursePageReady ? element : null;
        if (id === 'messages') {
          return coursePageReady ? { className: 'active' } : null;
        }
        return null;
      },
      querySelectorAll() {
        return [];
      },
    },
    setInterval(callback) {
      timers.push(callback);
      return timers.length;
    },
    clearInterval() {},
  };
  context.window.window = context.window;
  context.window.document = context.document;
  context.window.setInterval = context.setInterval;
  context.window.clearInterval = context.clearInterval;
  vm.runInNewContext(teachingPlanScript, context);

  return {
    reports,
    requests,
    tick() {
      assert.ok(timers.length, 'capture script did not start a timer');
      timers.at(-1)();
    },
    enterCoursePage() {
      coursePageReady = true;
    },
    initializeGrid() {
      element.grid = { hDiv: { loading: false } };
    },
    completeReload(nextCount, totalCount = nextCount) {
      data = Array.from({ length: nextCount }, (_, index) => ({
        kch: `P${index}`,
        kcmc: `Plan ${index}`,
      }));
      records = totalCount;
      lastPage = nextCount ? Math.ceil(totalCount / nextCount) : 0;
      const callback = loadComplete;
      loadComplete = undefined;
      if (callback) callback();
      element.grid.hDiv.loading = false;
    },
  };
}

test('teaching-plan capture also waits for its full grid reload', () => {
  const harness = createTeachingPlanHarness();

  harness.tick();
  harness.tick();
  assert.equal(
    harness.reports.filter((payload) => payload.status === 'ok').length,
    0,
    'reported the stale first teaching-plan page before reload completed',
  );

  harness.completeReload(40);
  harness.tick();
  const success = harness.reports.find((payload) => payload.status === 'ok');
  assert.ok(success, 'did not report the teaching plan after reload completed');
  assert.equal(success.courses.length, 40);
});

test('teaching-plan capture reloads automatically after an in-flight first page finishes', () => {
  const harness = createTeachingPlanHarness({ initiallyLoading: true });
  harness.tick();
  harness.completeReload(15, 40);
  harness.tick();
  assert.equal(
    harness.requests.length,
    1,
    'full reload was lost during the initial load; manual pagination is required',
  );
  assert.equal(harness.requests[0].rowNum, 5000);
  assert.equal(harness.reports.some((payload) => payload.status === 'ok'), false);
  harness.completeReload(40);
  harness.tick();
  assert.equal(harness.reports.find((payload) => payload.status === 'ok')?.courses.length, 40);
});

test('teaching-plan capture waits for jqGrid initialization before starting reload', () => {
  const harness = createTeachingPlanHarness({ initiallyInitialized: false });
  harness.tick();
  harness.initializeGrid();
  harness.tick();
  assert.equal(harness.requests.length, 1);
  harness.completeReload(40);
  harness.tick();
  assert.equal(harness.reports.find((payload) => payload.status === 'ok')?.courses.length, 40);
});

test('teaching-plan capture reports a stuck initial request instead of waiting forever', () => {
  const harness = createTeachingPlanHarness({ initiallyLoading: true });
  for (let index = 0; index < 122; index++) harness.tick();
  assert.equal(harness.requests.length, 0);
  assert.ok(harness.reports.some((payload) => payload.status === 'error'));
});

test('teaching-plan capture reports an empty completed reload instead of waiting forever', () => {
  const harness = createTeachingPlanHarness();
  harness.tick();
  harness.completeReload(0);
  for (let index = 0; index < 122; index++) harness.tick();
  assert.ok(harness.reports.some((payload) => payload.status === 'error'));
  assert.equal(harness.reports.some((payload) => payload.status === 'ok'), false);
});

test('teaching-plan capture rejects a reload that still contains only the first page', () => {
  const harness = createTeachingPlanHarness();
  harness.tick();
  harness.completeReload(15, 40);
  for (let index = 0; index < 122; index++) harness.tick();
  assert.equal(harness.reports.some((payload) => payload.status === 'ok'), false);
  assert.ok(harness.reports.some((payload) => payload.status === 'error'));
});

test('teaching-plan reload timeout starts after the user reaches the course page', () => {
  const harness = createTeachingPlanHarness({ initiallyReady: false });

  for (let index = 0; index < 130; index++) harness.tick();
  assert.equal(harness.reports.length, 0);

  harness.enterCoursePage();
  harness.tick();
  harness.tick();
  assert.equal(
    harness.reports.some((payload) => payload.status === 'error'),
    false,
    'reported a reload timeout inherited from time spent navigating',
  );

  harness.completeReload(40);
  harness.tick();
  const success = harness.reports.find((payload) => payload.status === 'ok');
  assert.equal(success.courses.length, 40);
});
