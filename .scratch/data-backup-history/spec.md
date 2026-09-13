# 数据备份与历史快照

**Status:** ready-for-agent

## Problem Statement

应用已经在本地保存多次成绩快照，但用户只能通过成绩页看到最新快照，并通过
数据管理页编辑当前数据。用户无法查看过去的原始采集结果、主动选择统计所用的
快照，也无法将成绩快照、教学计划和个人设置作为完整备份迁移到另一台设备。

现有 HTML 文件导入只负责从教务页面存档生成一个成绩快照，不是应用数据的完整
备份与恢复机制。用户也缺少适合 Excel 等工具使用的通用成绩导出格式。

## Solution

在设置页增加统一的“数据与备份”入口。进入后，用户可以继续管理与编辑当前
数据、浏览不可变的历史成绩快照、显式选择当前快照、导出或恢复完整应用备份，
以及将当前有效成绩或指定历史快照导出为 CSV。

历史详情默认展示采集时保存的原始成绩记录，不套用后来产生的修改、删除和手动
新增记录。只有被设为当前的快照进入现有统计数据流，并应用当前成绩 overrides。

完整备份使用带格式版本的 JSON 文档，覆盖档案、全部成绩快照、教学计划、成绩
与教学计划 overrides、GPA 目标和规则包。恢复前必须完成全文件校验并展示预览；
恢复操作不能在失败后留下用户可见的半套数据。

CSV 是面向表格分析的有损导出，不作为完整恢复格式。

## User Stories

1. As a student, I want to enter all data-related functions from Settings, so that the grades page remains focused on viewing and capture.
2. As a student, I want the Settings entry to be named “数据与备份”, so that its purpose is immediately clear.
3. As a student, I want to continue opening the existing data editor from the data hub, so that current management capability is not lost.
4. As a student, I want to see every stored grade snapshot in reverse chronological order, so that I can find a past capture quickly.
5. As a student, I want each snapshot row to show capture time, source, course count and GPA summary, so that I can identify it without opening it.
6. As a student, I want the current snapshot to be visibly marked, so that I know which data drives the grades and target-analysis pages.
7. As a student, I want to open a snapshot and inspect its original course records, so that historical evidence is not rewritten by later edits.
8. As a student, I want historical details to ignore current overrides, so that the view represents what was captured at that time.
9. As a student, I want to set a historical snapshot as current only through an explicit action, so that merely browsing history cannot change statistics.
10. As a student, I want to preview the effect of switching the current snapshot, so that I understand that existing overrides will apply to it.
11. As a student, I want the grades and target-analysis pages to refresh after switching snapshots, so that all calculations use the selected data consistently.
12. As a student, I want to delete an unwanted historical snapshot after confirmation, so that I can manage local storage.
13. As a student, I want deletion of the current snapshot to fall back safely to the newest remaining snapshot, so that the app never references missing data.
14. As a student, I want deletion of the final snapshot to produce the normal empty/current-manual-data state, so that the application remains usable.
15. As a student, I want to export one complete backup file, so that I can migrate or archive all app-managed academic data.
16. As a student, I want the backup to preserve stable identifiers and original timestamps, so that history remains auditable after restoration.
17. As a student, I want the backup to include the teaching plan and manual corrections, so that restored calculations match the source device.
18. As a student, I want the backup to include GPA goals and the selected rule preset, so that personal analysis settings are restored too.
19. As a student, I want the export flow to warn that grade data is personal information, so that I can choose a safe destination.
20. As a student, I want backups to exclude passwords, cookies and WebView data, so that exporting academic data does not export authentication state.
21. As a student, I want to choose where the backup is saved using the platform file interface, so that the flow works naturally on mobile and Windows.
22. As a student, I want to select a backup file using the platform file interface, so that importing does not require typing a path.
23. As a student, I want the app to reject malformed or unsupported backup files before writing anything, so that bad input cannot damage local data.
24. As a student, I want an import preview showing profiles, snapshots, teaching-plan presence, corrections and settings, so that I know what will change.
25. As a student, I want to merge a backup with local data, so that distinct snapshots from two devices can coexist.
26. As a student, I want identical snapshot identifiers and content to be skipped during merge, so that repeat imports remain idempotent.
27. As a student, I want conflicting content under the same stable identifier to stop the merge, so that the app never silently rewrites history.
28. As a student, I want replacement restore to require an additional destructive confirmation, so that I cannot erase local data accidentally.
29. As a student, I want failed merge or replacement restores to roll back, so that every visible data store remains internally consistent.
30. As a student, I want an interrupted restore to be detected and recovered on the next launch, so that process termination cannot leave an ambiguous state.
31. As a student, I want to export current effective grades as CSV, so that my manual corrections are reflected in spreadsheet analysis.
32. As a student, I want to export the raw records of a selected historical snapshot as CSV, so that I can audit exactly what was captured.
33. As a student, I want Chinese CSV content to open correctly in common Windows spreadsheet software, so that course names are not garbled.
34. As a student, I want CSV export to state that it cannot restore the complete application, so that I do not mistake it for a backup.
35. As a tablet or desktop user, I want the data hub and history views to use the existing adaptive layout, so that wide screens are used efficiently.
36. As a screen-reader or keyboard user, I want every data action and current-state marker to have meaningful semantics and focus behavior, so that the feature is operable without touch.

