# UI 采用 liquid_glass_widgets 液态玻璃体系

Flutter 官方 Cupertino 尚无 Liquid Glass（追踪于 flutter/flutter#170310，预计 2026 年底），app 整体视觉选用第三方 `liquid_glass_widgets`（基于 `liquid_glass_renderer`）：GlassScaffold/GlassAppBar/GlassTabBar/GlassCard 组件体系，SDF 着色器真实折射 + 色散 + 物理动画，Android/iOS 双端可用并按设备自动降档质量。所有玻璃组件统一收敛到 `lib/ui/glass/` 包装层，业务代码不直接 import 该库——库处于 0.x 阶段，未来官方方案落地或换库时只动这一层。

## Considered Options

- `cupertino_native` — iOS 原生像素级还原，但 iOS-only，不符合双端要求
- 手搓 BackdropFilter — 可控但只有磨砂无折射，不像真的 Liquid Glass

## Consequences

- 要求 Flutter ≥ 3.41、Impeller 渲染最佳
- 玻璃必须有背景层（壁纸）才有效果：内置渐变壁纸组 + 相册自选，默认渐变
