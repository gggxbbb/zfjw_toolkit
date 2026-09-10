# 持久化采用 drift（SQLite）

成绩快照、档案、规则包配置、目标 GPA 等持久化选用 drift 而非 shared_preferences + JSON。快照天然是表结构（多次采集、带来源与时间戳），存储格式按多档案设计（档案表 + 快照表），当前 UI 只暴露单档案；未来课表、考试安排等新功能域直接加表，无需迁移存储方案。代价：引入 build_runner 代码生成。

## Considered Options

- shared_preferences 存 JSON — 起步快，但快照列表与多档案结构会迅速失控
- 每档案一个 JSON 文件 + 版本号 — 轻量，但查询、并发写入和未来功能扩展都要自己造
