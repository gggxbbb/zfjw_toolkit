# 09 — HTML 文件导入兜底

**What to build:** 设置页（或空态）提供「导入 HTML」入口：file_picker 选择保存的正方成绩页 HTML 文件，走 03 解析器 DOM 路径，成功后存为快照并跳转统计页。WebView 不可用时的完整备用数据通道。

**Blocked by:** 03（DOM 解析路径）、06（跳转目标）。

**Status:** done（743d344，主 agent 实现）

- [x] 文件选择（file_picker，限定 .html/.htm）
- [x] 读取 → DOM 解析 → CourseRecord 列表 → 存快照（来源标记 file）
- [x] 解析失败（无 tabGrid/无数据行）给可读错误提示
- [x] 成功后导航到成绩 tab（导入按钮在成绩页/空态内，invalidate 后自动刷新）
- [x] `flutter analyze` 零告警、`flutter test` 通过（导入→解析→入库链路测试——解析链路复用 03 测试；按钮为原生 picker 交互，人工验证）
