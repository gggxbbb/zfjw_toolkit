# 04 — 统计引擎（纯 Dart）

**What to build:** `core/rules`（或 core/stats）的计算核心：给定 CourseRecord 列表 + 规则包，产出完整统计结果——总/学位 GPA、加权/算术平均分、学分（已获/已修）、学期分组、分数分布、挂科/疑似误输入警告、免修汇总、最高最低分；以及 What-If 模拟（替换某课分数重算）。这是油猴 computeStats/simulate 的 Dart 移植。

**Blocked by:** 02（依赖规则包接口与模型）。

**Status:** done

- [x] 先经规则包去重得到有效记录集，免修剥离后单独汇总（门数/学分/列表）
- [x] aggregate：GPA=Σ(xf·jd)/Σxf、加权平均、算术平均、已获/已修学分、非百分制计数、最值（带课程名）
- [x] 学期分组（xnmmc+xqmmc 键，xnm*100+xqm 排序）+ 每学期 GPA/学分/门数
- [x] 警告：去重后仍不及格的挂科列表；百分制 <10 分疑似误输入
- [x] What-If：指定课程替换假设分数（规则包公式重估绩点）返回新旧总/学位 GPA
- [x] TDD：worked example 用独立手算值断言（禁止用与实现相同的公式重算期望值）；油猴脚本行为为对齐基准
- [x] `flutter test` 通过
