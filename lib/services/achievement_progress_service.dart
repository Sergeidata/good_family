import 'api_service.dart';

/// Результат загрузки прогресса личных достижений.
class AchievementProgress {
  /// Ближайшее к завершению достижение (ratio < 1), либо null.
  final Map<String, dynamic>? next;

  /// true, если все личные достижения уже получены.
  final bool allEarned;

  const AchievementProgress({this.next, this.allEarned = false});
}

class AchievementProgressService {
  /// Загружает прогресс всех личных достижений одним запросом и выбирает
  /// ближайшее к завершению. При ошибке сети возвращает пустой результат.
  static Future<AchievementProgress> load({
    required String familyId,
    required String userName,
  }) async {
    final list = await ApiService.getAchievementProgressAll(familyId, userName);
    if (list == null || list.isEmpty) {
      return const AchievementProgress();
    }

    Map<String, dynamic>? best;
    double bestRatio = -1;

    for (final item in list) {
      if (item is! Map) continue;

      final current = (item["current"] as num?)?.toInt() ?? 0;
      final target = (item["target"] as num?)?.toInt() ?? 0;
      if (target <= 0) continue;

      final ratio = current / target;
      if (ratio >= 1.0) continue;

      if (ratio > bestRatio) {
        bestRatio = ratio;
        best = Map<String, dynamic>.from(item);
      }
    }

    return AchievementProgress(next: best, allEarned: best == null);
  }

  /// Название достижения: серверное, иначе fallback (клиентский словарь/ключ).
  static String titleOf(
    Map<String, dynamic> item, {
    String Function(String key)? fallback,
  }) {
    final serverTitle = item["title"]?.toString().trim() ?? "";
    if (serverTitle.isNotEmpty) return serverTitle;

    final key = item["key"].toString();
    return fallback?.call(key) ?? key;
  }
}
