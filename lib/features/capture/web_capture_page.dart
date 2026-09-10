import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zfjw_toolkit/capture/capture_script.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

class WebCaptureResult {
  const WebCaptureResult.success([this.message = '采集完成']) : error = false;
  const WebCaptureResult.failure(this.message) : error = true;
  final String message;
  final bool error;
}

class WebCapturePage extends StatefulWidget {
  const WebCapturePage({super.key, required this.title, required this.instruction, required this.handlerName, required this.matchesPage, required this.script, required this.onPayload, required this.onSuccess});
  final String title, instruction, handlerName, script;
  final bool Function(String?) matchesPage;
  final Future<WebCaptureResult> Function(Map<String, dynamic>, InAppWebViewController) onPayload;
  final VoidCallback onSuccess;
  @override State<WebCapturePage> createState() => _WebCapturePageState();
}

class _WebCapturePageState extends State<WebCapturePage> {
  String? _message; bool _finished = false; bool _error = false;
  @override Widget build(BuildContext context) {
    final tokens = AppTokens.of(context); final text = _message ?? widget.instruction;
    return AppGlassScaffold(extendBody: false, appBar: AppGlassAppBar(title: Text(widget.title), leading: _finished ? null : AppGlassIconButton(icon: CupertinoIcons.back, onTap: () => Navigator.pop(context))), body: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: AppTokens.space4, vertical: AppTokens.space3), decoration: BoxDecoration(color: _error ? tokens.danger.withAlpha(20) : tokens.accentSubtle, border: Border(bottom: BorderSide(color: tokens.separator, width: .5))), child: Row(children: [
        if (!_finished) const SizedBox(width:14,height:14,child:AppGlassProgress(size:14)) else Icon(_error ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.check_mark_circled_solid, color: _error ? tokens.danger : tokens.success, size:16), const SizedBox(width:AppTokens.space2), Expanded(child: Text(text, style: AppText.footnote.copyWith(color: tokens.labelPrimary, fontWeight: FontWeight.w500))),
      ])),
      Expanded(child: InAppWebView(initialUrlRequest: URLRequest(url: WebUri(zfjwDefaultEntryUrl)), initialSettings: InAppWebViewSettings(javaScriptEnabled:true, thirdPartyCookiesEnabled:true), onWebViewCreated: (c) { c.addJavaScriptHandler(handlerName: widget.handlerName, callback: (args) async { if (args.isEmpty || args.first is! Map) return null; final result = await widget.onPayload(Map<String,dynamic>.from(args.first as Map), c); if (!mounted) return null; setState(() { _message=result.message; _error=result.error; _finished=true; }); if (!result.error) widget.onSuccess(); return null; }); }, onLoadStop: (c,url) async { if (widget.matchesPage(url?.toString())) { setState(() => _message = '正在采集数据…'); await c.evaluateJavascript(source: widget.script); } else if (_message == null) { setState(() {}); } }, onReceivedError: (_, request, error) { if (request.isForMainFrame ?? false) setState(() { _message='网络错误：${error.description}'; _error=true; _finished=true; }); }))
    ]));
  }
}
