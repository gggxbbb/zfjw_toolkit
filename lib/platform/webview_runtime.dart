import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

/// Windows WebView2 environment shared by every capture page.
///
/// WebView2 needs a writable user-data directory. Creating the environment at
/// startup also lets the app report a missing runtime before constructing the
/// native WebView widget.
final class AppWebViewRuntime {
  AppWebViewRuntime._();

  static WebViewEnvironment? environment;
  static String? initializationError;

  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;

    try {
      final version = await WebViewEnvironment.getAvailableVersion();
      if (version == null) {
        initializationError =
            '未检测到 Microsoft Edge WebView2 Runtime。请安装 WebView2 后重试。';
        return;
      }

      final supportDirectory = await getApplicationSupportDirectory();
      environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: '${supportDirectory.path}\\webview2',
        ),
      );
    } catch (error) {
      initializationError =
          '无法初始化 Windows WebView2。请安装或修复 WebView2 Runtime 后重启应用。详情：$error';
    }
  }
}
