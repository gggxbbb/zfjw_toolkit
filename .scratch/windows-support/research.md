# Windows 运行可行性研究

日期：2026-09-12

> **实施状态更新（2026-09-12）：** 后续实现已加入 Windows Runner、
> WebView2 Runtime 检测和可写用户数据目录，并成功产出、短时启动
> `build/windows/x64/runner/Release/zfjw_toolkit.exe`。下文保留的是实施前的
> 可行性判断和风险清单；“缺少 Runner”等描述是当时状态，不再代表当前代码。

## 实施前结论

**这个程序技术上可以移植到 Windows，但当前仓库不是一个可直接构建、发布的 Windows 版本。**

需要分三层看：

| 层次 | 当前判定 | 原因 |
| --- | --- | --- |
| 直接执行 `flutter build windows` | **不可** | 实测报错 `No Windows desktop project configured`；仓库没有 `windows/` Runner |
| 经过平台补全后编译并启动主界面 | **大概率可行** | Flutter 支持 Windows，且当前主要依赖都有 Windows 实现 |
| 教务登录、验证码、Cookie 与采集全流程 | **可行性高，但未验证** | Windows 使用 WebView2，不是 Android WebView；还缺 WebView2 环境处理和真实教务站实测 |

因此，当前最准确的产品表述是：**“具备 Windows 移植基础”，而不是“已支持 Windows”。**

## 仓库证据

### 1. 缺少 Windows Runner，当前不能直接构建

当前根目录只有 `android/` 和 `ios/` 等已提交的平台工程，没有 Flutter Windows 应用必需的 `windows/CMakeLists.txt` 和 `windows/runner/`。`git ls-tree -r --name-only HEAD -- windows` 为空，`git log --all -- windows` 也没有历史。

本机实际执行 `flutter build windows`（Flutter 3.41.5）以退出码 1 结束，Flutter 的完整诊断是：`No Windows desktop project configured. See https://flutter.dev/to/add-desktop-support to learn about adding Windows support to a project.`

