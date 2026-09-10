import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/capture/capture_flow.dart';
import 'package:zfjw_toolkit/capture/capture_script.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 全屏 WebView 采集页。
///
/// 用户在 WebView 内自行完成教务登录（cookie 由 WebView 持久化，下次免登）；
/// URL 命中成绩查询页后自动注入采集脚本，JS 桥回传后经解析器入库为快照。
///
/// 本页是**推入的全屏路由**（非 tab），WebView 自身填满视口，因此
/// `extendBody: false`——内容不需要从玻璃栏下穿过。顶部玻璃栏自带返回按钮。
class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key});

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  InAppWebViewController? _controller;
  CaptureState _state = CaptureState.loading;
  String? _message;

  Future<void> _onPayload(Map<String, dynamic> payload) async {
    final outcome = handleCapturePayload(
      payload,
      fallbackHtml: () => null, // 同步桥内无法 await getHtml；缺列时二次请求
    );

    // 同步回退不可行时（需要异步 getHtml），在此补一次。
    if (outcome.state == CaptureState.failed &&
        (outcome.error ?? '').contains('无法获取页面 HTML')) {
      final html = await _controller?.getHtml();
      final retried = handleCapturePayload(payload, fallbackHtml: () => html);
      await _finish(retried);
      return;
    }
    await _finish(outcome);
  }

  Future<void> _finish(CaptureOutcome outcome) async {
    if (!mounted) return;
    if (outcome.state == CaptureState.done && outcome.records != null) {
      final repo = ref.read(snapshotRepositoryProvider);
      await repo.saveSnapshot(
        kDefaultProfileId,
        SnapshotSource.webview,
        outcome.records!,
      );
      ref.invalidate(latestSnapshotProvider);
      // 采集成功后回到根级成绩页；从导入页进入时也一并跳过中间路由。
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      setState(() {
        _state = CaptureState.failed;
        _message = outcome.error ?? '采集失败';
      });
    }
  }

  String get _statusText => switch (_state) {
        CaptureState.loading => '页面加载中…',
        CaptureState.awaitingLogin => '请在页面内完成教务登录',
        CaptureState.navigating => '正在进入成绩查询页…',
        CaptureState.capturing => '正在采集成绩数据…',
        CaptureState.done => _message ?? '采集完成',
        CaptureState.failed => _message ?? '采集失败',
      };

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final finished =
        _state == CaptureState.done || _state == CaptureState.failed;

    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: const Text('成绩采集'),
        leading: finished
            ? null
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTokens.space2),
                  child: Icon(
                    CupertinoIcons.back,
                    color: tokens.accent,
                  ),
                ),
              ),
      ),
      body: Column(
        children: [
          // 状态条。
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space4,
              vertical: AppTokens.space3,
            ),
            decoration: BoxDecoration(
              color: finished && _state == CaptureState.failed
                  ? tokens.danger.withAlpha(20)
                  : tokens.accentSubtle,
              border: Border(
                bottom: BorderSide(color: tokens.separator, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                if (!finished)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: AppGlassProgress(size: 14),
                  )
                else
                  Icon(
                    _state == CaptureState.done
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.exclamationmark_circle,
                    size: 16,
                    color: _state == CaptureState.done
                        ? tokens.success
                        : tokens.danger,
                  ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: Text(
                    _statusText,
                    style: AppText.footnote.copyWith(
                      color: tokens.labelPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(zfjwDefaultEntryUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                // cookie 持久化：登录态留在 WebView 存储，下次免登。
                thirdPartyCookiesEnabled: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                controller.addJavaScriptHandler(
                  handlerName: zfjwCaptureHandlerName,
                  callback: (args) {
                    if (args.isNotEmpty && args.first is Map) {
                      _onPayload(Map<String, dynamic>.from(args.first as Map));
                    }
                    return null;
                  },
                );
              },
              onLoadStop: (controller, url) async {
                final urlStr = url?.toString();
                if (isGradePageUrl(urlStr)) {
                  setState(() {
                    _state = CaptureState.capturing;
                    _message = null;
                  });
                  await controller.evaluateJavascript(
                    source: zfjwCaptureScript,
                  );
                } else if (_state == CaptureState.loading) {
                  setState(() => _state = CaptureState.awaitingLogin);
                }
              },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame ?? false) {
                  setState(() {
                    _state = CaptureState.failed;
                    _message = '网络错误：${error.description}';
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
