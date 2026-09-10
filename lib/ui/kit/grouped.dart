import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;
import 'package:zfjw_toolkit/ui/kit/surfaces.dart';

import 'tokens.dart';

/// iOS 分组卡片：卡片 + 上方小写灰字 header + 下方灰字 footer。
///
/// 对应系统「设置」「健康」页的分组结构。内部可放任意内容；若要承载
/// 列表行（自动插分隔线），用 [AppGlassGroupedSection]。
class AppGlassGroupedCard extends StatelessWidget {
  const AppGlassGroupedCard({
    super.key,
    required this.child,
    this.title,
    this.footer,
    this.padding = const EdgeInsets.all(AppTokens.space4),
    this.glass = true,
  });

  /// 卡片内容。
  final Widget child;

  /// 卡片上方小写灰色 section header。
  final String? title;

  /// 卡片下方小写灰色脚注。
  final String? footer;

  /// 卡片内边距。
  final EdgeInsetsGeometry padding;

  /// 是否使用玻璃材质。
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTokens.space1,
              bottom: AppTokens.space2,
              top: AppTokens.space2,
            ),
            child: Text(
              title!,
              style: AppText.sectionHeader.copyWith(
                color: tokens.labelSecondary,
              ),
            ),
          ),
        AppGlassCard(glass: glass, padding: padding, child: child),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTokens.space1,
              right: AppTokens.space1,
              top: AppTokens.space2,
            ),
            child: Text(
              footer!,
              style: AppText.footnote.copyWith(color: tokens.labelSecondary),
            ),
          ),
      ],
    );
  }
}

/// iOS 分组列表段：多个 [AppGlassListTile] 组成一段，自动插分隔线。
///
/// 直接映射 iOS 的 grouped table section 语义。
class AppGlassGroupedSection extends StatelessWidget {
  const AppGlassGroupedSection({
    super.key,
    required this.children,
    this.title,
    this.footer,
  });

  /// 段内列表行（通常为 [AppGlassListTile]）。
  final List<Widget> children;

  /// 段上方小写灰色 header。
  final String? title;

  /// 段下方小写灰色 footer。
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return lg.GlassGroupedSection(
      header: title == null
          ? null
          : Text(
              title!,
              style: AppText.sectionHeader.copyWith(
                color: tokens.labelSecondary,
              ),
            ),
      footer: footer == null
          ? null
          : Text(
              footer!,
              style: AppText.footnote.copyWith(color: tokens.labelSecondary),
            ),
      children: children,
    );
  }
}

/// iOS 列表行：左侧标签（可带图标）+ 右侧值/控件。
///
/// 薄封装 GlassListTile，统一文字样式令牌（这也是"黄色下划线"的防线之一：
/// 所有文本样式都显式给出）。
class AppGlassListTile extends StatelessWidget {
  const AppGlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  /// 主标题。
  final String title;

  /// 副标题。
  final String? subtitle;

  /// 左侧控件（图标等）。
  final Widget? leading;

  /// 右侧控件（值文本、箭头、开关等）。
  final Widget? trailing;

  /// 点击回调。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return lg.GlassListTile(
      leading: leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      onTap: onTap,
      titleStyle: AppText.body.copyWith(color: tokens.labelPrimary),
      subtitleStyle: AppText.caption.copyWith(color: tokens.labelSecondary),
    );
  }
}

/// 键值明细行：左标签 + 右数值（等宽数字，右对齐）。
///
/// 统计页的核心信息载体，比列表行更紧凑。
class AppStatRow extends StatelessWidget {
  const AppStatRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  /// 指标名。
  final String label;

  /// 指标值。
  final String value;

  /// 值颜色覆盖（达标绿、挂科红等）。
  final Color? valueColor;

  /// 是否加粗强调。
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.subhead.copyWith(color: tokens.labelSecondary),
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          Text(
            value,
            style: AppText.numeric.copyWith(
              color: valueColor ?? tokens.labelPrimary,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡内小标题。
class AppCardTitle extends StatelessWidget {
  const AppCardTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppText.title.copyWith(
                fontSize: 15,
                color: tokens.labelPrimary,
              ),
            ),
          ),
          if (trailing case final Widget trailing) trailing,
        ],
      ),
    );
  }
}

/// 发丝分隔线。
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => lg.GlassDivider(
        thickness: 0.5,
        indent: indent,
      );
}
