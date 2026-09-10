import 'package:flutter/material.dart';

import 'package:zfjw_toolkit/features/gpa/ui/capture_page.dart';
import 'package:zfjw_toolkit/ui/glass/glass.dart';

/// 「去采集」入口按钮：导航到全屏 WebView 采集页。
class CaptureEntryButton extends StatelessWidget {
  const CaptureEntryButton({super.key});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CapturePage()),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_download_outlined, size: 20),
              SizedBox(width: 8),
              Text('去采集', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}
