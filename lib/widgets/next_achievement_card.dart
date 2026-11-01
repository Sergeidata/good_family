import 'package:flutter/material.dart';

/// Карточка прогресса до ближайшего личного достижения.
class NextAchievementCard extends StatelessWidget {
  final String title;
  final int current;
  final int target;
  final VoidCallback? onTap;

  /// Цвета градиента. По умолчанию — зелёный (стиль приложения).
  final List<Color>? gradientColors;

  const NextAchievementCard({
    super.key,
    required this.title,
    required this.current,
    required this.target,
    this.onTap,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final safeTarget = target <= 0 ? 1 : target;
    final ratio = (current / safeTarget).clamp(0.0, 1.0);
    final left = (safeTarget - current).clamp(0, safeTarget);

    final gradient = LinearGradient(
      colors: gradientColors ??
          [Colors.green.shade400, Colors.green.shade600],
    );
    const radius = 22.0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'До следующего достижения',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 22,
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Ближайшее к завершению',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$current из $safeTarget',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _daysLeftLabel(left),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );

    if (onTap == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: content,
      );
    }

    // Ink + InkWell: волна рисуется поверх градиента, а не под ним.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточка «все личные достижения получены».
class AllAchievementsEarnedCard extends StatelessWidget {
  final VoidCallback? onTap;

  const AllAchievementsEarnedCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [Colors.amber.shade400, Colors.orange.shade600],
    );
    const radius = 22.0;

    final content = Row(
      children: [
        const Icon(
          Icons.emoji_events_rounded,
          color: Colors.white,
          size: 34,
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            '🎉 Все личные достижения получены!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.8),
            size: 24,
          ),
      ],
    );

    if (onTap == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// «ещё 1 день!» / «осталось 3 дня» / «осталось 21 день» / «осталось 5 дней».
String _daysLeftLabel(int left) {
  if (left <= 0) return 'готово!';

  final mod10 = left % 10;
  final mod100 = left % 100;

  // 1, 21, 31... но не 11
  if (mod10 == 1 && mod100 != 11) {
    return left == 1 ? 'ещё 1 день!' : 'осталось $left день';
  }

  // 2–4, 22–24... но не 12–14
  final isFew = mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14);

  return 'осталось $left ${isFew ? "дня" : "дней"}';
}
