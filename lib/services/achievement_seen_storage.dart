import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ключи достижений, которые пользователь уже видел
/// (с префиксом типа: "personal:3", "group:10").
class AchievementSeenStorage {
  static const _key = 'seen_achievements';

  /// `null` — ключа ещё нет (первый запуск): вызывающий должен
  /// молча сохранить текущий набор и ничего не показывать.
  static Future<Set<String>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};

      return decoded.map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> save(Set<String> keys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(keys.toList()));
    } catch (_) {
      // молча: сбой сохранения не должен ломать показ достижений
    }
  }
}
