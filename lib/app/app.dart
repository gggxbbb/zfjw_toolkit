import 'package:flutter/material.dart';

import 'package:zfjw_toolkit/app/main_shell.dart';
import 'package:zfjw_toolkit/app/theme.dart';

/// 应用根组件：Material 3 亮/暗主题 + 中文本地化 + 主壳。
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
