import 'package:flutter/material.dart';

import 'package:zfjw_toolkit/app/main_shell.dart';
import 'package:zfjw_toolkit/app/theme.dart';

/// 应用根组件：Material 主题（承载色板与明暗）+ 玻璃主壳。
///
/// 用 [MaterialApp] 而非 `CupertinoApp`：[AppTheme] 把
/// [Brightness] 暴露给玻璃层的 `brightnessResolver`（见 `main.dart`），
/// 同时为树内的 Material 组件提供一致的主题上下文。
class ZfjwApp extends StatelessWidget {
  const ZfjwApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '正方教务工具箱',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const MainShell(),
      );
}
