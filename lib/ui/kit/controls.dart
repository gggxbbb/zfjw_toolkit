import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;

import 'tokens.dart';

/// 玻璃按钮：iOS 26 按钮形态。
///
/// 全部走玻璃库的 [lg.GlassButton]——它实现了 iOS 26 的 `.glass` /
/// `.prominentGlass` 配置（含液态拉伸与光泽反馈）。本封装把风格枚举
/// 映射到玻璃库的 [lg.GlassButtonStyle]，并统一圆角/颜色令牌。
class AppGlassButton extends StatelessWidget {
  const AppGlassButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.style = AppButtonStyle.regular,
    this.expand = false,
  });

  /// 按钮文案。
  final String label;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 左侧图标。
  final IconData? icon;

  /// 视觉风格。
  final AppButtonStyle style;

  /// 是否横向撑满。
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final enabled = onTap != null;

    final lgStyle = switch (style) {
      AppButtonStyle.prominent => lg.GlassButtonStyle.prominent,
      AppButtonStyle.regular => lg.GlassButtonStyle.filled,
      AppButtonStyle.plain => lg.GlassButtonStyle.transparent,
    };

    // 主按钮的图标/文字用强调色，其余用主文本色。
    final fg = style == AppButtonStyle.prominent
        ? tokens.labelPrimary
        : tokens.accent;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppTokens.space2),
        ],
        Text(
          label,
          style: AppText.subhead.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final button = lg.GlassButton.custom(
      onTap: enabled ? (onTap ?? () {}) : () {},
      shape: const lg.LiquidRoundedSuperellipse(
        borderRadius: AppTokens.radiusControl,
      ),
      style: lgStyle,
      enabled: enabled,
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space5),
        child: content,
      ),
    );

    // 撑满时占满可用宽度（Expanded 在有界宽度下工作；高度仍由内容决定，
    // 因此在 ListView/Column 等纵向无界上下文里也安全）。
    if (!expand) return button;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Expanded(child: button)],
    );
  }
}

/// 按钮风格（映射到玻璃库的 iOS 26 配置）。
enum AppButtonStyle {
  /// 主要操作：`.prominentGlass`（更厚更实的玻璃）。
  prominent,

  /// 常规操作：`.glass`（半透明自适应玻璃）。
  regular,

  /// 纯操作：无背景，仅内容与交互反馈。
  plain,
}

/// 玻璃图标按钮：纯图标、无文字（顶部栏 actions、工具条场景）。
///
/// 尺寸紧凑（默认 36×36），放在 [AppGlassAppBar.actions] 里时长驻可见、
/// 不随大标题折叠淡出（库的行为：只有 title 参与折叠联动）。
class AppGlassIconButton extends StatelessWidget {
  const AppGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 20,
    this.buttonSize = 36,
    this.style = AppButtonStyle.regular,
  });

  /// 图标。
  final IconData icon;

  /// 点击回调；null 时禁用。
  final VoidCallback? onTap;

  /// 图标尺寸。
  final double size;

  /// 按钮占位尺寸（正方形）。
  final double buttonSize;

  /// 视觉风格。
  final AppButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final enabled = onTap != null;
    final lgStyle = switch (style) {
      AppButtonStyle.prominent => lg.GlassButtonStyle.prominent,
      AppButtonStyle.regular => lg.GlassButtonStyle.filled,
      AppButtonStyle.plain => lg.GlassButtonStyle.transparent,
    };

    return lg.GlassButton.custom(
      onTap: enabled ? (onTap ?? () {}) : () {},
      shape: lg.LiquidRoundedSuperellipse(
        borderRadius: buttonSize / 2.6,
      ),
      style: lgStyle,
      enabled: enabled,
      height: buttonSize,
      width: buttonSize,
      child: Icon(icon, size: size, color: tokens.accent),
    );
  }
}

/// 玻璃分段控件（iOS `UISegmentedControl`）。
class AppGlassSegmentedControl extends StatelessWidget {
  const AppGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentSelected,
    this.height = 36,
  });

  /// 分段文案。
  final List<String> segments;

  /// 当前选中索引。
  final int selectedIndex;

  /// 选中回调。
  final ValueChanged<int> onSegmentSelected;

  /// 控件高度。
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return lg.GlassSegmentedControl(
      segments: [
        for (final s in segments) lg.GlassSegment(label: s),
      ],
      selectedIndex: selectedIndex,
      onSegmentSelected: onSegmentSelected,
      height: height,
      selectedTextStyle: AppText.footnote.copyWith(
        color: tokens.labelPrimary,
        fontWeight: FontWeight.w600,
      ),
      unselectedTextStyle: AppText.footnote.copyWith(
        color: tokens.labelSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// 玻璃滑杆（iOS `UISlider`）。
class AppGlassSlider extends StatelessWidget {
  const AppGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.label,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return lg.GlassSlider(
      value: value,
      onChanged: onChanged ?? (_) {},
      min: min,
      max: max,
      divisions: divisions,
      label: label,
      activeColor: tokens.accent,
    );
  }
}

/// 玻璃开关（iOS `UISwitch`）。
class AppGlassSwitch extends StatelessWidget {
  const AppGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return lg.GlassSwitch(
      value: value,
      onChanged: onChanged ?? (_) {},
      activeColor: tokens.accent,
    );
  }
}

