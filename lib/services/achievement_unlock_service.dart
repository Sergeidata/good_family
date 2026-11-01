import 'package:flutter/material.dart';

import '../screens/achievement_unlocked_screen.dart';
import 'achievement_seen_storage.dart';

class AchievementUnlockService {
  /// Возвращает ключи, которые ещё НЕ показывались.
  /// Первый запуск (seen == null) — молча сохраняет текущий набор.
  static Future<List<String>> takeNew(Set<String> currentKeys) async {
    if (currentKeys.isEmpty) return const [];

    final seen = await AchievementSeenStorage.load();

    if (seen == null) {
      // Первый запуск: не заваливаем пользователя пачкой поп-апов.
      await AchievementSeenStorage.save(currentKeys);
      return const [];
    }

    final newKeys = currentKeys.difference(seen);
    return newKeys.toList();
  }

  /// Помечает один ключ просмотренным (после показа).
  static Future<void> markSeen(String key) async {
    final seen = await AchievementSeenStorage.load() ?? <String>{};
    seen.add(key);
    await AchievementSeenStorage.save(seen);
  }

  /// Показывает очередь по одному и помечает каждый после показа.
  static Future<void> showQueue(
    BuildContext context, {
    required List<String> keys,
    required String Function(String key) titleFor,
  }) async {
    for (final key in keys) {
      if (!context.mounted) return;

      await AchievementUnlockedScreen.show(
        context,
        title: titleFor(key),
        achievementKey: key,
      );

      await markSeen(key);
    }
  }
}
