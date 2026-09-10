/// 液态玻璃设计系统统一导入层。
///
/// 业务代码（features/*）只应 import 本文件，不要直接依赖 `liquid_glass_widgets`。
/// 未来若更换玻璃库或官方 Liquid Glass 落地，只需改动本目录内的薄封装即可。
library;

export 'glass_scaffold.dart';
export 'glass_app_bar.dart';
export 'glass_tab_bar.dart';
export 'glass_card.dart';
export 'wallpaper.dart';

// 透传业务代码构造 tab 时所需的类型。
export 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassTab, GlassStatusBarStyle;
