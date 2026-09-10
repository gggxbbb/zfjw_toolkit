# 05 — drift 持久化 + Repository

**What to build:** `data/` 完成 drift 数据库：profiles 表 + snapshots 表（多档案 schema），SnapshotRepository 提供「保存采集快照、列出快照、取当前档案最新快照、档案 CRUD（内部，UI 暂单档案）」。应用重启后成绩数据仍在。

**Blocked by:** 02（依赖 Snapshot/Profile 模型）。

**Status:** done

- [x] profiles 表（id/名称/创建时间/规则包标识），snapshots 表（id/profile_id/来源/时间戳/记录 JSON）
- [x] drift 代码生成跑通（build_runner），数据库迁移策略就位
- [x] SnapshotRepository：saveSnapshot、listSnapshots、latestSnapshot(profileId)、创建默认档案
- [x] 快照内 CourseRecord JSON 序列化往返无损
- [x] TDD：drift 内存数据库（NativeDatabase.memory）测试，不落盘
- [x] `flutter test` 通过
