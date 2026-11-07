import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'register_screen.dart';

/// Экран выбора: создать аккаунт, войти или продолжить без аккаунта.
///
/// Регистрация необязательна — старые версии приложения работают
/// без почты, и мы не ломаем их совместимость.
class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              const Icon(
                Icons.family_restroom_rounded,
                size: 72,
                color: Color(0xFF2196F3),
              ),
              const SizedBox(height: 20),

              const Text(
                'Аккаунт Good Family',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Аккаунт нужен, чтобы не потерять семью при смене '
                'телефона. Можно продолжить и без него.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),

              const Spacer(),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _openAuth(context, const RegisterScreen()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Создать аккаунт',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => _openAuth(context, const LoginScreen()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'У меня есть аккаунт',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Продолжить без аккаунта'),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Открывает auth-экран и, если вернулся `true` (успех),
  /// закрывает AuthGate — онбординг продолжится на WelcomeScreen.
  static Future<void> _openAuth(BuildContext context, Widget screen) async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => screen),
    );

    if (success == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