## Implementation Decisions

- The Settings page contains one “数据与备份” entry that opens a dedicated data hub. The hub owns navigation to data management, snapshot history, complete backup import/export and CSV export.
- Grade capture continues to append immutable snapshots. Browsing history never changes the current snapshot.
- A profile can persist an optional current snapshot identifier. When absent, the newest snapshot is current for backward compatibility.
- The current statistics data flow resolves the persisted current snapshot first and falls back to the newest remaining snapshot. All consumers use the same resolved snapshot.
- Historical snapshot summaries and details are calculated from raw stored records using the profile rule preset. They do not apply record overrides.
- Record overrides remain the editable current working state. Once a snapshot is explicitly made current, the existing overrides are applied by stable course and semester keys as they are today.
- Deleting a snapshot requires confirmation. Deleting the current snapshot selects the newest remaining snapshot; deleting the last snapshot clears the persisted selection.
- Complete backups use a UTF-8 JSON document with a top-level integer format version, export timestamp, producing app version and payload sections for profiles, snapshots, teaching plan, overrides, goals and rule preset.
- Backup serialization is a dedicated versioned boundary rather than a copy of the SQLite file. Unknown newer versions are rejected with an actionable error; future older-version migrations happen at this boundary.
- Backup export preserves snapshot identifiers, sources and capture timestamps. It excludes credentials, cookies, WebView storage, caches and transient UI state.
- Restore fully parses and validates the document before presenting a preview or changing local state. Validation checks required fields, supported enum values, identifiers, timestamps and record shapes.
- Merge is idempotent: an identical entity with the same stable identifier is skipped. The same identifier with different content is a blocking conflict and is never silently overwritten.
- Replacement restore requires a second destructive confirmation after preview.
- Restore coordinates SQLite and key-value state as one application-level operation. It records enough pre-restore state and progress to compensate failures and recover an interrupted restore on next launch. User-visible success is emitted only after every store is committed.
- Providers for snapshots, effective records, statistics, teaching plans, overrides and goals are invalidated together after a successful switch, deletion or restore.
- File selection and save destinations are abstracted behind an injectable document gateway so platform UI and automated tests do not leak into domain serialization.
- CSV export has two explicit modes: current effective records and one selected snapshot’s raw records. The file is UTF-8 with a BOM and stable Chinese column headers for compatibility with common Windows spreadsheet software.
- Existing responsive breakpoints and content-width rules apply to the data hub and history pages. Narrow screens use a single-column navigation flow; wide screens may use list-detail or card columns without changing behavior.
- Personal-data warnings appear before exporting. The app does not transmit files or add cloud synchronization.

## Testing Decisions

- Prefer a high-level data-hub widget seam backed by an in-memory database, deterministic key-value storage and a fake document gateway. It should verify Settings navigation, history rendering, current selection, deletion confirmation, import previews and export outcomes through user-visible behavior.
- Use one backup-format round-trip seam for codec and restore-coordinator behavior. It should verify exact preservation, version rejection, corrupt input, idempotent merge, identifier conflicts, replacement and rollback/recovery without depending on platform dialogs.
- Extend existing repository tests for current-snapshot resolution, ordering, deletion and fallback behavior. Assertions should describe externally observable repository results rather than Drift query structure.
- Extend existing grades-page tests to prove that selecting a snapshot refreshes statistics and that historical preview remains raw while the current view applies overrides.
- Test complete backup round trips with multiple snapshots, all supported sources, teaching-plan data, record and plan overrides, goals and rule-preset metadata.
- Inject failures at each restore boundary and assert that the pre-import state is recovered and no success signal is emitted.
- Test CSV bytes and parsed cells, including BOM, commas, quotes, line breaks, Chinese course names, null fields and both export modes.
- Test compact and wide layouts using the existing widget-test viewport pattern, including keyboard focus and semantic labels for destructive actions and current markers.
- Continue running the full analyzer and test suite after each vertical slice. File-dialog plugins are covered by their adapter contract; automated tests use the fake gateway.

## Out of Scope

- Cloud synchronization, accounts, remote backup destinations or automatic upload.
- Automatic snapshot retention or background deletion policies.
- Backup encryption, password-protected archives or key management.
- Importing credentials, cookies, WebView storage or authentication state.
- Teaching-plan history or coordinated historical grade/plan snapshots.
- Snapshot annotations, custom names or notes.
- Visual comparison or diffing between two snapshots.
- CSV import or using CSV as a complete restore format.
- Spreadsheet statistics, charts or formatting beyond a stable tabular record export.
- Multiple-profile management UI beyond faithfully preserving profile data in backups.

## Further Notes

- The existing HTML import remains a capture source that creates a new grade snapshot. It must not be relabeled as complete backup restore.
- Grade records and teaching plans are personal academic data. Export copy should recommend storing files only in locations controlled by the user.
- The first implementation frontier contains tickets 01 and 03, which can proceed independently. Import work begins only after the exported format is fixed by ticket 03.
