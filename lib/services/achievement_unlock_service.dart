import 'package:flutter/material.dart';

import '../screens/achievement_unlocked_screen.dart';
import 'achievement_seen_storage.dart';
import 'api_service.dart';

class AchievementUnlockService {
  /// true, если первичное заполнение seen_achievements уже произошло
  /// в этом запуске приложения. Сбрасывается при перезапуске процесса.
  static bool _seeded = false;

  /// Однократное заполнение при первом запуске с фичей: сохраняем ВСЕ
  /// текущие достижения (и личные, и групповые), чтобы не было каскада
  /// салютов и «потерянных» типов.
  static Future<void> ensureSeeded(String familyId) async {
    final seen = await AchievementSeenStorage.load();
    if (seen != null) return;

    final personal =
        await ApiService.getAchievements(familyId, "personal", null) ?? [];
    final group =
        await ApiService.getAchievements(familyId, "group", null) ?? [];

    final keys = <String>{
      for (final a in personal) 'personal:${a["achievement_key"]}',
      for (final a in group) 'group:${a["achievement_key"]}',
    };

    await AchievementSeenStorage.save(keys);
    _seeded = true;
  }

  /// Возвращает ключи, которые ещё НЕ показывались.
  static Future<List<String>> takeNew(Set<String> currentKeys) async {
    if (currentKeys.isEmpty) return const [];

    final seen = await AchievementSeenStorage.load();

    if (seen == null) {
      // Первый запуск: молча запоминаем текущий набор.
      await AchievementSeenStorage.save(currentKeys);
      _seeded = true;
      return const [];
    }

    // Тот же запуск, второй таб: молча дописываем, не вспыхиваем каскадом.
    if (_seeded) {
      await AchievementSeenStorage.save({...seen, ...currentKeys});
      return const [];
    }

    return currentKeys.difference(seen).toList();
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

  /// Проверить набор ключей и показать салют, если есть новые.
  static Future<void> checkAndShow(
    BuildContext context, {
    required Set<String> currentKeys,
    required String Function(String key) titleFor,
  }) async {
    final newKeys = await takeNew(currentKeys);
    if (newKeys.isEmpty || !context.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      await showQueue(context, keys: newKeys, titleFor: titleFor);
    });
  }
}
