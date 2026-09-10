# 03 — jqGrid 解析器（纯 Dart）

**What to build:** `core/parser` 能把正方成绩页的数据源转成 CourseRecord 列表：输入 jqGrid 的原始 JSON 数组（WebView 采集路径）或完整 HTML 文档（文件导入路径），输出统一模型。容错与油猴脚本对齐。

**Blocked by:** 02（依赖 CourseRecord 模型与字段清洗）。

**Status:** done

- [x] JSON 路径：jqGrid data 数组 → CourseRecord，字段完整性校验（sfxwkc/bfzcj 缺列时返回失败信号）
- [x] HTML 路径：解析 `#tabGrid tr.jqgrow` 单元格（按 aria-describedby 列名取值，与列顺序无关）→ CourseRecord
- [x] 值清洗：Cf/Zs 不可见字符剥除、空白 trim、数字字段 toNum 语义（null 安全）
- [x] 纯 Dart 无 Flutter 依赖；HTML 解析可引入 html 包（html 0.15.7）
- [x] TDD：fixture 至少含正常 JSON、含污染字符 JSON、离线保存的 HTML 三类样本
- [x] `flutter test` 通过（test/core/ 全绿，51 项）
