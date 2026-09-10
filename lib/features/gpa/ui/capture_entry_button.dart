import 'package:flutter/cupertino.dart';

import 'package:zfjw_toolkit/features/gpa/ui/capture_page.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 「去采集」入口按钮：导航到全屏 WebView 采集页。
///
/// 用 [CupertinoPageRoute] 而非 Material 路由——本应用是 iOS 26 玻璃树，
/// Cupertino 路由自带 iOS 式侧滑返回手势与转场。
class CaptureEntryButton extends StatelessWidget {
  const CaptureEntryButton({super.key, this.expand = false});

  /// 是否横向撑满父级。
  final bool expand;

  @override
  Widget build(BuildContext context) => AppGlassButton(
        label: '去采集',
        icon: CupertinoIcons.cloud_download,
        style: AppButtonStyle.prominent,
        expand: expand,
        onTap: () => _push(context),
      );
}

/// 顶部栏图标版采集入口：有数据后的「重新采集/更新」常驻入口。
class CaptureAppBarAction extends StatelessWidget {
  const CaptureAppBarAction({super.key});

  @override
  Widget build(BuildContext context) => AppGlassIconButton(
        icon: CupertinoIcons.cloud_download,
        style: AppButtonStyle.prominent,
        onTap: () => _push(context),
      );
}

void _push(BuildContext context) {
  Navigator.of(context).push(
    CupertinoPageRoute<void>(builder: (_) => const CapturePage()),
  );
}
