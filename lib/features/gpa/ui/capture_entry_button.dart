import 'package:flutter/material.dart';

import 'package:zfjw_toolkit/features/gpa/ui/capture_page.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 「去采集」入口按钮：导航到全屏 WebView 采集页。
class CaptureEntryButton extends StatelessWidget {
  const CaptureEntryButton({super.key});

  @override
  Widget build(BuildContext context) => AppGlassButton(
        label: '去采集',
        icon: Icons.cloud_download_outlined,
        style: AppButtonStyle.prominent,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CapturePage()),
        ),
      );
}
