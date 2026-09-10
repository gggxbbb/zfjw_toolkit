import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;

/// 玻璃卡片薄封装，用于后续功能页的内容容器。
///
/// 仅透传常用字段，默认内边距 16。详见 [lg.GlassCard]。
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, this.child, this.padding});

  /// 卡片内容。
  final Widget? child;

  /// 内边距，默认 16。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => lg.GlassCard(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      );
}