`.metadata` 仍记录了 Windows 平台的初始模板 revision，但这只是 Flutter 迁移元数据，不能代替 Runner 源码：[`.metadata`](../../.metadata#L13-L32)。

Flutter 官方说明 Windows 构建会生成并编译一个 C++ Runner，常规构建命令是 `flutter build windows`：[Building Windows apps with Flutter](https://docs.flutter.dev/platform-integration/windows/building)。本仓库需先用 Flutter 生成缺失的 Windows 平台工程，并审查生成差异，再进行构建。

### 2. Dart/Flutter 业务代码没有明显的 Android 硬编码阻断

对 `lib/` 的平台敏感导入扫描没有找到 `dart:io` 平台分支、Android 专用 platform channel 或直接调用 Android API。启动路径只初始化 Flutter 和界面库：[`lib/main.dart`](../../lib/main.dart#L1-L29)。

仓库自己的文档目前仍把产品定义为 Android/iOS 移动工具，也只列出 Android/iOS 开发环境：[`CONTEXT.md`](../../CONTEXT.md#L1-L3)、[`README.md`](../../README.md#L22-L30)。这说明 Windows 并非当前已承诺、已测试的产品平台。

### 3. 主要依赖链支持 Windows

当前直接依赖见 [`pubspec.yaml`](../../pubspec.yaml#L31-L48)，解析后的 `.flutter-plugins-dependencies` 已包含 Windows 插件：

- `flutter_inappwebview 6.1.5` 已解析到 `flutter_inappwebview_windows 0.6.0`，该实现底层使用 Microsoft WebView2：[`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview)、[`flutter_inappwebview_windows`](https://pub.dev/packages/flutter_inappwebview_windows)。
- `drift_flutter 0.2.8` 标注支持 Windows；当前锁定的 `sqlite3_flutter_libs 0.5.42` 会为 Windows 打包原生 SQLite：[`drift_flutter` versions](https://pub.dev/packages/drift_flutter/versions)、[`sqlite3_flutter_libs 0.5.42`](https://pub.dev/packages/sqlite3_flutter_libs/versions/0.5.42)。当前数据库创建使用 `driftDatabase(..., native: DriftNativeOptions())`：[`gpa_providers.dart`](../../lib/features/gpa/state/gpa_providers.dart#L14-L22)。
- `liquid_glass_widgets 1.4.2` 明确列出 Windows 渲染路径和桌面端降级策略：[`liquid_glass_widgets 1.4.2`](https://pub.dev/packages/liquid_glass_widgets/versions/1.4.2)。
- Flutter 官方 Windows 文档也将 `url_launcher`、`shared_preferences` 列为常见的 Windows 插件：[Building Windows apps with Flutter](https://docs.flutter.dev/platform-integration/windows/building)。`package_info_plus` 的 Windows 实现也已出现在本地解析的 Windows 插件列表中。

没发现一个必然使 Windows 编译失败的业务依赖。

## 核心功能的 Windows 可行性

### 成绩统计、目标分析和本地存储

这些功能主要是平台无关的 Dart 计算与 Drift/SQLite 存储。从代码和依赖支持矩阵看，**这部分在 Windows 上风险低**。

### WebView 登录与采集

当前采集页通过 `InAppWebView` 打开教务站，注册 JavaScript handler，在目标页注入脚本并回传数据：[`web_capture_page.dart`](../../lib/features/capture/web_capture_page.dart#L13-L34)。

技术路线本身可在 Windows 上成立：

- `InAppWebView` 明确支持 Windows：[InAppWebView documentation](https://inappwebview.dev/docs/webview/in-app-webview/)。
- JavaScript handler 明确支持 Windows：[JavaScript communication](https://inappwebview.dev/docs/webview/javascript/communication/)。
- JavaScript 注入也明确支持 Windows：[JavaScript injection](https://inappwebview.dev/docs/webview/javascript/injection/)。

但当前代码还没有做 Windows WebView2 的必要健壮化：

1. 插件官方要求 Windows **构建机**的 PATH 中有 NuGet CLI：[Getting Started / Windows setup](https://inappwebview.dev/docs/intro/)。本机检查中 `Get-Command nuget` 为空，因此即使补了 Runner，当前开发环境也还不满足该插件的 Windows 构建要求。
2. 插件建议在 Windows 初始化前用 `WebViewEnvironment.getAvailableVersion()` 检查 WebView2 Runtime；Windows 10 不一定已安装。当前 [`main.dart`](../../lib/main.dart#L8-L28) 没有这个检查。
3. 插件建议在 Windows 创建带自定义、可写用户数据目录的 `WebViewEnvironment`，并传给 `InAppWebView`。否则默认目录在 exe 旁，安装到只读目录时 WebView2 可能因写入失败而崩溃。当前 [`web_capture_page.dart`](../../lib/features/capture/web_capture_page.dart#L23-L34) 没有传 `webViewEnvironment`。详见 [InAppWebView Windows guidance](https://inappwebview.dev/docs/webview/in-app-webview/)。
4. `thirdPartyCookiesEnabled: true` 是 Android 专用设置，不能被当作 Windows Cookie 行为的保证。因此 CAS 跳转、验证码、Cookie 持久化与校方页面的兼容性必须用 WebView2 实测。插件也明确提醒，各平台使用不同原生 WebView 实现，行为可能不同：[Getting Started](https://inappwebview.dev/docs/intro/)。

所以，**“能编译”不等于“能完成教务采集”**。后者至少需要徐州医科大学真实 CAS/教务站的 Windows WebView2 验收。

## 当前本机开发环境

- `flutter doctor -v` 已验证 Flutter 3.41.5 / Dart 3.11.3，且 Windows desktop feature 已启用。
- `flutter doctor -v` 已验证 Windows 11、Visual Studio Community 2026、C++ Windows 开发工具链及 Windows 10 SDK 10.0.26100.0 可用，并识别到 `windows-x64` 桌面设备。
- 未找到 `nuget.exe`。
- 本机已安装 Microsoft Edge WebView2 Runtime 154.0.4258.x；但发布版本仍应检测 Runtime 并处理缺失情形，不能假定所有目标电脑都已安装。
- `flutter doctor -v` 的 Windows 工具链项目为通过；另外有 FVM 路径提示和 Android license 状态提示，均不构成本次 Windows 构建阻断。

Flutter 官方要求 Windows 开发环境安装 Visual Studio 的 **Desktop development with C++** workload，并用 `flutter doctor -v` 验证：[Set up Windows development](https://docs.flutter.dev/platform-integration/windows/setup)。

## 达到“Windows 功能版”的最小工作

1. 生成并提交 Windows Runner，审查应用名、图标、版本信息和最小系统要求。
2. 安装 NuGet CLI 并放入 PATH，用 `flutter doctor -v` 验证 C++ toolchain。
3. 增加 Windows 专用 WebView2 Runtime 检测、可写的 `WebViewEnvironment` 用户数据目录，并规划 WebView2 Runtime 分发。Microsoft 的官方选项见 [Distribute your app and the WebView2 Runtime](https://learn.microsoft.com/microsoft-edge/webview2/concepts/distribution)。
4. 先验证 `flutter build windows`、启动、SQLite 读写和基本界面；再单独验证 CAS 登录、验证码、重定向、Cookie 保留、成绩页/教学计划页识别、JavaScript 回传与采集后入库。
5. 用普通用户权限在实际安装目录验收，不要只在可写的 `build/` 输出目录运行。

## 验收标准

只有以下全部通过，才建议宣称“支持 Windows”：

- Windows 10 和 Windows 11 上可安装、启动、退出，无管理员权限要求。
- 缺少 WebView2 Runtime 时给出可操作的提示，而不是崩溃。
- 真实教务站的 CAS/验证码/重定向/Cookie 可用。
- 成绩和教学计划都能识别、注入脚本、回传、持久化。
- 重启后数据仍在，设置与外部链接功能正常。
- 常见桌面窗口尺寸、高 DPI、键鼠操作无阻断问题。

## 本次未完成的验证

- 未修改应用代码，未生成 `windows/` Runner。
- 当前构建已确认在“缺少 Windows desktop project”处失败，因此未产出 Windows exe，也未启动桌面端。
- 未使用真实教务账户对 WebView2 进行端到端验收。
- 未验证 Windows 安装包、签名或自动更新。
