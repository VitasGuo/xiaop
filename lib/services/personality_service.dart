import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/models/companion.dart';

class PersonalityService {
  static const String _keyCurrent = 'companion_current';
  static const String _keyList = 'companion_list';

  // 获取当前使用的人格
  static Future<Companion> getCurrentCompanion() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyCurrent);
    if (json == null) return Companion.warmPreset;
    return Companion.decode(json);
  }

  // 设置当前使用的人格
  static Future<void> setCurrentCompanion(Companion companion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrent, Companion.encode(companion));
  }

  // 获取所有保存的人格列表
  static Future<List<Companion>> getAllCompanions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyList);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Companion.fromJson(e as Map<String, dynamic>)).toList();
  }

  // 保存一个人格到列表
  static Future<void> saveCompanion(Companion companion) async {
    final list = await getAllCompanions();
    final existIndex = list.indexWhere(
        (c) => c.name == companion.name && c.preset == companion.preset);
    if (existIndex != -1) {
      list[existIndex] = companion;
    } else {
      list.add(companion);
    }
    await _saveList(list);
  }

  // 从列表中删除一个人格
  static Future<void> deleteCompanion(String name) async {
    final list = await getAllCompanions();
    list.removeWhere((c) => c.name == name);
    await _saveList(list);
  }

  static Future<void> _saveList(List<Companion> list) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_keyList, json);
  }
}
