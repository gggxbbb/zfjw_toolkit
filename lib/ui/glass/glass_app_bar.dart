import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;

/// 顶部玻璃栏薄封装。
///
/// 仅透传本应用需要的字段；玻璃折射由栏内子组件（如按钮）自身渲染，
/// 栏面本身保持透明。详见 [lg.GlassAppBar]。
class GlassAppBar extends StatelessWidget {
  const GlassAppBar({super.key, this.title, this.leading, this.actions});

  /// 标题，通常为 [Text]。
  final Widget? title;

  /// 标题前的控件，通常为返回按钮。
  final Widget? leading;

  /// 标题后的控件列表。
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => lg.GlassAppBar(
        title: title,
        leading: leading,
        actions: actions,
      );
}
