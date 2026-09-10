# 02 — 领域模型 + 徐医规则包（纯 Dart）

**What to build:** `core/model` 与 `core/rules` 完成：CourseRecord（正方标准字段）、Attempt/Snapshot/Profile 模型；规则引擎接口 + 徐医规则包 preset。给定一组原始成绩记录，徐医规则包能回答每条记录的绩点、是否学位课、是否免修、多次修读时哪条是有效记录。

**Blocked by:** None — can start immediately.

**Status:** done

- [x] CourseRecord 覆盖正方字段：kch/kcmc/xf/jd/bfzcj/cj/cjbz/sfxwkc/xnm/xqm/xnmmc/xqmmc，含原始字段清洗（Unicode Cf/Zs 剥除）
- [x] RulePreset 接口：绩点计算、学位课判定、免修判定、修读去重策略、通过判定
- [x] 徐医 preset：绩点优先官方 jd，缺失回退 (score-50)/10 且 <60 记 0；重修/补考取历次最高分；免修记录优先于考试记录；学位课 = sfxwkc 含「是」（含编码值 1/true/Y 兜底）；免修 = 成绩或备注含「免修」
- [x] 全部为纯 Dart，core/ 目录禁止 import Flutter
- [x] TDD：每条规则先红后绿；测试用例覆盖油猴脚本注释中的真实坑（不可见字符污染、免修优先、0 分重修等）
- [x] `flutter test` 通过 + `flutter analyze` 零告警
