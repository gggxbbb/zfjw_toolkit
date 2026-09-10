# GPA v1 规格

状态: 已与用户达成共识 (2026-09-10)
来源: /grilling-with-docs 会话

## 目标

zfjw_toolkit 的第一个功能：将 `C:/Users/gameg/Desktop/Dev/GPA/userscripts/jwpt-gpa.user.js`（徐医教务成绩 GPA 统计油猴脚本）移植为独立的 Flutter 应用功能，采用 Liquid Glass UI。

## 已定决策（详见 docs/adr/0001-0003 与 CONTEXT.md）

1. **平台**：Android 优先，尽量兼容 iOS；桌面端目录已移除。
2. **数据获取**（ADR-0001）：`flutter_inappwebview` 6.x WebView 采集为主路径——用户在 WebView 内自行完成 CAS/验证码登录，cookie 持久化；导航至正方成绩查询页（`cjcx_cxDgXscj.html`）后自动注入采集脚本（自动全范围查询 → jqGrid 原始 JSON 优先 → DOM 解析回退）→ JS 桥回传 → 采集完成提示一键返回统计页。HTML 文件导入为兜底入口。手动编辑作为数据层能力（What-If 依赖）。
3. **UI**（ADR-0002）：`liquid_glass_widgets`（GlassScaffold/GlassAppBar/GlassTabBar/GlassCard），全部收敛到 `lib/ui/glass/` 包装层。背景：内置渐变壁纸组 + 相册自选，默认渐变。中文标签。
4. **持久化**（ADR-0003）：drift (SQLite)。存储按多档案设计（profiles + snapshots 表），UI 单档案。
5. **计算规则**：纯 Dart 规则引擎，接口化（绩点公式、学位课判定、重修去重策略、免修处理），首发内置徐医规则包 preset：绩点取教务官方 jd，缺失回退 (score-50)/10 且 <60 记 0；重修/补考取历次最高分，免修记录优先；学位课 = sfxwkc 为「是」；免修不参与统计、学分单独展示；<10 分标疑似误输入。
6. **状态管理**：Riverpod。**图表**：fl_chart。
7. **导航**：底部 GlassTabBar 两个 tab（成绩 / 设置）。采集是成绩页顶栏动作按钮，全屏 WebView 采集页，不占 tab。未来功能直接加 tab。

## v1 功能范围（油猴全家桶全量移植）

- 总 GPA / 学位 GPA
- 加权平均分 / 算术平均分
- 学分（已获/已修，总 & 学位）
- 课程门数统计
- 学期分组 GPA + 趋势图（fl_chart 折线，含目标线）
- 分数分布（fl_chart 柱状，90-100/80-89/70-79/60-69/<60）
- 挂科警告列表（去重后仍不及格）
- 疑似误输入警告（百分制 <10 分）
- 免修课程列表（不参与统计，单独展示）
- What-If 假设分析（选课 + 分数滑杆，实时重算总/学位 GPA）
- 目标 GPA（设置 + 差距展示）
- 最高分 / 最低分

## 目录结构

Feature-first 布局：每个功能域自成 `features/<name>/` 目录（自带 ui、状态、feature 内数据访问），新增功能零侵入旧目录；`core/` 只放跨功能共享的纯逻辑；`capture/` 是可复用的采集基础设施（未来课表/考试等采集型功能直接复用 WebView 会话与注入框架）。

```
lib/
  app/                # 入口、主题、路由、底部导航壳（GlassTabBar）
  core/               # 平台无关纯 Dart，禁止 import Flutter
    model/            # CourseRecord / Snapshot / Profile / Attempt 等跨功能共享模型
    parser/           # jqGrid JSON 解析 + DOM 解析（文件导入复用）
    rules/            # 规则引擎接口 + 各校 preset
  data/               # drift 数据库、跨功能 Repository（profile/snapshot 仓储）
  capture/            # WebView 采集基础设施：会话管理、cookie、注入框架、进度
  ui/
    glass/            # liquid_glass_widgets 包装层（设计系统组件）
    widgets/          # 跨功能共享的通用组件
  features/
    gpa/              # GPA 功能域（本 spec 范围）
      ui/             # 统计页、学期趋势、What-If、警告
      state/          # Riverpod providers
    settings/         # 设置功能域：主题、壁纸、规则包、目标 GPA
    <future>/         # 未来功能（课表/考试安排等）按同样结构加入，加 tab 即可
```

硬约束：
- `core/` 零 Flutter 依赖，解析与计算全量单测
- feature 之间禁止互相 import 对方内部实现，只能经由 `core/`、`data/`、`ui/` 共享层协作
- 路由集中在 `app/`，但每个 feature 暴露自己的路由清单，新功能注册即接入

## 数据流

WebView/文件 → parser 产出 CourseRecord 列表 → 存为 Snapshot（来源 + 时间戳）→ rules 引擎按规则包计算统计结果 → Riverpod 暴露给 UI。What-If 不落库，基于当前快照内存模拟。

## 明确不做（v1）

- 模拟 HTTP 请求直连正方接口
- 多档案 UI、规则包自定义 UI（引擎接口预留）
- 课表/空教室/评教等未来功能（导航壳已预留扩展位）
