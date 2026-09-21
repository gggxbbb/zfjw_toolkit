import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/features/capture/web_capture_page.dart';
import 'package:zfjw_toolkit/platform/webview_runtime.dart';

void main() {
  tearDown(() {
    AppWebViewRuntime.initializationError = null;
    AppWebViewRuntime.environment = null;
  });

  testWidgets('WebView2 初始化失败时显示修复说明并允许返回', (tester) async {
    AppWebViewRuntime.initializationError = '未检测到 WebView2 Runtime。';

    await tester.pumpWidget(
      CupertinoApp(
        home: WebCapturePage(
          title: '成绩采集',
          instruction: '打开成绩页',
          handlerName: 'capture',
          matchesPage: (_) => false,
          script: '',
          onPayload: (_, _) async => WebCaptureResult.review(
            '采集完成',
            overview: const [],
            commit: () async {},
          ),
          onSuccess: () {},
        ),
      ),
    );

    expect(find.text('未检测到 WebView2 Runtime。'), findsOneWidget);
    expect(
      find.textContaining('安装或修复 Microsoft Edge WebView2 Runtime'),
      findsOneWidget,
    );
    expect(find.byIcon(CupertinoIcons.back), findsOneWidget);
  });

  testWidgets('采集概览显示数据范围并可选择重新采集', (tester) async {
    Future<CaptureReviewAction?>? pendingDecision;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () {
              pendingDecision = showCaptureOverview(
                context,
                const WebCaptureResult.review(
                  '读取完成',
                  overview: ['成绩记录：40 条', '覆盖学期：6 个'],
                  commit: _noOpCommit,
                ),
              );
            },
            child: const Text('打开概览'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开概览'));
    await tester.pumpAndSettle();

    expect(find.text('采集概览'), findsOneWidget);
    expect(find.textContaining('成绩记录：40 条'), findsOneWidget);
    expect(find.textContaining('覆盖学期：6 个'), findsOneWidget);
    expect(find.text('重新采集'), findsOneWidget);
    expect(find.text('使用本次数据'), findsOneWidget);

    await tester.tap(find.text('重新采集'));
    await tester.pumpAndSettle();
    expect(await pendingDecision, CaptureReviewAction.retry);
  });
}

Future<void> _noOpCommit() async {}
