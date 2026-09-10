import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/capture/capture_flow.dart';
import 'package:zfjw_toolkit/capture/capture_script.dart';

void main() {
  group('capture_script 内容完整性', () {
    test('包含桥 handler 名与成绩页标记', () {
      expect(zfjwCaptureScript, contains(zfjwCaptureHandlerName));
      expect(zfjwCaptureScript, contains('callHandler'));
      expect(zfjwGradePageMarker, 'cjcx_cxDgXscj.html');
    });

    test('脚本含两条解析路径与全范围查询逻辑', () {
      expect(zfjwCaptureScript, contains("jqGrid('getGridParam', 'data')"));
      expect(zfjwCaptureScript, contains('aria-describedby'));
      expect(zfjwCaptureScript, contains('rowNum: 10000'));
      expect(zfjwCaptureScript, contains('search_go'));
      // 污染字符清洗与油猴一致。
      expect(zfjwCaptureScript, contains(r'[\p{Cf}\p{Zs}]'));
    });
  });

  group('isGradePageUrl', () {
    test('命中成绩查询页', () {
      expect(
        isGradePageUrl('https://jwpt.xzhmu.edu.cn/cjcx/cjcx_cxDgXscj.html?a=1'),
        isTrue,
      );
    });

    test('其他页面与 null 不命中', () {
      expect(isGradePageUrl('https://jwpt.xzhmu.edu.cn/'), isFalse);
      expect(isGradePageUrl(null), isFalse);
    });
  });

  group('handleCapturePayload', () {
    Map<String, dynamic> row({Map<String, dynamic>? extra}) => {
          'kch': 'A01',
          'kcmc': '高等数学',
          'xf': '4',
          'jd': '4.0',
          'bfzcj': '90',
          'cj': '90',
          'sfxwkc': '是',
          'xnm': '2024',
          'xqm': '1',
          ...?extra,
        };

    test('ok 完整行 → done', () {
      final outcome = handleCapturePayload({
        'status': 'ok',
        'path': 'data',
        'rows': [row()],
      });
      expect(outcome.state, CaptureState.done);
      expect(outcome.records, hasLength(1));
      expect(outcome.records!.single.kcmc, '高等数学');
    });

    test('error → failed 携带脚本消息', () {
      final outcome = handleCapturePayload({
        'status': 'error',
        'message': '等待成绩表格超时',
      });
      expect(outcome.state, CaptureState.failed);
      expect(outcome.error, contains('超时'));
    });

    test('空 rows → failed', () {
      final outcome = handleCapturePayload({
        'status': 'ok',
        'path': 'data',
        'rows': <Map<String, dynamic>>[],
      });
      expect(outcome.state, CaptureState.failed);
    });

    test('JSON 缺关键列 → 回退 HTML 成功则 done', () {
      final incomplete = {
        'status': 'ok',
        'path': 'data',
        'rows': [
          {
            'kch': 'A01',
            'kcmc': '高等数学',
            'xf': '4',
            // 缺 sfxwkc / bfzcj —— 触发 incompleteColumns 回退
          },
        ],
      };
      final outcome = handleCapturePayload(
        incomplete,
        fallbackHtml: () => '<html><body><table id="tabGrid">'
            '<tr class="jqgrow">'
            '<td aria-describedby="tabGrid_kch">A01</td>'
            '<td aria-describedby="tabGrid_kcmc">高等数学</td>'
            '<td aria-describedby="tabGrid_bfzcj">90</td>'
            '</tr></table></body></html>',
      );
      expect(outcome.state, CaptureState.done);
      expect(outcome.records!.single.bfzcj, '90');
    });

    test('JSON 缺列且无 HTML 回退 → failed', () {
      final outcome = handleCapturePayload({
        'status': 'ok',
        'path': 'data',
        'rows': [
          {'kch': 'A01', 'kcmc': '高等数学'},
        ],
      });
      expect(outcome.state, CaptureState.failed);
      expect(outcome.error, contains('HTML'));
    });
  });
}
