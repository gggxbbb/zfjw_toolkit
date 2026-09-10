# 06 — 成绩页 UI（统计全家桶）

**What to build:** 「成绩」tab 从空壳变成完整统计页：无数据时展示空态引导（去采集/去导入）；有快照时展示 GPA 大字卡（总/学位）、加权/算术平均、学分、门数、挂科与疑似误输入警告卡、免修区、各学期列表 + 趋势折线（fl_chart）、分数分布柱状图。数据经 Riverpod 从 Repository 流入统计引擎再进 UI。

**Blocked by:** 01（app 壳与玻璃组件层）、04（统计引擎）、05（Repository）。

**Status:** done（145416a，主 agent 实现——subagent 限流不可用期间接手）

- [x] Riverpod provider 链：latestSnapshot → 规则包 → 统计结果 → 页面
- [x] 空态：无快照时引导按钮（采集 / 导入占位）
- [x] 总览卡：GPA 大字、学位 GPA、平均分、学分（已获/已修）、门数、最值、免修行
- [x] 警告区：挂科（红色强调）、疑似误输入（黄色提示）
- [x] 学期区：每学期 GPA/学分/门数列表 + fl_chart 趋势折线
- [x] 分布区：五档柱状图
- [x] 全部玻璃组件经 lib/ui/glass/ 包装层使用；滚动布局在长列表下不溢出
- [x] `flutter analyze` 零告警、`flutter test` 通过；提供至少一条 UI 级测试（空态/有数据分支）
