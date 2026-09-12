import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zfjw_toolkit/capture/capture_script.dart';
import 'package:zfjw_toolkit/platform/webview_runtime.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

class WebCaptureResult {
  const WebCaptureResult.success([this.message = '采集完成']) : error = false;
  const WebCaptureResult.failure(this.message) : error = true;
  final String message;
  final bool error;
}

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
  @override
  State<WebCapturePage> createState() => _WebCapturePageState();
}

class _WebCapturePageState extends State<WebCapturePage> {
  String? _message;
  bool _finished = false;
  bool _error = false;
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
        title: Text(widget.title),
        leading: AppGlassIconButton(
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
            setState(() {
              _message = result.message;
              _error = result.error;
              _finished = true;
            });
            if (!result.error) widget.onSuccess();
            return null;
          },
        );
      },
      onLoadStop: (controller, url) async {
        if (widget.matchesPage(url?.toString())) {
          setState(() => _message = widget.targetPageStatus);
          await controller.evaluateJavascript(source: widget.script);
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
}
