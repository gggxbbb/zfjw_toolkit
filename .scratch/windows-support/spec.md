# Windows 支持

Status: ready-for-human

## 目标

让当前 Flutter 项目具备可构建、可启动的 Windows 桌面版本，同时保持
Android/iOS 行为不变。

## 验收要求

- 提交标准 Flutter Windows Runner，并使用项目现有名称、版本和应用图标。
- `flutter build windows` 能生成 Release 可执行文件和完整运行目录。
- Windows 启动时检查 WebView2 Runtime，并为 WebView2 使用用户可写的数据目录。
- WebView2 不可用或初始化失败时，采集页显示可操作的错误信息，不因创建原生
  WebView 而崩溃。
- 现有静态分析和 Flutter 测试全部通过。
- README 记录 Windows 构建及运行前置条件。
- 宽度达到 720 时将底部导航切换为左侧导航栏，超宽窗口显示展开标签。
- 宽屏内容居中并限制最大宽度；成绩、目标分析和设置页的独立卡片可自适应
  单列/双列显示，窄屏继续使用原有单列和底部导航。

## 非目标

- 本次不制作 MSIX/安装器，不实现签名或自动更新。
- 没有真实教务账号时，不宣称 CAS、验证码、Cookie 和采集链路已在 Windows
  端到端验收。

## 验证记录

- `flutter analyze`：通过。
- `flutter test`：113 项全部通过，覆盖 WebView2 错误态、精确导航断点、单双列重排和深色主题语义色。
- `flutter build windows`：通过，产物位于
  `build/windows/x64/runner/Release/zfjw_toolkit.exe`。
- 启动冒烟：Release 进程启动 8 秒后仍正常运行，随后由测试命令主动结束。
