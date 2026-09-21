# 更新日志

## 1.2.0 - 2026-09-21

### 新增

- 新增 Windows x64 桌面版支持，包含标准 Windows Runner 与 WebView2
  运行时检测。WebView2 无法初始化时，应用会显示可操作的修复说明并允许返回。
- 新增平板与桌面端自适应布局。720 px 起使用侧边导航，1100 px
  起展开导航标签；宽屏页面会使用多列卡片，但不改变原有功能流程。
- 「设置 → 关于」新增 Git 提交哈希与 UTC 构建时间，便于准确识别
  CI 或本地生成的 release 包。
- 新增统一 release 构建入口，Android 与 Windows 构建都会注入可追溯的
  提交与时间信息；CI 也已切换到同一入口。为避免哈希与实际源码
  不一致，该入口会拒绝从存在未提交更改的工作树打包。

### 改进

- 成绩与教学计划读取完成后会先显示采集概览；可以确认使用本次数据，
  也可以直接重新运行采集脚本，确认前不会覆盖设备上的已有数据。
- 设置页版本号改为读取实际安装包元数据，版本名和构建号不再硬编码。
- GPA 概览、目标分析与玻璃卡片更完整地跟随应用深浅主题。
- 改进 Windows 桌面导航在深色模式下的对比度，并增加系统中文 UI
  字体回退，改善中文文本的显示稳定性。
- 整理响应式间距、内容宽度和导航断点，使手机、平板和桌面端保持
  一致的信息层级。

### 修复

- 修复页面数据尚未完全渲染时提前读取、最终只采集到第一页 15 条记录的
  问题。采集脚本现在会等待 jqGrid 完整加载，并核对记录数与分页状态。
- 修复教学计划数据中「建议修读学年」和「建议修读学期」的真实字段映射，
  同时保留旧字段别名的兼容性。
- 修复桌面端导航未选中项目在部分主题下对比度不足的问题。
- 修复部分统计卡片使用平台主题而非应用主题，导致深色模式颜色不一致
  的问题。

### 工程与后续规划

- 完成「数据备份与历史快照」规格和六个可执行任务的拆分，覆盖历史快照、
  JSON 备份、合并/替换恢复与 CSV 导出。这些是后续开发规划，未在 1.2.0
  中作为用户功能交付。
- 新增针对宽屏导航、响应式分列、主题语义、WebView2 失败边界、版本号与
  release 构建元数据的回归测试，并增加采集脚本完整加载时序测试。

### 包与环境

- Android 包名保持 `icu.gxb.zfjw_toolkit`，版本号为 `1.2.0`，构建号为
  `6`。
- Windows 版需要 Microsoft Edge WebView2 Runtime。从源码构建 Windows 版还需要
  Visual Studio 的「使用 C++ 的桌面开发」工作负载与 NuGet CLI。
- 本次更新不会上传成绩或教学计划数据；原有本地数据保持在设备上。

### 本版本功能提交列表

- `a8b5b8d` `fix(settings): show installed app version`
- `94f004a` `fix(capture): map teaching plan schedule fields`
- `267ecff` `feat: add Windows desktop support`
- `4a92829` `feat: adapt layout for larger screens`
- `d744ddf` `fix: follow app theme in GPA overview`
- `18ca91c` `fix: restore desktop navigation contrast and CJK font`
- `0ed93e8` `docs: specify data backup and snapshot history`
- `8ec561f` `feat: show release build metadata`
- `f5a06a6` `fix(capture): wait for complete grid data`
- `1f99415` `fix(ci): preserve clean release metadata`