/// 玻璃进度指示器（不定量转圈）。
class AppGlassProgress extends StatelessWidget {
  const AppGlassProgress({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return lg.GlassProgressIndicator.circular(
      size: size,
      color: tokens.accent,
    );
  }
}

/// 玻璃输入框（iOS 26 text field）。
///
/// 用玻璃库的 [lg.GlassTextField] 而非 Material 的 `TextField`——页面树基于
/// `CupertinoPageScaffold`（无 Material 祖先），Material 输入框会抛
/// "No Material widget found"。
class AppGlassTextField extends StatelessWidget {
  const AppGlassTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.onSubmitted,
  });

  /// 文本控制器。
  final TextEditingController? controller;

  /// 占位文案。
  final String? placeholder;

  /// 键盘类型。
  final TextInputType? keyboardType;

  /// 回车键动作。
  final TextInputAction? textInputAction;

  /// 是否自动聚焦。
  final bool autofocus;

  /// 提交回调。
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return lg.GlassTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      textStyle: AppText.body.copyWith(color: tokens.labelPrimary),
      placeholderStyle: AppText.body.copyWith(color: tokens.labelTertiary),
      shape: const lg.LiquidRoundedSuperellipse(
        borderRadius: AppTokens.radiusControl,
      ),
    );
  }
}

/// iOS 26 玻璃提示弹窗（单按钮「好」）。
///
/// 用 [lg.GlassDialog] + `showCupertinoDialog`——页面树无 Material 祖先，
/// Material 的 `showDialog`/`AlertDialog` 会抛 "No Material widget found"。
Future<void> showAppAlert(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return lg.GlassDialog.show<void>(
    context: context,
    title: title,
    message: message,
    actions: [
      lg.GlassDialogAction(
        label: '好',
        isPrimary: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

/// 玻璃选择器字段（iOS 26 `GlassPicker`）。
///
/// 显示当前值 + 展开箭头，点击由调用方弹出选择（通常用 [showAppPicker]）。
class AppGlassPicker extends StatelessWidget {
  const AppGlassPicker({
    super.key,
    required this.value,
    required this.onTap,
    this.placeholder = '请选择',
    this.height = 48,
  });

  /// 当前值文案；null 显示占位。
  final String? value;

  /// 点击回调（由调用方弹出选择器）。
  final VoidCallback? onTap;

  /// 占位文案。
  final String placeholder;

  /// 控件高度。
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return lg.GlassPicker(
      value: value,
      placeholder: placeholder,
      onTap: onTap,
      height: height,
      textStyle: AppText.body.copyWith(color: tokens.labelPrimary),
      placeholderStyle: AppText.body.copyWith(color: tokens.labelTertiary),
      shape: const lg.LiquidRoundedSuperellipse(
        borderRadius: AppTokens.radiusControl,
      ),
    );
  }
}

/// 从底部弹出一个 iOS 滚轮选择器（Cupertino，无 Material 依赖）。
///
/// 返回选中项索引；用户取消返回 null。
Future<int?> showAppPicker(
  BuildContext context, {
  required List<String> options,
  required int initialIndex,
  String? title,
}) {
  var index = initialIndex.clamp(0, options.length - 1);
  final tokens = AppTokens.of(context);

  return showCupertinoModalPopup<int>(
    context: context,
    builder: (ctx) => Container(
      height: 300,
      color: tokens.cardBackground,
      child: Column(
        children: [
          // 顶部操作条：取消 / 标题 / 确定。
          SizedBox(
            height: 48,
            child: Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space4,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    '取消',
                    style: AppText.body.copyWith(color: tokens.accent),
                  ),
                ),
                Expanded(
                  child: Text(
                    title ?? '',
                    textAlign: TextAlign.center,
                    style: AppText.title.copyWith(color: tokens.labelPrimary),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space4,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(index),
                  child: Text(
                    '确定',
                    style: AppText.body.copyWith(
                      color: tokens.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoPicker(
              scrollController:
                  FixedExtentScrollController(initialItem: index),
              itemExtent: 40,
              onSelectedItemChanged: (i) => index = i,
              children: [
                for (final o in options)
                  Center(
                    child: Text(
                      o,
                      style: AppText.body.copyWith(color: tokens.labelPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
