import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/auth_service.dart';
import '../services/family_storage.dart';
import 'main_navigation_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Загружаем данные семьи параллельно с показом анимации
    final familyFuture = FamilyStorage.loadFamily();
    final tokenFuture = AuthService.loadToken();

    await Future.delayed(const Duration(milliseconds: 1500));

    String? familyId;
    try {
      familyId = (await familyFuture)["family_id"] as String?;
    } catch (_) {
      familyId = null;
    }

    String? token;
    try {
      token = await tokenFuture;
    } catch (_) {
      token = null;
    }

    // Локальных данных нет, но есть сохранённый аккаунт —
    // пробуем восстановить семью с сервера (переустановка приложения).
    if (familyId == null && token != null && token.isNotEmpty) {
      familyId = await _restoreFromAccount();
    }

    if (!mounted) return;

    final Widget next = familyId != null
        ? const MainNavigationScreen()
        : const WelcomeScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  /// Восстанавливает FamilyStorage из /auth/me.
  /// Возвращает family_id либо null, если аккаунт не привязан к семье.
  Future<String?> _restoreFromAccount() async {
    try {
      final me = await AuthService.fetchMe();
      final family = me?["family"];
      if (family is! Map) return null;

      final restored = Map<String, dynamic>.from(family);
      final restoredId = (restored["family_id"] ?? "").toString();
      if (restoredId.isEmpty) return null;

      await FamilyStorage.saveFamily({
        "family_id": restored["family_id"],
        "invite_code": restored["invite_code"],
        "family_name": restored["family_name"],
        "user_name": restored["user_name"],
        "role": restored["role"],
        "avatar": restored["avatar"] ?? "",
      });

      return restoredId;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/animations/family.json',
          width: 250,
          height: 250,
          repeat: false,
          animate: true,
        ),
      ),
    );
  }
}