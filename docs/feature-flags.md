# 功能开关

功能开关由 `lib/core/feature_flags/feature_flags.dart` 统一定义与持久化。课表默认关闭；关闭仅隐藏入口，不删除课表或历史快照。选择保存在本机，重启后继续生效。

## 接入新功能

1. 在 `FeatureFlag` 中增加稳定的 id、显示名称、说明和默认值。发布后不要重命名 id，以免丢失用户选择。
2. 设置页自动展示注册的开关，无需新增存储或表单代码。
3. 若控制导航入口，在 `AppTab.featureFlag` 指定开关；其他组件用 `ref.watch(featureEnabledProvider(FeatureFlag.xxx))` 读取状态。
4. 用 `ref.read(featureFlagsProvider.notifier).setEnabled(flag, value)` 修改状态，并处理返回 Future 的保存错误。

开关加载完成前，受控入口暂不显示。读取失败时设置页提供重试。写入按调用顺序执行，成功后才更新界面；失败保留原值。此机制是本地功能偏好，不用于权限校验。

导航按稳定 tab id 保存当前选择。隐藏其他入口不会切换当前页；当前页被关闭时回到第一个可用页面。
