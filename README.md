# 正方教务工具箱

正方教务工具箱是一款基于 Flutter 的学业管理应用，用于采集成绩、分析目标和查看离线课表。项目包含 Android、iOS 和 Windows 平台工程。

登录在内嵌的校方教务页面中完成。应用将采集的数据保存在设备本地，供后续统计和查阅。

## 功能

- **成绩统计**：查看总 GPA（平均学分绩点）、学位 GPA、学分和成绩分布，按学期查看成绩趋势。
- **目标分析**：采集教学计划，分析目标 GPA，并模拟课程成绩变化。
- **数据管理**：新增、修改或隐藏成绩记录与教学计划课程，重新采集后保留手动修改。
- **离线课表**：按周查看课程安排，保存历史快照，对比新增、取消和调整的课次。
- **自适应布局**：支持手机、平板和桌面布局，适配浅色与深色主题。

应用内置徐州医科大学成绩计算规则包。其他学校的页面结构和计算规则可能不同，使用前请核对适用性。

## 使用说明

Windows 版运行时需要 Microsoft Edge WebView2 Runtime。

### 采集成绩

1. 打开“成绩”页，进入成绩采集页面。
2. 在内嵌的校方教务页面登录，进入成绩查询页。
3. 等待应用读取数据，核对采集概览并确认保存。
4. 返回“成绩”页，查看统计结果、学期趋势和课程警告。

每次确认采集后，应用会保存一份成绩快照，即本次采集的完整成绩记录。

### 分析目标

1. 完成成绩采集，打开“目标分析”页。
2. 选择“采集教学计划”，进入校方的“教学执行计划查看”页面。
3. 选择自己的计划，打开“课程信息”页。
4. 核对采集结果并保存，再进行目标分析和成绩模拟。

### 查看课表

1. 打开“课表”页，选择“采集课表”。
2. 登录后进入个人课表查询页面，选择学期并查询。
3. 等待页面加载完成，点击“采集当前学期”。
4. 首次采集时，按提示设置学期起始日期和周数。
5. 核对课表变化并确认，随后即可离线查看。

重新采集时，应用会对比当前课表。确认变化后，应用保存新的课表快照；课表无变化时，只更新检查时间。已保存的版本可在“历史快照”中查阅。

请仅采集自己的学业信息，并遵守学校教务系统的使用规定。

## 本地开发

### 环境准备

- Flutter SDK，所附 Dart SDK 须满足 `^3.11.3`。
- Git，以及目标平台所需的开发环境。
- 运行采集脚本测试时，还需安装 Node.js。

构建 Windows 版还需准备以下工具：

- Visual Studio，并安装“使用 C++ 的桌面开发”工作负载。
- NuGet CLI，并将其加入 `PATH`。

### 运行与检查

在仓库根目录安装依赖并启动应用：

```bash
flutter pub get
flutter run
```

提交代码前，运行静态检查和测试：

```bash
flutter analyze
flutter test
node --test test/capture/capture_script_timing_test.mjs
```

## 构建与发布

### 构建发布包

发布包统一通过 [构建脚本](tool/build_release.dart) 生成。构建前须保持 Git 工作区干净，处理所有未提交的更改。

构建 Android APK（应用安装包）：

```bash
dart tool/build_release.dart apk
```

构建 Windows 版：

```bash
dart tool/build_release.dart windows
```

在目标名称后追加 Flutter 构建参数。例如，按处理器架构分别生成 APK：

```bash
dart tool/build_release.dart apk --split-per-abi
```

脚本会注入 Git 提交哈希与 UTC（协调世界时）构建时间。两项信息显示在“设置 → 关于”中，用于追溯构建来源。直接运行 `flutter build` 时，这两项信息不会自动注入。

### 配置 Android 签名

1. 将 [签名配置示例](android/key.properties.example) 复制为 `android/key.properties`。
2. 填写 JKS 密钥库路径、密钥别名和密码。
3. 配置完成后，运行 Android 发布构建命令。

签名配置和 JKS 文件包含敏感信息，请保存在仓库之外或已忽略的路径中。另在团队认可的密码库或加密离线存储中保留恢复副本。

### 持续集成

[GitHub Actions 工作流](.github/workflows/ci.yml) 会在推送到 `main`、创建拉取请求或手动触发时运行检查。检查包括采集脚本测试、静态分析和 Flutter 测试。

推送到 `main` 且检查通过后，工作流会构建签名 APK。构建需要在仓库的 Actions Secrets 中配置以下值：

| 名称 | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | JKS 文件的 Base64 编码内容 |
| `ANDROID_KEYSTORE_PASSWORD` | JKS 密钥库密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

Base64 编码本身不提供加密保护。签名材料通过 Actions Secrets 保存和注入。

工作流将 APK 保存为 `zfjw-toolkit-release-apk` 构件，保留 30 天。

## 项目结构

| 路径 | 用途 |
| --- | --- |
| `lib/app/` | 应用入口布局与导航 |
| `lib/capture/` | 教务页面采集脚本与采集流程 |
| `lib/core/` | 领域模型、解析器与成绩计算规则 |
| `lib/data/` | 本地 SQLite 数据库与数据仓库 |
| `lib/features/` | 成绩、目标分析、课表、数据管理与设置 |
| `lib/ui/` | 主题、排版与通用界面组件 |
| `test/` | 自动化测试 |
| `tool/` | 构建工具 |
| `docs/adr/` | 架构决策记录 |

领域术语见 [CONTEXT.md](CONTEXT.md)，版本变更见 [更新日志](CHANGELOG.md)。

## 许可证

本项目采用 [MIT 许可证](LICENSE)。
