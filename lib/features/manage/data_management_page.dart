import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/overrides.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';
import 'package:zfjw_toolkit/core/rules/presets/xzhmu.dart';
import 'package:zfjw_toolkit/core/stats/stats_engine.dart'
    show semesterKeyOf, semesterSortValOf;
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/features/target/state/plan_providers.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 数据管理页：查看并编辑成绩记录与教学计划。
///
/// 所有修改/新增/删除都以 override 形式独立存储（见 [OverrideRepository]），
/// 重新采集不会丢失编辑；补丁按课程键 + 学期定位，重新采集后自动再次应用。
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key, this.initialIndex = 0});

  /// 初始分段：0 = 成绩记录，1 = 教学计划。
  final int initialIndex;

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  late var _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: Text(
          '数据管理',
          style: AppText.title.copyWith(color: tokens.labelPrimary),
        ),
        leading: AppGlassIconButton(
          icon: CupertinoIcons.back,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              AppTokens.space3,
              AppTokens.pagePadding,
              AppTokens.space2,
            ),
            child: AppGlassSegmentedControl(
              segments: const ['成绩记录', '教学计划'],
              selectedIndex: _index,
              onSegmentSelected: (i) => setState(() => _index = i),
            ),
          ),
          Expanded(
            child: _index == 0
                ? const _RecordsSection()
                : const _PlanSection(),
          ),
        ],
      ),
    );
  }
}

/// 确认弹窗（ destructive 操作用）；返回用户是否点了确认。
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  var result = false;
  await GlassDialog.show<void>(
    context: context,
    title: title,
    message: message,
    actions: [
      GlassDialogAction(
        label: '取消',
        onPressed: () => Navigator.of(context).pop(),
      ),
      GlassDialogAction(
        label: confirmLabel,
        isPrimary: true,
        onPressed: () {
          result = true;
          Navigator.of(context).pop();
        },
      ),
    ],
  );
  return result;
}

/// 学期选项（新增成绩记录时选择所属学期）。
typedef SemesterOption = ({
  String xnm,
  String xqm,
  String xnmmc,
  String xqmmc,
  String label,
});

// ---------------------------------------------------------------------------
// 成绩记录
// ---------------------------------------------------------------------------

class _RecordRow {
  const _RecordRow({
    required this.record,
    required this.original,
    required this.isAddition,
    this.patch,
  });

  /// 应用补丁后的有效记录（展示用）。
  final CourseRecord record;

  /// 快照中的原始记录；手动新增时与 [record] 相同。
  final CourseRecord original;

  final bool isAddition;

  /// 命中该记录的补丁（不含删除补丁——被删除的记录不出现在列表里）。
  final RecordPatch? patch;
}

class _RecordsSection extends ConsumerWidget {
  const _RecordsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final preset = ref.watch(rulePresetProvider);
    final raw = ref.watch(latestSnapshotProvider).value?.records;
    final overrides =
        ref.watch(recordOverridesProvider).value ?? const RecordOverrides();
    if (raw == null &&
        ref.watch(latestSnapshotProvider).isLoading) {
      return const Center(child: AppGlassProgress());
    }
    final rawRecords = raw ?? const <CourseRecord>[];

    // 行集：补丁覆盖后的采集记录（跳过已删除）+ 手动新增记录。
    // 注意：不用集合内嵌套 if-case——else 会绑定到内层 if 导致逻辑错误。
    final rows = <_RecordRow>[];
    for (final r in rawRecords) {
      final patch = _patchFor(overrides, r);
      if (patch == null) {
        rows.add(_RecordRow(record: r, original: r, isAddition: false));
      } else if (!patch.deleted) {
        rows.add(_RecordRow(
            record: patch.applyTo(r),
            original: r,
            isAddition: false,
            patch: patch));
      }
    }
    for (final a in overrides.additions) {
      rows.add(_RecordRow(record: a, original: a, isAddition: true));
    }

    // 学期选项供新增记录选择（最近在前）。
    final semesters = <SemesterOption>[];
    final seen = <String>{};
    for (final row in rows) {
      final r = row.record;
      final key = '${r.xnm}|${r.xqm}';
      if (seen.add(key)) {
        semesters.add((
          xnm: r.xnm ?? '',
          xqm: r.xqm ?? '',
          xnmmc: r.xnmmc ?? '',
          xqmmc: r.xqmmc ?? '',
          label: semesterKeyOf(r),
        ));
      }
    }
    semesters.sort((a, b) => _semSortVal(b).compareTo(_semSortVal(a)));

