import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';

class TeachingPlanRepository {
  static const _key = 'teaching_plan';
  Future<TeachingPlan?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    return raw == null ? null : TeachingPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
  Future<void> save(TeachingPlan plan) async =>
      (await SharedPreferences.getInstance()).setString(_key, jsonEncode(plan.toJson()));
}
