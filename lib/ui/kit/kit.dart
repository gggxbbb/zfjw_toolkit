/// iOS 26 设计系统统一导入层。
///
/// 业务代码（features/*）只应 import 本文件，不要直接散落引用
/// `liquid_glass_widgets` 或硬编码颜色。
///
/// 分工：
/// - **材质**：由 `liquid_glass_widgets` 提供（玻璃卡、玻璃栏、玻璃控件）。
///   本目录的组件封装它，统一装配本应用的配色与排版。
/// - **配色 / 排版 / 安全区**：[tokens.dart] 是唯一的颜色与字号来源，
///   并经 [glass_theme_bridge.dart] 注入玻璃主题，保证全应用一套配色、
///   无黑紫混杂。
///
/// 视觉目标：**看起来、用起来都像 Apple 第一方 iOS 26 应用**。
library;

export 'tokens.dart';
export 'glass_theme_bridge.dart';
export 'surfaces.dart';
export 'grouped.dart';
export 'controls.dart';

// 透传业务代码构造 tab / 弹窗所需的类型。
export 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassTab,
        GlassStatusBarStyle,
        GlassDialog,
        GlassDialogAction;
