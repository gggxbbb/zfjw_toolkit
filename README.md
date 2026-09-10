# 正方教务工具箱

一个面向正方教务平台的 Flutter 移动端工具箱，当前聚焦于成绩采集与统计。应用不会要求用户提供账号或密码；登录操作始终在校方教务页面中完成。

## 功能

- 从正方教务成绩查询页采集成绩数据
- 从已保存的成绩查询页 HTML 文件生成成绩快照
- 计算总 GPA、学位 GPA、学分和成绩分布
- 按学期查看成绩趋势
- 支持目标 GPA 与假设分析
- 内置徐州医科大学成绩计算规则包

## 使用方式

1. 安装并打开应用，在「成绩」页选择「采集成绩」或「导入 HTML」来生成成绩快照。
2. 采集时，在内嵌的校方教务页面正常登录并进入成绩查询页；应用会在查询结果出现后读取成绩。
3. 回到成绩页查看统计结果、趋势和课程警告。

成绩数据保存在设备本地。请仅导入或采集属于自己的成绩信息，并遵守学校教务系统的使用规定。

## 开发

要求：Flutter SDK（Dart `^3.11.3`）和可用的 Android 或 iOS 开发环境。

```bash
flutter pub get
flutter test
flutter run
```

## Android 签名与 CI

发布签名密钥不会以明文提交到仓库。CI 的加密副本保存在本仓库的 GitHub Actions repository secrets；请同时在团队认可的密码库或加密离线存储中保留恢复副本。本地构建时，将 `android/key.properties.example` 复制为 `android/key.properties`，并填入对应的 JKS 路径、别名和密码。

GitHub Actions 在推送到 `main` 后会运行静态检查和测试，并使用下列 repository secrets 构建签名 APK：

- `ANDROID_KEYSTORE_BASE64`：JKS 文件的 Base64 内容
- `ANDROID_KEYSTORE_PASSWORD`：JKS 密码
- `ANDROID_KEY_ALIAS`：密钥别名
- `ANDROID_KEY_PASSWORD`：密钥密码

生成的 APK 会作为 `zfjw-toolkit-release-apk` 构件保存 30 天。

## 项目结构

- `lib/capture/`：教务页面成绩采集与 HTML 导入
- `lib/core/`：领域模型、解析器与成绩计算规则
- `lib/data/`：本地 SQLite/Drift 存储
- `lib/features/`：成绩与设置页面
- `docs/adr/`：架构决策记录

## 许可证

本项目以 [MIT License](LICENSE) 发布。
