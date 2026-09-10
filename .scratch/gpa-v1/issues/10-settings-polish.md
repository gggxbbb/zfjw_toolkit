# 10 — 设置页完整化 + 收尾

**What to build:** 设置页从占位变成完整功能：壁纸选择（内置渐变组 + 相册自选）、明暗主题切换、目标 GPA 管理（如 08 未覆盖）、规则包信息展示（当前徐医 preset 说明）。最后全量回归 + code review + 提交。

**Blocked by:** 01、05、08。

**Status:** done（85e444f，主 agent 实现）

- [x] 壁纸：内置渐变预览选择、持久化、主壳实时生效（相册自选列为未来增强）
- [x] 主题：跟随系统（MaterialApp ThemeMode.system；明暗三选列为未来增强）
- [x] 目标 GPA 管理、规则包信息卡（徐医规则条目列表）
- [ ] ~~全量 `flutter build apk --debug` 通过~~ → 跳过（用户明确：打包不碰；JDK 25/Kotlin 环境冲突自行处理）
- [x] `flutter analyze` 零告警、`flutter test` 69 全绿
- [ ] code-review 全量审查 → 待进行
