# zfjw_toolkit

面向正方教务平台的移动端工具箱（Flutter，Android/iOS）。当前唯一功能域是成绩统计；数据经 WebView 从正方教务页面采集。

## Language

### 数据

**成绩记录 (Course Record)**:
一条课程成绩的原始记录，对应正方 jqGrid 的一行，字段名沿用正方标准（kch/kcmc/xf/jd/bfzcj/sfxwkc 等）。
_Avoid_: 行、条目

**成绩快照 (Snapshot)**:
某次采集得到的完整成绩记录集合，携带来源（WebView/文件/手动）与时间戳。档案可持有多个快照。
_Avoid_: 导入、备份

**档案 (Profile)**:
一名学生的成绩数据容器。当前单档案，但存储格式按多档案设计。
_Avoid_: 账号、用户

**修读记录 (Attempt)**:
同一课程的一次修读（初修/重修/补考各算一条 Attempt）。

### 计算规则

**规则包 (Rule Preset)**:
一套学校特定的计算规则集合：绩点公式、学位课判定、重修策略、免修处理。首发内置徐医规则包。
_Avoid_: 配置、模板

**免修 (Exempt)**:
以学分认定方式获得的成绩，非考试结果。不参与任何成绩统计，学分单独展示。

**学位课程 (Degree Course)**:
参与学位 GPA 计算的课程，由正方 sfxwkc 字段标记。

**有效记录 (Effective Record)**:
同一课程多次修读（重修/补考）按规则包去重后保留的那条记录（徐医规则：取历次最高分，免修优先）。
_Avoid_: 最终成绩

### 采集

**采集 (Capture)**:
从正方教务页面提取成绩记录的过程（WebView 注入 JS 解析 jqGrid 原始 JSON，回退 DOM 解析）。
_Avoid_: 抓取、爬取
