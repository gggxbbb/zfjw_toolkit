# 07 — WebView 采集页

**What to build:** 成绩页顶栏「采集」按钮打开全屏 WebView 采集页：加载正方教务，用户自行完成 CAS/验证码登录（cookie 持久化，下次免登）；检测到成绩查询页后自动注入采集脚本（自动全范围查询 → jqGrid JSON 优先 → DOM 回退），数据经 JS 桥回传，解析入库为快照，弹「采集完成」一键返回统计页。

**Blocked by:** 01（app 壳）、03（解析器）、05（Repository）。

**Status:** done（7892cb6，主 agent 实现）

- [x] lib/capture/：WebView 会话管理（初始 URL 配置、cookie 持久化、可复用的注入框架）
- [x] 采集脚本（JS，从油猴脚本移植）：等待 jqGrid → 设 rowNum=10000 → 自动全范围查询 → 提取 JSON/DOM → 回传
- [x] URL 检测命中 cjcx_cxDgXscj.html 后自动注入；回传数据走 addJavaScriptHandler 桥
- [x] 采集进度反馈（加载中/等待登录/采集中/完成/失败）；完成后存快照并提示返回
- [x] 桥回传的原始 JSON 经 03 解析器转换，解析失败给出可读错误（不崩）
- [x] `flutter analyze` 零告警、`flutter test` 通过（注入脚本字符串、URL 检测逻辑可单测）
