# WebView 采集 + 文件导入兜底的数据获取方案

成绩数据不通过模拟 HTTP 请求获取，而是嵌 `flutter_inappwebview`（6.x）让用户在 WebView 内完成 CAS/验证码登录，登录态由 WebView CookieManager 持久化；进入正方成绩查询页后注入 JS（复用油猴脚本逻辑：优先 jqGrid 原始 JSON，回退 DOM 解析），经 JS 桥回传 Flutter。另保留「保存成绩页 HTML → 文件导入」作为兜底入口。拒绝模拟请求的原因：正方各校 CAS 跳转/验证码差异大且频繁改版，维护成本远超收益；WebView 方案对改版天然免疫（用户手动过登录）。解析层按正方标准字段（kch/kcmc/xf/jd/sfxwkc 等）写成平台无关纯 Dart，文件导入复用同一套解析。

## Considered Options

- 模拟 HTTP 请求直接调接口 — 体验最好但被拒：CAS/验证码脆弱性
- 仅文件导入 — 可靠但每次手动操作，被降级为兜底
- 手动输入 — 保留为数据编辑层（What-If 依赖），非独立入口
