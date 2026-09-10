# 01 — 依赖骨架 + 液态玻璃 App 壳

**What to build:** 应用安装全部依赖后能启动，展示底部 GlassTabBar 双 tab（「成绩」「设置」，中文标签），每个 tab 是空页占位；背景为内置渐变壁纸。这是所有 UI 工单的宿主壳。

**Blocked by:** None — can start immediately.

**Status:** done

- [x] pubspec 添加依赖：liquid_glass_widgets、flutter_inappwebview、drift(+dev build_runner)、flutter_riverpod、fl_chart、file_picker、shared_preferences、uuid
- [x] main() 完成 LiquidGlassWidgets.initialize() + wrap()，玻璃组件跟随明暗主题
- [x] lib/app/ 下入口、主题、路由；lib/ui/glass/ 建立包装层骨架（GlassScaffold/GlassAppBar/GlassTabBar/GlassCard 的薄封装）
- [x] lib/features/gpa/ 与 lib/features/settings/ 各含空首页，经 tab 可切换
- [x] 内置至少 3 组渐变壁纸资源（共 4 组），设置页暂用第一组
- [x] `flutter analyze` 零告警（本工单范围内），`flutter test` 通过（本工单 3 个用例）

> 备注：仓库全局 `flutter analyze`/`flutter test` 当前被并行 agent 的
> `lib/core`、`lib/data` 半成品（未生成的 drift 代码、类型错误）阻断；
> 本工单文件经范围化检查零告警、用例全绿。另：本地跑 `flutter test` 需
> 设置 `no_proxy=127.0.0.1,localhost` 以绕过拦截 localhost 的 HTTP 代理。
