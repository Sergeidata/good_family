import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// Полноэкранная праздничная анимация при получении достижения.
/// Закрывается сама через [_autoCloseAfter] или по кнопке «Круто!».
class AchievementUnlockedScreen extends StatefulWidget {
  final String title;
  final String achievementKey;

  const AchievementUnlockedScreen({
    super.key,
    required this.title,
    required this.achievementKey,
  });

  /// Показать поверх текущего экрана и дождаться закрытия.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String achievementKey,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Achievement unlocked',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => AchievementUnlockedScreen(
        title: title,
        achievementKey: achievementKey,
      ),
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AchievementUnlockedScreen> createState() =>
      _AchievementUnlockedScreenState();
}

class _AchievementUnlockedScreenState
    extends State<AchievementUnlockedScreen> {
  static const _autoCloseAfter = Duration(seconds: 3);

  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();

    // Вибрация + системный клик: без аудио-зависимостей.
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    _closeTimer = Timer(_autoCloseAfter, _close);
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ассет: 17297-fireworks.json из MIT-репозитория
              // https://github.com/xvrh/lottie-flutter (MIT License).
              // Локальная копия: assets/animations/achievement_confetti.json
              SizedBox(
                width: 280,
                height: 280,
                child: Lottie.asset(
                  'assets/animations/achievement_confetti.json',
                  fit: BoxFit.contain,
                  repeat: false,
                  animate: true,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                '🎉 Новое достижение!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _close,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B5E20),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Круто!',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