    // 按学期分组（最近学期在前）。
    final groups = <String, (int, List<_RecordRow>)>{};
    for (final row in rows) {
      final key = semesterKeyOf(row.record);
      final entry = groups.putIfAbsent(
          key, () => (semesterSortValOf(row.record), <_RecordRow>[]));
      entry.$2.add(row);
    }
    final groupList = groups.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));

    final deleted = [for (final p in overrides.patches) if (p.deleted) p];

    return ListView(
      padding: EdgeInsets.only(
        left: AppTokens.pagePadding,
        right: AppTokens.pagePadding,
        top: AppTokens.space2,
        bottom: MediaQuery.paddingOf(context).bottom + AppTokens.space5,
      ),
      children: [
        AppGlassButton(
          label: '新增成绩记录',
          icon: CupertinoIcons.add,
          style: AppButtonStyle.regular,
          expand: true,
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => RecordEditPage.addition(semesters: semesters),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space3),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space5),
            child: Text(
              '暂无成绩记录。可先采集成绩，或手动新增。',
              style: AppText.subhead.copyWith(color: tokens.labelSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        for (final g in groupList) ...[
          AppGlassGroupedSection(
            title: '${g.key}（${g.value.$2.length} 门）',
            children: [
              for (final row in g.value.$2)
                AppGlassListTile(
                  title: row.record.kcmc?.isNotEmpty == true
                      ? row.record.kcmc!
                      : row.record.courseKey,
                  subtitle: _recordSubtitle(row, preset),
                  trailing: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: tokens.labelTertiary,
                  ),
                  onTap: () => _openEdit(context, row, semesters),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
        ],
        if (deleted.isNotEmpty) ...[
          AppGlassGroupedSection(
            title: '已删除的记录（${deleted.length}）',
            children: [
              for (final p in deleted)
                AppGlassListTile(
                  title: _deletedLabel(p, rawRecords),
                  subtitle: '已隐藏，不参与统计',
                  trailing: GestureDetector(
                    onTap: () => ref
                        .read(recordOverridesProvider.notifier)
                        .removePatch(p.courseKey, p.xnm, p.xqm),
                    child: Text(
                      '恢复',
                      style: AppText.subhead.copyWith(color: tokens.accent),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
        ],
        Text(
          '修改与删除以覆盖（override）方式保存，重新采集成绩后仍会保留你的编辑；'
          '点「恢复」可回到采集值。',
          style: AppText.caption.copyWith(color: tokens.labelTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static int _semSortVal(SemesterOption s) =>
      ((int.tryParse(s.xnm) ?? 0) * 100 + (int.tryParse(s.xqm) ?? 0));

  static RecordPatch? _patchFor(RecordOverrides overrides, CourseRecord r) {
    for (final p in overrides.patches) {
      if (p.matches(r)) return p;
    }
    return null;
  }

  static String _recordSubtitle(_RecordRow row, XzhmuRulePreset preset) {
    final r = row.record;
    final score =
        r.bfzcj?.isNotEmpty == true ? r.bfzcj! : (r.cj?.isNotEmpty == true ? r.cj! : '—');
    final jd = preset.gradePoint(r);
    final badge = row.isAddition ? '新增 · ' : (row.patch != null ? '已修改 · ' : '');
    return '$badge学分 ${r.xf?.isNotEmpty == true ? r.xf! : '—'} · '
        '成绩 $score · 绩点 ${jd?.toStringAsFixed(1) ?? '—'}'
        '${preset.isDegreeCourse(r) ? ' · 学位课' : ''}';
  }

  static String _deletedLabel(RecordPatch p, List<CourseRecord> raw) {
    for (final r in raw) {
      if (p.matches(r)) {
        return '${r.kcmc ?? p.courseKey}（${semesterKeyOf(r)}）';
      }
    }
    return p.courseKey;
  }

  static void _openEdit(
    BuildContext context,
    _RecordRow row,
    List<SemesterOption> semesters,
  ) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => row.isAddition
            ? RecordEditPage.addition(
                semesters: semesters, addition: row.record)
            : RecordEditPage.fetched(original: row.original, patch: row.patch),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 成绩记录编辑页
// ---------------------------------------------------------------------------

class RecordEditPage extends ConsumerStatefulWidget {
  /// 编辑采集记录：[original] 为快照原始记录，[patch] 为已存在的补丁。
  const RecordEditPage.fetched({
    super.key,
    required CourseRecord original,
    RecordPatch? patch,
  })  : _original = original,
        _patch = patch,
        _addition = null,
        semesters = const [];

  /// 新增（[addition] 为 null）或编辑手动记录。
  const RecordEditPage.addition({
    super.key,
    required this.semesters,
    CourseRecord? addition,
  })  : _addition = addition,
        _original = null,
        _patch = null;

  final CourseRecord? _original;
  final RecordPatch? _patch;
  final CourseRecord? _addition;

  /// 可选学期（来自现有记录，最近在前）。
  final List<SemesterOption> semesters;

  bool get _isAddition => _original == null;

  @override
  ConsumerState<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends ConsumerState<RecordEditPage> {
  late final TextEditingController _kcmc;
  late final TextEditingController _kch;
  late final TextEditingController _cj;
  late final TextEditingController _bfzcj;
  late final TextEditingController _xf;
  late final TextEditingController _jd;
  late final TextEditingController _yearName;
  late final TextEditingController _termName;
  late bool _degree;
  late bool _initialDegree;

  /// 学期选择：>=0 为 [RecordEditPage.semesters] 索引，-1 表示新学期。
  late int _semesterIndex;

  /// 绩点是否被用户手动改过（未改则随成绩联动）。
  bool _jdTouched = false;
  bool _jdAutoFilling = false;

  @override
  void initState() {
    super.initState();
    final base = switch ((widget._original, widget._addition)) {
      (final o?, _) => widget._patch?.applyTo(o) ?? o,
      (_, final a?) => a,
      _ => const CourseRecord(),
    };
    _kcmc = TextEditingController(text: base.kcmc ?? '');
    _kch = TextEditingController(text: base.kch ?? '');
    _cj = TextEditingController(text: base.cj ?? '');
    _bfzcj = TextEditingController(text: base.bfzcj ?? '');
    _xf = TextEditingController(text: base.xf ?? '');
    _jd = TextEditingController(text: base.jd ?? '');
    _yearName = TextEditingController(text: base.xnmmc ?? '');
    _termName = TextEditingController(text: base.xqmmc ?? '');
    _degree = ref.read(rulePresetProvider).isDegreeCourse(base);
    _initialDegree = _degree;
    // 已有 jd 覆盖（或手动记录自带 jd）→ 视为已独立指定，不再联动覆盖。
    _jdTouched = widget._patch?.jd != null ||
        (widget._addition != null && (base.jd?.isNotEmpty ?? false));

    _semesterIndex = -1;
    if (widget._isAddition) {
      for (var i = 0; i < widget.semesters.length; i++) {
        final s = widget.semesters[i];
        if (s.xnm == (base.xnm ?? '') && s.xqm == (base.xqm ?? '')) {
          _semesterIndex = i;
          break;
        }
      }
    }

    _cj.addListener(_onScoreChanged);
    _bfzcj.addListener(_onScoreChanged);
    _jd.addListener(() {
      if (!_jdAutoFilling) _jdTouched = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_kcmc, _kch, _cj, _bfzcj, _xf, _jd, _yearName, _termName]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 绩点随成绩联动：成绩变化且用户未手动指定绩点时，按规则包公式重估。
  void _onScoreChanged() {
    if (_jdTouched) return;
    final s = parseNum(_bfzcj.text) ?? parseNum(_cj.text);
    if (s == null) return; // 等级制文本无法联动
    final jd = ref
        .read(rulePresetProvider)
        .gradePoint(CourseRecord(bfzcj: '$s', cj: '$s'));
    _jdAutoFilling = true;
    _jd.text = jd?.toStringAsFixed(1) ?? '';
    _jdAutoFilling = false;
    setState(() {});
  }

  String? _diffField(String input, String? original) {
    final v = input.trim();
    if (v.isEmpty || v == (original ?? '')) return null;
    return v;
  }

  Future<void> _save() async {
    if (widget._isAddition) {
      await _saveAddition();
    } else {
      await _saveFetched();
    }
  }

  Future<void> _saveFetched() async {
    final original = widget._original!;
    final patch = RecordPatch(
      courseKey: original.courseKey,
      xnm: original.xnm ?? '',
      xqm: original.xqm ?? '',
      cj: _diffField(_cj.text, original.cj),
      bfzcj: _diffField(_bfzcj.text, original.bfzcj),
      xf: _diffField(_xf.text, original.xf),
      jd: _diffField(_jd.text, original.jd),
      sfxwkc: _degree == _initialDegree ? null : (_degree ? '是' : '否'),
    );
    final notifier = ref.read(recordOverridesProvider.notifier);
    if (patch.isEmpty) {
      await notifier.removePatch(patch.courseKey, patch.xnm, patch.xqm);
    } else {
      await notifier.upsertPatch(patch);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveAddition() async {
    final kcmc = _kcmc.text.trim();
    if (kcmc.isEmpty) {
      await showAppAlert(context, title: '无法保存', message: '请填写课程名称。');
      return;
    }
    for (final (label, controller) in [
      ('学分', _xf),
      ('百分制成绩', _bfzcj),
      ('绩点', _jd),
    ]) {
      final v = controller.text.trim();
      if (v.isNotEmpty && double.tryParse(v) == null) {
        await showAppAlert(context, title: '无法保存', message: '$label格式不正确。');
        return;
      }
    }
    if (_cj.text.trim().isEmpty && _bfzcj.text.trim().isEmpty) {
      await showAppAlert(context, title: '无法保存', message: '请填写成绩或百分制成绩。');
      return;
    }
    final sem = _semesterIndex >= 0
        ? widget.semesters[_semesterIndex]
        : (
            xnm: _yearCodeOf(_yearName.text),
            xqm: _termCodeOf(_termName.text),
            xnmmc: _yearName.text.trim(),
            xqmmc: _termName.text.trim(),
            label: '',
          );
    final record = CourseRecord.fromRaw(
      kch: _kch.text,
      kcmc: kcmc,
      xf: _xf.text,
      jd: _jd.text,
      bfzcj: _bfzcj.text,
      cj: _cj.text,
      sfxwkc: _degree ? '是' : '否',
      xnm: sem.xnm,
      xqm: sem.xqm,
      xnmmc: sem.xnmmc,
      xqmmc: sem.xqmmc,
    );
    final notifier = ref.read(recordOverridesProvider.notifier);
    final old = widget._addition;
    if (old != null) {
      await notifier.removeAddition(old.courseKey, old.xnm ?? '', old.xqm ?? '');
    }
    await notifier.upsertAddition(record);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final notifier = ref.read(recordOverridesProvider.notifier);
    if (widget._isAddition) {
      final ok = await _confirm(
        context,
        title: '删除这条手动记录？',
        message: '该记录由你手动添加，删除后不可恢复。',
        confirmLabel: '删除',
      );
      if (!ok) return;
      final a = widget._addition!;
      await notifier.removeAddition(a.courseKey, a.xnm ?? '', a.xqm ?? '');
    } else {
      final ok = await _confirm(
        context,
        title: '删除这条成绩记录？',
        message: '将以覆盖方式隐藏该记录，重新采集后仍保持删除；可在数据管理页底部恢复。',
        confirmLabel: '删除',
      );
      if (!ok) return;
      final o = widget._original!;
      await notifier.upsertPatch(RecordPatch(
        courseKey: o.courseKey,
        xnm: o.xnm ?? '',
        xqm: o.xqm ?? '',
        deleted: true,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final ok = await _confirm(
      context,
      title: '恢复原始值？',
      message: '将撤销你对该记录的全部修改，回到最近一次采集的值。',
      confirmLabel: '恢复',
    );
    if (!ok) return;
    final o = widget._original!;
    await ref
        .read(recordOverridesProvider.notifier)
        .removePatch(o.courseKey, o.xnm ?? '', o.xqm ?? '');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final isAddition = widget._isAddition;
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: Text(
          isAddition
              ? (widget._addition == null ? '新增成绩记录' : '编辑成绩记录')
              : '编辑成绩记录',
          style: AppText.title.copyWith(color: tokens.labelPrimary),
        ),
        leading: AppGlassIconButton(
          icon: CupertinoIcons.back,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: AppTokens.pagePadding,
          right: AppTokens.pagePadding,
          top: AppTokens.space3,
          bottom: MediaQuery.paddingOf(context).bottom + AppTokens.space5,
        ),
        children: [
          if (!isAddition) ...[
            AppGlassGroupedCard(
              title: '课程',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget._original!.kcmc ?? widget._original!.courseKey,
                    style: AppText.title.copyWith(color: tokens.labelPrimary),
                  ),
                  const SizedBox(height: AppTokens.space1),
                  Text(
                    '${semesterKeyOf(widget._original!)}'
                    '${widget._original!.kch?.isNotEmpty == true ? ' · 课程代码 ${widget._original!.kch}' : ''}',
                    style:
                        AppText.caption.copyWith(color: tokens.labelSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space3),
          ],
          AppGlassGroupedCard(
            title: isAddition ? '课程信息' : '成绩信息',
            footer: isAddition
                ? null
                : '留空的字段跟随最近一次采集值；重新采集不会覆盖你的修改。',
            child: Column(
              children: [
                if (isAddition) ...[
                  _field('课程名称', _kcmc, placeholder: '必填'),
                  _field('课程代码', _kch, placeholder: '选填'),
                  _semesterPicker(context),
                  _field('学年名称', _yearName,
                      placeholder: '如 2024-2025', visible: _semesterIndex < 0),
                  _field('学期名称', _termName,
                      placeholder: '如 1 / 2 / 3', visible: _semesterIndex < 0),
                  const AppDivider(),
                ],
                _field('成绩', _cj, placeholder: '如 85 / 优秀 / 合格'),
                _field(
                  '百分制成绩',
                  _bfzcj,
                  placeholder: '如 85',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  '学分',
                  _xf,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  '绩点',
                  _jd,
                  placeholder: '随成绩联动',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTokens.space1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _jdTouched ? '绩点已手动指定' : '绩点随成绩联动（可修改）',
                          style: AppText.caption
                              .copyWith(color: tokens.labelTertiary),
                        ),
                      ),
                      if (_jdTouched)
                        GestureDetector(
                          onTap: () => setState(() {
                            _jdTouched = false;
                            _onScoreChanged();
                          }),
                          child: Text(
                            '恢复联动',
                            style: AppText.caption
                                .copyWith(color: tokens.accent),
                          ),
                        ),
                    ],
                  ),
                ),
                const AppDivider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTokens.space2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '学位课',
                          style: AppText.body
                              .copyWith(color: tokens.labelPrimary),
                        ),
                      ),
                      AppGlassSwitch(
                        value: _degree,
                        onChanged: (v) => setState(() => _degree = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          AppGlassButton(
            label: '保存',
            style: AppButtonStyle.prominent,
            expand: true,
            onTap: _save,
          ),
          if (widget._patch != null && !widget._patch!.deleted) ...[
            const SizedBox(height: AppTokens.space3),
            AppGlassButton(
              label: '恢复原始值',
              style: AppButtonStyle.regular,
              expand: true,
              onTap: _reset,
            ),
          ],
          if (widget._original != null || widget._addition != null) ...[
            const SizedBox(height: AppTokens.space3),
            AppGlassButton(
              label: isAddition ? '删除该记录' : '删除该记录（可恢复）',
              style: AppButtonStyle.plain,
              expand: true,
              onTap: _delete,
            ),
          ],
        ],
      ),
    );
  }

  Widget _semesterPicker(BuildContext context) {
    final options = [
      for (final s in widget.semesters) s.label,
      '新学期…',
    ];
    final value = _semesterIndex >= 0
        ? widget.semesters[_semesterIndex].label
        : (_yearName.text.isEmpty && _termName.text.isEmpty
            ? null
            : '${_yearName.text} 第${_termName.text}学期');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('学期',
              style: AppText.body.copyWith(
                  color: AppTokens.of(context).labelPrimary)),
          const SizedBox(height: AppTokens.space2),
          AppGlassPicker(
            value: value,
            placeholder: '选择学期',
            onTap: () async {
              final picked = await showAppPicker(
                context,
                options: options,
                initialIndex:
                    _semesterIndex >= 0 ? _semesterIndex : options.length - 1,
                title: '学期',
              );
              if (picked == null) return;
              setState(() {
                _semesterIndex =
                    picked < widget.semesters.length ? picked : -1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? placeholder,
    TextInputType? keyboardType,
    bool visible = true,
  }) {
    if (!visible) return const SizedBox.shrink();
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppText.body.copyWith(color: tokens.labelPrimary),
            ),
          ),
          Expanded(
            child: AppGlassTextField(
              controller: controller,
              placeholder: placeholder,
              keyboardType: keyboardType,
            ),
          ),
        ],
      ),
    );
  }
}

String _yearCodeOf(String name) =>
    RegExp(r'\d{4}').firstMatch(name)?.group(0) ?? '';

String _termCodeOf(String name) {
  final t = name.trim();
  const cn = {'一': '1', '二': '2', '三': '3'};
  if (cn.containsKey(t)) return cn[t]!;
  return RegExp(r'\d+').firstMatch(t)?.group(0) ?? '';
}

// ---------------------------------------------------------------------------
// 教学计划
// ---------------------------------------------------------------------------

class _PlanRow {
  const _PlanRow({
    required this.course,
    required this.isAddition,
    this.original,
    this.patch,
  });

  /// 应用补丁后的有效课程（展示用）。
  final PlannedCourse course;

  final bool isAddition;

  /// 采集计划中的原始课程；手动新增时为 null。
  final PlannedCourse? original;

  final PlanCoursePatch? patch;
}

class _PlanSection extends ConsumerWidget {
  const _PlanSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final rawPlan = ref.watch(teachingPlanProvider).value;
    final overrides =
        ref.watch(planOverridesProvider).value ?? const PlanOverrides();
    final effective = ref.watch(effectiveTeachingPlanProvider).value;

    // 行集：补丁覆盖后的计划课程（跳过已删除）+ 手动新增课程。
    // 注意：不用集合内嵌套 if-case——else 会绑定到内层 if 导致逻辑错误。
    final rows = <_PlanRow>[];
    for (final c in rawPlan?.courses ?? const <PlannedCourse>[]) {
      final patch = _patchFor(overrides, c);
      if (patch == null) {
        rows.add(_PlanRow(course: c, isAddition: false, original: c));
      } else if (!patch.deleted) {
        rows.add(_PlanRow(
            course: patch.applyTo(c),
            isAddition: false,
            original: c,
            patch: patch));
      }
    }
    for (final a in overrides.additions) {
      rows.add(_PlanRow(course: a, isAddition: true));
    }

    // 按建议学年/学期分组。
    final groups = <String, List<_PlanRow>>{};
    for (final row in rows) {
      final c = row.course;
      final key = c.suggestedYear.isEmpty && c.suggestedTerm.isEmpty
          ? '未安排学期'
          : '${c.suggestedYear} 学年 · 第 ${c.suggestedTerm} 学期';
      groups.putIfAbsent(key, () => []).add(row);
    }
    final groupList = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final deleted = [for (final p in overrides.patches) if (p.deleted) p];

    return ListView(
      padding: EdgeInsets.only(
        left: AppTokens.pagePadding,
        right: AppTokens.pagePadding,
        top: AppTokens.space2,
        bottom: MediaQuery.paddingOf(context).bottom + AppTokens.space5,
      ),
      children: [
        AppGlassButton(
          label: '新增计划课程',
          icon: CupertinoIcons.add,
          style: AppButtonStyle.regular,
          expand: true,
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => const PlanCourseEditPage.addition(),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space3),
        if (effective != null) ...[
          AppGlassGroupedSection(
            title: '计划信息',
            children: [
              AppGlassListTile(
                title: '专业名称',
                subtitle: effective.programName.isEmpty
                    ? '未设置'
                    : effective.programName,
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: tokens.labelTertiary,
                ),
                onTap: () => _openPlanInfoEdit(context, rawPlan),
              ),
              AppGlassListTile(
                title: '毕业学分要求',
                subtitle:
                    '${effective.graduationCredits.toStringAsFixed(1)} 学分'
                    '${overrides.graduationCredits != null ? ' · 已修改' : ''}',
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: tokens.labelTertiary,
                ),
                onTap: () => _openPlanInfoEdit(context, rawPlan),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
        ],
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space5),
            child: Text(
              '暂无教学计划课程。可在目标分析页采集教学计划，或手动新增。',
              style: AppText.subhead.copyWith(color: tokens.labelSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        for (final g in groupList) ...[
          AppGlassGroupedSection(
            title: '${g.key}（${g.value.length} 门）',
            children: [
              for (final row in g.value)
                AppGlassListTile(
                  title: row.course.name.isNotEmpty
                      ? row.course.name
                      : row.course.code,
                  subtitle: _planSubtitle(row),
                  trailing: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: tokens.labelTertiary,
                  ),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => row.isAddition
                          ? PlanCourseEditPage.addition(addition: row.course)
                          : PlanCourseEditPage.fetched(
                              original: row.original!, patch: row.patch),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
        ],
        if (deleted.isNotEmpty) ...[
          AppGlassGroupedSection(
            title: '已删除的课程（${deleted.length}）',
            children: [
              for (final p in deleted)
                AppGlassListTile(
                  title: _deletedLabel(p, rawPlan),
                  subtitle: '已隐藏，不参与目标分析',
                  trailing: GestureDetector(
                    onTap: () => ref
                        .read(planOverridesProvider.notifier)
                        .removePatch(p.key),
                    child: Text(
                      '恢复',
                      style: AppText.subhead.copyWith(color: tokens.accent),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
        ],
        Text(
          '修改与删除以覆盖（override）方式保存，重新采集教学计划后仍会保留你的编辑。',
          style: AppText.caption.copyWith(color: tokens.labelTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static PlanCoursePatch? _patchFor(PlanOverrides overrides, PlannedCourse c) {
    final key = plannedCourseKey(c);
    for (final p in overrides.patches) {
      if (p.key == key) return p;
    }
    return null;
  }

  static bool _isDegree(PlannedCourse c) =>
      c.sfxwkc.contains('是') || degreeYes[cleanField(c.sfxwkc)] == 1;

  static String _planSubtitle(_PlanRow row) {
    final badge = row.isAddition ? '新增 · ' : (row.patch != null ? '已修改 · ' : '');
    return '$badge${row.course.credits.toStringAsFixed(1)} 学分'
        '${_isDegree(row.course) ? ' · 学位课' : ''}';
  }

  static String _deletedLabel(PlanCoursePatch p, TeachingPlan? rawPlan) {
    for (final c in rawPlan?.courses ?? const <PlannedCourse>[]) {
      if (plannedCourseKey(c) == p.key) return c.name;
    }
    return p.key;
  }

  static void _openPlanInfoEdit(BuildContext context, TeachingPlan? rawPlan) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PlanInfoEditPage(rawPlan: rawPlan),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 教学计划课程编辑页
// ---------------------------------------------------------------------------

class PlanCourseEditPage extends ConsumerStatefulWidget {
  /// 编辑采集计划中的课程。
  const PlanCourseEditPage.fetched({
    super.key,
    required PlannedCourse original,
    PlanCoursePatch? patch,
  })  : _original = original,
        _patch = patch,
        _addition = null;

  /// 新增（[addition] 为 null）或编辑手动计划课程。
  const PlanCourseEditPage.addition({super.key, PlannedCourse? addition})
      : _addition = addition,
        _original = null,
        _patch = null;

  final PlannedCourse? _original;
  final PlanCoursePatch? _patch;
  final PlannedCourse? _addition;

  bool get _isAddition => _original == null;

  @override
  ConsumerState<PlanCourseEditPage> createState() => _PlanCourseEditPageState();
}

class _PlanCourseEditPageState extends ConsumerState<PlanCourseEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _credits;
  late final TextEditingController _year;
  late final TextEditingController _term;
  late bool _degree;
  late bool _initialDegree;

  @override
  void initState() {
    super.initState();
    final base = widget._original != null
        ? (widget._patch?.applyTo(widget._original!) ?? widget._original!)
        : (widget._addition ??
            const PlannedCourse(
              code: '',
              name: '',
              credits: 0,
              suggestedYear: '',
              suggestedTerm: '',
            ));
    _name = TextEditingController(text: base.name);
    _code = TextEditingController(text: base.code);
    _credits = TextEditingController(
        text: base.credits == 0 && widget._addition == null && widget._original == null
            ? ''
            : (base.credits == base.credits.roundToDouble()
                ? base.credits.toStringAsFixed(0)
                : base.credits.toString()));
    _year = TextEditingController(text: base.suggestedYear);
    _term = TextEditingController(text: base.suggestedTerm);
    _degree = base.sfxwkc.contains('是') ||
        degreeYes[cleanField(base.sfxwkc)] == 1;
    _initialDegree = _degree;
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _credits, _year, _term]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _diffField(String input, String original) {
    final v = input.trim();
    if (v.isEmpty || v == original) return null;
    return v;
  }

  Future<void> _save() async {
    if (widget._isAddition) {
      await _saveAddition();
    } else {
      await _saveFetched();
    }
  }

  Future<void> _saveFetched() async {
    final original = widget._original!;
    final creditsText = _credits.text.trim();
    double? credits;
    if (creditsText.isNotEmpty) {
      credits = double.tryParse(creditsText);
      if (credits == null) {
        await showAppAlert(context, title: '无法保存', message: '学分格式不正确。');
        return;
      }
      if (credits == original.credits) credits = null;
    }
    final patch = PlanCoursePatch(
      key: plannedCourseKey(original),
      credits: credits,
      sfxwkc: _degree == _initialDegree ? null : (_degree ? '是' : '否'),
      suggestedYear: _diffField(_year.text, original.suggestedYear),
      suggestedTerm: _diffField(_term.text, original.suggestedTerm),
    );
    final notifier = ref.read(planOverridesProvider.notifier);
    if (patch.isEmpty) {
      await notifier.removePatch(patch.key);
    } else {
      await notifier.upsertPatch(patch);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveAddition() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      await showAppAlert(context, title: '无法保存', message: '请填写课程名称。');
      return;
    }
    final credits = double.tryParse(_credits.text.trim());
    if (credits == null || credits <= 0) {
      await showAppAlert(context, title: '无法保存', message: '请填写有效的学分。');
      return;
    }
    final course = PlannedCourse(
      code: cleanField(_code.text),
      name: name,
      credits: credits,
      suggestedYear: cleanField(_year.text),
      suggestedTerm: cleanField(_term.text),
      sfxwkc: _degree ? '是' : '否',
    );
    final notifier = ref.read(planOverridesProvider.notifier);
    final old = widget._addition;
    if (old != null) {
      await notifier.removeAddition(plannedCourseKey(old));
    }
    await notifier.upsertAddition(course);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final notifier = ref.read(planOverridesProvider.notifier);
    if (widget._isAddition) {
      final ok = await _confirm(
        context,
        title: '删除这门手动课程？',
        message: '该课程由你手动添加，删除后不可恢复。',
        confirmLabel: '删除',
      );
      if (!ok) return;
      await notifier.removeAddition(plannedCourseKey(widget._addition!));
    } else {
      final ok = await _confirm(
        context,
        title: '从计划中删除这门课程？',
        message: '将以覆盖方式隐藏该课程，重新采集后仍保持删除；可在数据管理页底部恢复。',
        confirmLabel: '删除',
      );
      if (!ok) return;
      await notifier.upsertPatch(
          PlanCoursePatch(key: plannedCourseKey(widget._original!), deleted: true));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final ok = await _confirm(
      context,
      title: '恢复原始值？',
      message: '将撤销你对该课程的全部修改，回到最近一次采集的值。',
      confirmLabel: '恢复',
    );
    if (!ok) return;
    await ref
        .read(planOverridesProvider.notifier)
        .removePatch(plannedCourseKey(widget._original!));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final isAddition = widget._isAddition;
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: Text(
          isAddition
              ? (widget._addition == null ? '新增计划课程' : '编辑计划课程')
              : '编辑计划课程',
          style: AppText.title.copyWith(color: tokens.labelPrimary),
        ),
        leading: AppGlassIconButton(
          icon: CupertinoIcons.back,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: AppTokens.pagePadding,
          right: AppTokens.pagePadding,
          top: AppTokens.space3,
          bottom: MediaQuery.paddingOf(context).bottom + AppTokens.space5,
        ),
        children: [
          AppGlassGroupedCard(
            title: '课程信息',
            footer: isAddition ? null : '留空的字段跟随最近一次采集值；重新采集不会覆盖你的修改。',
            child: Column(
              children: [
                _field('课程名称', _name,
                    placeholder: '必填', readOnly: !isAddition),
                _field('课程代码', _code,
                    placeholder: '选填', readOnly: !isAddition),
                _field(
                  '学分',
                  _credits,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                _field('建议学年', _year, placeholder: '如 2024-2025'),
                _field('建议学期', _term, placeholder: '如 1 / 2 / 3'),
                const AppDivider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTokens.space2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '学位课',
                          style: AppText.body
                              .copyWith(color: tokens.labelPrimary),
                        ),
                      ),
                      AppGlassSwitch(
                        value: _degree,
                        onChanged: (v) => setState(() => _degree = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          AppGlassButton(
            label: '保存',
            style: AppButtonStyle.prominent,
            expand: true,
            onTap: _save,
          ),
          if (widget._patch != null && !widget._patch!.deleted) ...[
            const SizedBox(height: AppTokens.space3),
            AppGlassButton(
              label: '恢复原始值',
              style: AppButtonStyle.regular,
              expand: true,
              onTap: _reset,
            ),
          ],
          if (widget._original != null || widget._addition != null) ...[
            const SizedBox(height: AppTokens.space3),
            AppGlassButton(
              label: isAddition ? '删除该课程' : '删除该课程（可恢复）',
              style: AppButtonStyle.plain,
              expand: true,
              onTap: _delete,
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? placeholder,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppText.body.copyWith(color: tokens.labelPrimary),
            ),
          ),
          Expanded(
            child: readOnly
                ? Text(
                    controller.text.isEmpty ? '—' : controller.text,
                    style: AppText.body.copyWith(color: tokens.labelSecondary),
                  )
                : AppGlassTextField(
                    controller: controller,
                    placeholder: placeholder,
                    keyboardType: keyboardType,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 教学计划信息编辑页（专业名称 / 毕业学分要求）
// ---------------------------------------------------------------------------

class PlanInfoEditPage extends ConsumerStatefulWidget {
  const PlanInfoEditPage({super.key, required this.rawPlan});

  /// 采集的原始计划（用于对比决定是否写覆盖）；可能为 null（纯手动计划）。
  final TeachingPlan? rawPlan;

  @override
  ConsumerState<PlanInfoEditPage> createState() => _PlanInfoEditPageState();
}

class _PlanInfoEditPageState extends ConsumerState<PlanInfoEditPage> {
  late final TextEditingController _programName;
  late final TextEditingController _graduationCredits;

  @override
  void initState() {
    super.initState();
    final overrides =
        ref.read(planOverridesProvider).value ?? const PlanOverrides();
    final raw = widget.rawPlan;
    _programName = TextEditingController(
        text: overrides.programName ?? raw?.programName ?? '');
    final credits = overrides.graduationCredits ?? raw?.graduationCredits;
    _graduationCredits = TextEditingController(
        text: credits == null || credits == 0 ? '' : credits.toString());
  }

  @override
  void dispose() {
    _programName.dispose();
    _graduationCredits.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = widget.rawPlan;
    final name = _programName.text.trim();
    final creditsText = _graduationCredits.text.trim();
    double? credits;
    if (creditsText.isNotEmpty) {
      credits = double.tryParse(creditsText);
      if (credits == null || credits <= 0) {
        await showAppAlert(
            context, title: '无法保存', message: '毕业学分要求格式不正确。');
        return;
      }
    }
    final notifier = ref.read(planOverridesProvider.notifier);
    await notifier.setPlanInfo(
      programName:
          name.isEmpty || name == (raw?.programName ?? '') ? null : name,
      graduationCredits:
          credits == null || credits == raw?.graduationCredits ? null : credits,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final ok = await _confirm(
      context,
      title: '恢复原始值？',
      message: '专业名称与毕业学分要求将回到最近一次采集的值。',
      confirmLabel: '恢复',
    );
    if (!ok) return;
    await ref
        .read(planOverridesProvider.notifier)
        .setPlanInfo(programName: null, graduationCredits: null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final overrides =
        ref.watch(planOverridesProvider).value ?? const PlanOverrides();
    final hasOverride =
        overrides.programName != null || overrides.graduationCredits != null;
    return AppGlassScaffold(
      extendBody: false,
      appBar: AppGlassAppBar(
        title: Text(
          '计划信息',
          style: AppText.title.copyWith(color: tokens.labelPrimary),
        ),
        leading: AppGlassIconButton(
          icon: CupertinoIcons.back,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: AppTokens.pagePadding,
          right: AppTokens.pagePadding,
          top: AppTokens.space3,
          bottom: MediaQuery.paddingOf(context).bottom + AppTokens.space5,
        ),
        children: [
          AppGlassGroupedCard(
            title: '计划信息',
            footer: '留空的字段跟随最近一次采集值；重新采集不会覆盖你的修改。',
            child: Column(
              children: [
                _field('专业名称', _programName, placeholder: '如 2023级临床医学'),
                _field(
                  '毕业学分',
                  _graduationCredits,
                  placeholder: '如 220',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          AppGlassButton(
            label: '保存',
            style: AppButtonStyle.prominent,
            expand: true,
            onTap: _save,
          ),
          if (hasOverride) ...[
            const SizedBox(height: AppTokens.space3),
            AppGlassButton(
              label: '恢复原始值',
              style: AppButtonStyle.regular,
              expand: true,
              onTap: _reset,
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? placeholder,
    TextInputType? keyboardType,
  }) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppText.body.copyWith(color: tokens.labelPrimary),
            ),
          ),
          Expanded(
            child: AppGlassTextField(
              controller: controller,
              placeholder: placeholder,
              keyboardType: keyboardType,
            ),
          ),
        ],
      ),
    );
  }
}
