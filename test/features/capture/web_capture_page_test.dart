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
          onPayload: (_, _) async => const WebCaptureResult.success(),
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
}
