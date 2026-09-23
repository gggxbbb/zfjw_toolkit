import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zfjw_toolkit/capture/capture_script.dart';
import 'package:zfjw_toolkit/platform/webview_runtime.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

class WebCaptureResult {
  const WebCaptureResult.review(
    this.message, {
    required this.overview,
    required this.commit,
  }) : error = false;
  const WebCaptureResult.failure(this.message)
    : error = true,
      overview = const [],
      commit = null;
  final String message;
  final bool error;
  final List<String> overview;
  final Future<void> Function()? commit;
}

enum CaptureReviewAction { retry, accept }

Future<CaptureReviewAction?> showCaptureOverview(
  BuildContext context,
  WebCaptureResult result,
) => showCupertinoDialog<CaptureReviewAction>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => CupertinoAlertDialog(
    title: Text(
      '采集概览',
      style: AppText.title.copyWith(
        color: AppTokens.of(dialogContext).labelPrimary,
      ),
    ),
    content: Padding(
      padding: const EdgeInsets.only(top: AppTokens.space3),
      child: Text(
        [result.message, ...result.overview].join('\n'),
        style: AppText.subhead.copyWith(
          color: AppTokens.of(dialogContext).labelPrimary,
        ),
      ),
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: () =>
            Navigator.of(dialogContext).pop(CaptureReviewAction.retry),
        child: Text(
          '重新采集',
          style: AppText.body.copyWith(
            color: AppTokens.of(dialogContext).accent,
          ),
        ),
      ),
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: () =>
            Navigator.of(dialogContext).pop(CaptureReviewAction.accept),
        child: Text(
          '使用本次数据',
          style: AppText.body.copyWith(
            color: AppTokens.of(dialogContext).accent,
          ),
        ),
      ),
    ],
  ),
);

class WebCapturePage extends StatefulWidget {
  const WebCapturePage({
    super.key,
    required this.title,
    required this.instruction,
    this.targetPageStatus = '正在采集数据…',
    this.progressMessage,
    required this.handlerName,
    required this.matchesPage,
    required this.script,
    required this.onPayload,
    required this.onSuccess,
    this.manualCapture = false,
    this.review,
  });
  final String title, instruction, targetPageStatus, handlerName, script;
  final String? Function(Map<String, dynamic> payload)? progressMessage;
  final bool Function(String?) matchesPage;
  final Future<WebCaptureResult> Function(
    Map<String, dynamic>,
    InAppWebViewController,
  )
  onPayload;
  final VoidCallback onSuccess;
  final bool manualCapture;
  final Future<CaptureReviewAction?> Function(BuildContext, WebCaptureResult)?
  review;
  @override
  State<WebCapturePage> createState() => _WebCapturePageState();
}

class _WebCapturePageState extends State<WebCapturePage> {
  String? _message;
  bool _finished = false;
  bool _error = false;
  InAppWebViewController? _controller;
  bool _targetReady = false;
  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final initializationError = AppWebViewRuntime.initializationError;
    final finished = _finished || initializationError != null;
    final error = _error || initializationError != null;
    final text = initializationError ?? _message ?? widget.instruction;
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: Text(
          widget.title,
          style: AppText.title.copyWith(
            color: AppTokens.of(context).labelPrimary,
          ),
        ),
        leading: finished && !error
            ? null
            : AppGlassIconButton(
                icon: CupertinoIcons.back,
                onTap: () => Navigator.pop(context),
              ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space4,
              vertical: AppTokens.space3,
            ),
            decoration: BoxDecoration(
              color: error ? tokens.danger.withAlpha(20) : tokens.accentSubtle,
              border: Border(
                bottom: BorderSide(color: tokens.separator, width: .5),
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
                    error
                        ? CupertinoIcons.exclamationmark_circle
                        : CupertinoIcons.check_mark_circled_solid,
                    color: error ? tokens.danger : tokens.success,
                    size: 16,
                  ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: Text(
                    text,
                    style: AppText.footnote.copyWith(
                      color: tokens.labelPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.manualCapture)
            Padding(
              padding: const EdgeInsets.all(8),
              child: AppGlassButton(
                label: '采集当前学期',
                onTap: _targetReady && _controller != null
                    ? () async {
                        setState(() {
                          _finished = false;
                          _error = false;
                          _message = '正在读取课表…';
                        });
                        await _controller!.evaluateJavascript(
                          source: widget.script,
                        );
                      }
                    : null,
              ),
            ),
          Expanded(child: _buildWebView(tokens, initializationError)),
        ],
      ),
    );
  }

  Widget _buildWebView(AppTokens tokens, String? initializationError) {
    if (initializationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.pagePadding),
          child: Text(
            '采集功能暂不可用。请安装或修复 Microsoft Edge WebView2 Runtime，'
            '然后重新启动应用。',
            style: AppText.body.copyWith(color: tokens.danger),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return InAppWebView(
      webViewEnvironment: AppWebViewRuntime.environment,
      initialUrlRequest: URLRequest(url: WebUri(zfjwDefaultEntryUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        thirdPartyCookiesEnabled: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: widget.handlerName,
          callback: (args) async {
            if (args.isEmpty || args.first is! Map) return null;
            final payload = Map<String, dynamic>.from(args.first as Map);
            final progress = widget.progressMessage?.call(payload);
            if (progress != null) {
              if (mounted) setState(() => _message = progress);
              return null;
            }
            final result = await widget.onPayload(payload, controller);
            if (!mounted) return null;
            if (!result.error) {
              await _reviewSuccessfulCapture(result, controller);
              return null;
            }
            setState(() {
              _message = result.message;
              _error = result.error;
              _finished = true;
            });
            return null;
          },
        );
      },
      onLoadStop: (controller, url) async {
        if (mounted) {
          setState(() => _targetReady = widget.matchesPage(url?.toString()));
        }
        if (widget.matchesPage(url?.toString())) {
          setState(() => _message = widget.targetPageStatus);
          if (!widget.manualCapture) {
            await controller.evaluateJavascript(source: widget.script);
          }
        } else if (_message == null) {
          setState(() {});
        }
      },
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame ?? false) {
          setState(() {
            _message = '网络错误：${error.description}';
            _error = true;
            _finished = true;
          });
        }
      },
    );
  }

  Future<void> _reviewSuccessfulCapture(
    WebCaptureResult result,
    InAppWebViewController controller,
  ) async {
    setState(() {
      _message = result.message;
      _error = false;
      _finished = true;
    });

    final action = await (widget.review ?? showCaptureOverview)(
      context,
      result,
    );
    if (!mounted) return;

    if (action != CaptureReviewAction.accept) {
      if (widget.manualCapture) {
        setState(() {
          _finished = false;
          _message = widget.instruction;
        });
        return;
      }
      setState(() {
        _message = '正在重新采集…';
        _error = false;
        _finished = false;
      });
      await controller.evaluateJavascript(source: widget.script);
      return;
    }

    try {
      await result.commit!.call();
      if (!mounted) return;
      widget.onSuccess();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = '保存采集结果失败：$error';
        _error = true;
        _finished = true;
      });
    }
  }
}
