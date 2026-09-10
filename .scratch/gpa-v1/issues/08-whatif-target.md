# 08 — What-If 假设分析 + 目标 GPA

**What to build:** 统计页新增 What-If 卡：下拉选课程 + 分数滑杆，拖动实时重算并展示总/学位 GPA 新旧对比；目标 GPA 可在设置页设定，统计页展示与当前 GPA 的差距，趋势线叠加目标虚线。What-If 不落库，基于当前快照内存模拟。

**Blocked by:** 06（成绩页 UI 是宿主）。

**Status:** done（bef1874，主 agent 实现）

- [x] What-If 卡：课程下拉（含学期标注）、0-100 分滑杆、新旧 GPA 对比行
- [x] 假设分数按规则包公式重估绩点（对齐 04 引擎 simulate）
- [x] 目标 GPA：设置页输入持久化（shared_preferences），统计页展示差距（±与已达标）
- [x] 趋势折线叠加目标虚线（对齐油猴 trendSvg 行为）
- [x] `flutter analyze` 零告警、`flutter test` 通过
