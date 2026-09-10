/// 字段清洗：剥除 Unicode 格式字符类（Cf：零宽空格/连接符、方向标记
/// U+200E/F、软连字符 U+00AD、BOM、Word Joiner 等）与空白分隔符类
/// （Zs：U+00A0、U+3000 等），再 trim。这些字符在成绩字段里绝无意义，
/// 但正方返回的文本常夹带（实测「是」严格相等比较因此失败）。
///
/// 对应油猴脚本 `clean` 函数。
String cleanField(String? value) {
  if (value == null) return '';
  return value
      .replaceAll(RegExp(r'[\p{Cf}\p{Zs}]', unicode: true), '')
      .trim();
}

/// 将字段值清洗后解析为数字；空或无法解析返回 `null`。
///
/// 对应油猴脚本 `toNum` 函数。
double? parseNum(String? value) {
  if (value == null) return null;
  final s = cleanField(value);
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// 一条课程成绩记录，对应正方 jqGrid 的一行。
///
/// 字段名沿用正方标准。文本字段经 [fromRaw]/[fromJson] 构造时已被清洗；
/// 直接 [CourseRecord] 构造则不清洗（供已清洗数据使用）。
class CourseRecord {
  final String? kch; // 课程代码
  final String? kcmc; // 课程名称
  final String? xf; // 学分
  final String? jd; // 绩点（官方）
  final String? bfzcj; // 百分制成绩
  final String? cj; // 成绩（含等级/免修文本）
  final String? cjbz; // 成绩备注
  final String? sfxwkc; // 是否学位课
  final String? xnm; // 学年码
  final String? xqm; // 学期码
  final String? xnmmc; // 学年名称
  final String? xqmmc; // 学期名称

  const CourseRecord({
    this.kch,
    this.kcmc,
    this.xf,
    this.jd,
    this.bfzcj,
    this.cj,
    this.cjbz,
    this.sfxwkc,
    this.xnm,
    this.xqm,
    this.xnmmc,
    this.xqmmc,
  });

  /// 从正方原始字段构造，自动清洗所有文本字段。
  factory CourseRecord.fromRaw({
    String? kch,
    String? kcmc,
    String? xf,
    String? jd,
    String? bfzcj,
    String? cj,
    String? cjbz,
    String? sfxwkc,
    String? xnm,
    String? xqm,
    String? xnmmc,
    String? xqmmc,
  }) =>
      CourseRecord(
        kch: cleanField(kch),
        kcmc: cleanField(kcmc),
        xf: cleanField(xf),
        jd: cleanField(jd),
        bfzcj: cleanField(bfzcj),
        cj: cleanField(cj),
        cjbz: cleanField(cjbz),
        sfxwkc: cleanField(sfxwkc),
        xnm: cleanField(xnm),
        xqm: cleanField(xqm),
        xnmmc: cleanField(xnmmc),
        xqmmc: cleanField(xqmmc),
      );

  /// 从正方原始 JSON 行构造（键名沿用正方标准字段）。
  factory CourseRecord.fromJson(Map<String, dynamic> raw) => CourseRecord.fromRaw(
        kch: raw['kch']?.toString(),
        kcmc: raw['kcmc']?.toString(),
        xf: raw['xf']?.toString(),
        jd: raw['jd']?.toString(),
        bfzcj: raw['bfzcj']?.toString(),
        cj: raw['cj']?.toString(),
        cjbz: raw['cjbz']?.toString(),
        sfxwkc: raw['sfxwkc']?.toString(),
        xnm: raw['xnm']?.toString(),
        xqm: raw['xqm']?.toString(),
        xnmmc: raw['xnmmc']?.toString(),
        xqmmc: raw['xqmmc']?.toString(),
      );

  /// 学分（解析后）。
  double? get credit => parseNum(xf);

  /// 教务官方绩点（解析后）。
  double? get officialGradePoint => parseNum(jd);

  /// 有效分数：百分制成绩优先，回退普通成绩字段。
  double? get numericScore {
    final b = parseNum(bfzcj);
    if (b != null) return b;
    return parseNum(cj);
  }

  /// 去重键：课程代码优先，缺失回退课程名称。
  String get courseKey =>
      (kch != null && kch!.isNotEmpty) ? kch! : (kcmc ?? '');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseRecord &&
          kch == other.kch &&
          kcmc == other.kcmc &&
          xf == other.xf &&
          jd == other.jd &&
          bfzcj == other.bfzcj &&
          cj == other.cj &&
          cjbz == other.cjbz &&
          sfxwkc == other.sfxwkc &&
          xnm == other.xnm &&
          xqm == other.xqm &&
          xnmmc == other.xnmmc &&
          xqmmc == other.xqmmc;

  @override
  int get hashCode => Object.hash(
        kch,
        kcmc,
        xf,
        jd,
        bfzcj,
        cj,
        cjbz,
        sfxwkc,
        xnm,
        xqm,
        xnmmc,
        xqmmc,
      );

  @override
  String toString() =>
      'CourseRecord(kch: $kch, kcmc: $kcmc, xf: $xf, jd: $jd, '
      'bfzcj: $bfzcj, cj: $cj, cjbz: $cjbz, sfxwkc: $sfxwkc)';
}
