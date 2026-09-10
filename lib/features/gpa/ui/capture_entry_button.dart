import 'package:flutter/cupertino.dart';

import 'package:zfjw_toolkit/features/gpa/ui/capture_page.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 「去采集」入口按钮：导航到全屏 WebView 采集页。
///
/// 用 [CupertinoPageRoute] 而非 Material 路由——本应用是 iOS 26 玻璃树，
/// Cupertino 路由自带 iOS 式侧滑返回手势与转场。
class CaptureEntryButton extends StatelessWidget {
  const CaptureEntryButton({
    super.key,
    this.expand = false,
    this.label = '去采集',
  });

  /// 是否横向撑满父级。
  final bool expand;

  /// 按钮文案（目标分析页等处需要区分采集对象时可自定义）。
  final String label;

  @override
  Widget build(BuildContext context) => AppGlassButton(
        label: label,
        icon: CupertinoIcons.cloud_download,
        style: AppButtonStyle.prominent,
        expand: expand,
        onTap: () => _push(context),
      );
}

void _push(BuildContext context) {
  Navigator.of(context).push(
    CupertinoPageRoute<void>(builder: (_) => const CapturePage()),
  );
}
