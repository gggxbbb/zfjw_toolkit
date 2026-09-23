# zfjw_toolkit

## Agent skills

### Issue tracker

Issues 以本地 markdown 形式跟踪，位于 `.scratch/<feature-slug>/`。见 `docs/agents/issue-tracker.md`。

### Triage labels

使用默认五角色标签（needs-triage / needs-info / ready-for-agent / ready-for-human / wontfix）。见 `docs/agents/triage-labels.md`。

### Domain docs

Single-context：根级 `CONTEXT.md` + `docs/adr/`。见 `docs/agents/domain.md`。

## UI implementation rules

- 业务页面自己创建的 `Text`、`RichText`、`SelectableText` 必须显式使用 `AppText` 样式，并用 `AppTokens.of(context)` 设置语义色。不要依赖 `DefaultTextStyle` 或 Flutter fallback；红字、黄色下划线等 fallback 外观属于阻断问题。
- 颜色、字号、间距和圆角优先复用 `AppTokens`、`AppText` 与 `AppGlass*` 组件。业务代码不得新增与现有设计系统重复的硬编码视觉值。
- UI 必须先建立信息层级，再呈现原始数据。大量重复记录要分组或摘要；新增、取消、调整等状态使用清晰的语义标签与颜色，不能把整段调试文本直接塞进同色卡片。
- 同时验证窄屏和桌面布局。新增或修改页面至少覆盖 390 像素宽、无溢出、固定操作区不遮挡内容；需要展示七列等高密度内容时仍须保证可读和可点击。
- Widget 测试应使用与正式应用一致的主题入口，或显式覆盖所依赖的排版与颜色；不要让 `MaterialApp` 的默认样式掩盖正式运行时的 fallback 问题。
- 可见 UI 改动在提交前必须用实际 Windows 构建检查一次，确认排版、滚动、明暗语义色和主要操作路径；自动化测试不能代替这一步。
