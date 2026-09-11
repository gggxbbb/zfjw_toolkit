import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/overrides.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';
import 'package:zfjw_toolkit/data/database.dart' show courseRecordToJson;

/// 用户编辑（override）的持久化仓储。
///
/// 与快照/教学计划原始数据分离存储：重新采集只写原始数据，overrides 原样
/// 保留并再次应用。序列化逻辑集中在 data 层（core 模型保持无 JSON 依赖），
/// 与 [TeachingPlanRepository] 同走 SharedPreferences。
class OverrideRepository {
  static const _recordKey = 'record_overrides';
  static const _planKey = 'plan_overrides';

  Future<RecordOverrides> loadRecords() async {
    final raw =
        (await SharedPreferences.getInstance()).getString(_recordKey);
    if (raw == null) return const RecordOverrides();
    try {
      return _recordOverridesFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const RecordOverrides();
    }
  }

  Future<void> saveRecords(RecordOverrides overrides) async {
    final prefs = await SharedPreferences.getInstance();
    if (overrides.isEmpty) {
      await prefs.remove(_recordKey);
    } else {
      await prefs.setString(
          _recordKey, jsonEncode(_recordOverridesToJson(overrides)));
    }
  }

  Future<PlanOverrides> loadPlan() async {
    final raw = (await SharedPreferences.getInstance()).getString(_planKey);
    if (raw == null) return const PlanOverrides();
    try {
      return _planOverridesFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const PlanOverrides();
    }
  }

  Future<void> savePlan(PlanOverrides overrides) async {
    final prefs = await SharedPreferences.getInstance();
    if (overrides.isEmpty) {
      await prefs.remove(_planKey);
    } else {
      await prefs.setString(
          _planKey, jsonEncode(_planOverridesToJson(overrides)));
    }
  }
}

Map<String, dynamic> _recordOverridesToJson(RecordOverrides o) => {
      'patches': [for (final p in o.patches) _patchToJson(p)],
      'additions': [for (final a in o.additions) courseRecordToJson(a)],
    };

RecordOverrides _recordOverridesFromJson(Map<String, dynamic> json) =>
    RecordOverrides(
      patches: [
        for (final e in (json['patches'] as List<dynamic>? ?? []))
          _patchFromJson(Map<String, dynamic>.from(e as Map)),
      ],
      additions: [
        for (final e in (json['additions'] as List<dynamic>? ?? []))
          CourseRecord.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );

Map<String, dynamic> _patchToJson(RecordPatch p) => {
      'courseKey': p.courseKey,
      'xnm': p.xnm,
      'xqm': p.xqm,
      'deleted': p.deleted,
      if (p.cj != null) 'cj': p.cj,
      if (p.bfzcj != null) 'bfzcj': p.bfzcj,
      if (p.xf != null) 'xf': p.xf,
      if (p.jd != null) 'jd': p.jd,
      if (p.sfxwkc != null) 'sfxwkc': p.sfxwkc,
    };

RecordPatch _patchFromJson(Map<String, dynamic> json) => RecordPatch(
      courseKey: json['courseKey'] as String? ?? '',
      xnm: json['xnm'] as String? ?? '',
      xqm: json['xqm'] as String? ?? '',
      deleted: json['deleted'] as bool? ?? false,
      cj: json['cj'] as String?,
      bfzcj: json['bfzcj'] as String?,
      xf: json['xf'] as String?,
      jd: json['jd'] as String?,
      sfxwkc: json['sfxwkc'] as String?,
    );

Map<String, dynamic> _planOverridesToJson(PlanOverrides o) => {
      if (o.programName != null) 'programName': o.programName,
      if (o.graduationCredits != null)
        'graduationCredits': o.graduationCredits,
      'patches': [for (final p in o.patches) _planPatchToJson(p)],
      'additions': [for (final a in o.additions) a.toJson()],
    };

PlanOverrides _planOverridesFromJson(Map<String, dynamic> json) =>
    PlanOverrides(
      programName: json['programName'] as String?,
      graduationCredits: (json['graduationCredits'] as num?)?.toDouble(),
      patches: [
        for (final e in (json['patches'] as List<dynamic>? ?? []))
          _planPatchFromJson(Map<String, dynamic>.from(e as Map)),
      ],
      additions: [
        for (final e in (json['additions'] as List<dynamic>? ?? []))
          PlannedCourse.fromStoredJson(Map<String, dynamic>.from(e as Map)),
      ],
    );

Map<String, dynamic> _planPatchToJson(PlanCoursePatch p) => {
      'key': p.key,
      'deleted': p.deleted,
      if (p.credits != null) 'credits': p.credits,
      if (p.sfxwkc != null) 'sfxwkc': p.sfxwkc,
      if (p.suggestedYear != null) 'suggestedYear': p.suggestedYear,
      if (p.suggestedTerm != null) 'suggestedTerm': p.suggestedTerm,
    };

PlanCoursePatch _planPatchFromJson(Map<String, dynamic> json) =>
    PlanCoursePatch(
      key: json['key'] as String? ?? '',
      deleted: json['deleted'] as bool? ?? false,
      credits: (json['credits'] as num?)?.toDouble(),
      sfxwkc: json['sfxwkc'] as String?,
      suggestedYear: json['suggestedYear'] as String?,
      suggestedTerm: json['suggestedTerm'] as String?,
    );
