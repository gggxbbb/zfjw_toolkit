// 解析层测试用例的 fixture：覆盖正常 JSON、污染字符 JSON、离线 HTML 三类。
//
// 字段名沿用正方标准（见 lib/core/model/course_record.dart）。

/// 正常 jqGrid 原始 JSON 数组（首行含 sfxwkc/bfzcj）。
const List<Map<String, dynamic>> normalJqGridRows = [
  {
    'kch': '100101',
    'kcmc': '系统解剖学',
    'xf': '4.0',
    'jd': '4.5',
    'bfzcj': '92',
    'cj': '92',
    'cjbz': '',
    'sfxwkc': '是',
    'xnm': '2021',
    'xqm': '1',
    'xnmmc': '2021-2022',
    'xqmmc': '1',
  },
  {
    'kch': '100102',
    'kcmc': '组织学与胚胎学',
    'xf': '3.0',
    'jd': '3.0',
    'bfzcj': '78',
    'cj': '78',
    'cjbz': '',
    'sfxwkc': '否',
    'xnm': '2021',
    'xqm': '1',
    'xnmmc': '2021-2022',
    'xqmmc': '1',
  },
  {
    // 缺 kch，仅以 kcmc 构成有效行（对齐油猴 row.kch || row.kcmc）
    'kcmc': '体育(一)',
    'xf': '1.0',
    'jd': '4.0',
    'bfzcj': '88',
    'cj': '88',
    'sfxwkc': '否',
  },
];

/// 含 U+200B（零宽空格）/U+00A0（不换行空格）污染字符的 JSON 数组。
/// 清洗后应得到与 [normalJqGridRows] 一致的值。
const List<Map<String, dynamic>> pollutedJqGridRows = [
  {
    'kch': '​100101', // 前置 U+200B
    'kcmc': '系统解剖学 ', // 后置 U+00A0
    'xf': '4.0',
    'jd': '4.5',
    'bfzcj': '92',
    'cj': '92',
    'sfxwkc': '​是​', // 两侧 U+200B
  },
];

/// 首行缺 sfxwkc/bfzcj 列（仅由 formatter 渲染进 DOM 的情形）。
const List<Map<String, dynamic>> incompleteColumnRows = [
  {
    'kch': '100101',
    'kcmc': '系统解剖学',
    'xf': '4.0',
    'jd': '4.5',
    'cj': '92',
  },
];

/// 离线保存的成绩页 HTML：含 #tabGrid 与 tr.jqgrow，单元格带 aria-describedby。
/// 列顺序刻意打乱且与 JSON 不同，验证按列名而非顺序取值。
const String normalGradeHtml = '''
<!DOCTYPE html>
<html><head><title>学生成绩查询</title></head>
<body>
<table id="tabGrid">
  <tbody>
    <tr class="jqgrow" role="row">
      <td aria-describedby="tabGrid_sfxwkc">是</td>
      <td aria-describedby="tabGrid_kcmc">系统解剖学</td>
      <td aria-describedby="tabGrid_bfzcj">92</td>
      <td aria-describedby="tabGrid_kch">100101</td>
      <td aria-describedby="tabGrid_xf">4.0</td>
      <td aria-describedby="tabGrid_jd">4.5</td>
    </tr>
    <tr class="jqgrow" role="row">
      <td aria-describedby="tabGrid_kch">100102</td>
      <td aria-describedby="tabGrid_kcmc">组织学与胚胎学</td>
      <td aria-describedby="tabGrid_sfxwkc">否</td>
      <td aria-describedby="tabGrid_bfzcj">78</td>
      <td aria-describedby="tabGrid_xf">3.0</td>
    </tr>
  </tbody>
</table>
</body></html>
''';

/// 含污染字符的离线 HTML（kcmc 夹带 U+200B/U+00A0，sfxwkc 夹带 U+200B）。
const String pollutedGradeHtml = '''
<!DOCTYPE html>
<html><body>
<table id="tabGrid">
  <tbody>
    <tr class="jqgrow" role="row">
      <td aria-describedby="tabGrid_kch">100101</td>
      <td aria-describedby="tabGrid_kcmc">系统解剖学 </td>
      <td aria-describedby="tabGrid_sfxwkc">​是​</td>
      <td aria-describedby="tabGrid_bfzcj">92</td>
    </tr>
  </tbody>
</table>
</body></html>
''';

/// 结构不符：文档中无 #tabGrid。
const String noTableHtml = '''
<!DOCTYPE html>
<html><body><div>无成绩表格</div></body></html>
''';

/// 结构合法但无数据：#tabGrid 存在，但无任何 tr.jqgrow 行（jqGrid 显示
/// “无记录”时的常见状态）。
const String emptyTableHtml = '''
<!DOCTYPE html>
<html><body>
<table id="tabGrid">
  <tbody>
    <tr class="ui-widget-content jqgrow ui-row-ltr" role="row"></tr>
  </tbody>
</table>
</body></html>
''';
