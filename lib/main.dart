import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:zfjw_toolkit/app/app.dart';
import 'package:zfjw_toolkit/platform/webview_runtime.dart';
import 'package:zfjw_toolkit/ui/kit/glass_theme_bridge.dart';

void main() async {
  // 玻璃库需要引擎级初始化（预热着色器），必须在 runApp 前完成。
  WidgetsFlutterBinding.ensureInitialized();
  await AppWebViewRuntime.initialize();
  await LiquidGlassWidgets.initialize();

  // wrap() 桥接 Material 主题到玻璃明暗级联；brightnessResolver 让玻璃组件
  // 正确跟随 MaterialApp 的 ThemeMode（明/暗/跟随系统）。
  //
  // theme 只用于「非 Material 树」下的默认玻璃色板；真正的明暗切换由
  // brightnessResolver(Theme.maybeBrightnessOf) 驱动——它在 MaterialApp 的
  // theme/darkTheme 之间解析出当前 Brightness，玻璃层据此取
  // GlassThemeData.light / .dark 变体。
  // ProviderScope 为 Riverpod 根容器（数据库/仓储/统计 provider 链）。
  runApp(
    LiquidGlassWidgets.wrap(
      child: const ProviderScope(child: ZfjwApp()),
      theme: GlassThemeBridge.adaptive,
      adaptiveQuality: true,
      brightnessResolver: Theme.maybeBrightnessOf,
    ),
  );
}
