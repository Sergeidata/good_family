import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Одно достижение на карточке-картинке.
class ShareAchievementItem {
  final String title;
  final IconData icon;
  final Color color;

  const ShareAchievementItem({
    required this.title,
    required this.icon,
    required this.color,
  });
}

/// Карточка для шаринга: логический размер 360×640,
/// при [exportPixelRatio] = 3 даёт картинку 1080×1920 (сторис).
class AchievementShareCard extends StatelessWidget {
  static const double cardWidth = 360;
  static const double cardHeight = 640;
  static const double exportPixelRatio = 3.0;

  static const String rustoreUrl =
      'https://apps.rustore.ru/app/com.example.family_focus';

  /// Путь к логотипу — его нужно precacheImage перед снимком.
  static const String logoAsset = 'assets/images/logo.png';

  final String title;
  final String userName;
  final String avatar;
  final String badgeText;
  final List<ShareAchievementItem> achievements;

  const AchievementShareCard({
    super.key,
    required this.title,
    required this.userName,
    required this.avatar,
    required this.badgeText,
    required this.achievements,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(44)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Логотип
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      logoAsset,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good Family',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                      Text(
                        'семья в порядке',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Аватар + имя
            CircleAvatar(
              radius: 42,
              backgroundColor: const Color(0xFFF3E6E8),
              child: Text(
                avatar.isEmpty ? '👤' : avatar,
                style: const TextStyle(fontSize: 38),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A8A8A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              badgeText,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6B6B),
              ),
            ),

            const SizedBox(height: 20),

            // Список достижений
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: achievements.isEmpty
                    ? const Center(
                        child: Text(
                          '🏆',
                          style: TextStyle(fontSize: 64),
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in achievements)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: item.color,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      size: 21,
                                      color: const Color(0xFF1B1B1B),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1B1B1B),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),

            // QR на RuStore
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
              child: Row(
                children: [
                  QrImageView(
                    data: rustoreUrl,
                    size: 80,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Скачайте Good Family\nв RuStore',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B1B1B),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
