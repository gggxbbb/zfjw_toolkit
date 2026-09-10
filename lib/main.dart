import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:zfjw_toolkit/app/app.dart';

void main() async {
  // 玻璃库需要引擎级初始化（预热着色器），必须在 runApp 前完成。
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();

  // wrap() 桥接 Material 主题到玻璃明暗级联；brightnessResolver 让玻璃组件
  // 正确跟随 MaterialApp 的 ThemeMode（明/暗/跟随系统）。
  // ProviderScope 为 Riverpod 根容器（数据库/仓储/统计 provider 链）。
  runApp(
    LiquidGlassWidgets.wrap(
      child: const ProviderScope(child: ZfjwApp()),
      adaptiveQuality: true,
      brightnessResolver: Theme.maybeBrightnessOf,
    ),
  );
}
