import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
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

    await Future.delayed(const Duration(milliseconds: 1500));

    String? familyId;
    try {
      familyId = (await familyFuture)["family_id"] as String?;
    } catch (_) {
      familyId = null;
    }

    if (!mounted) return;

    final Widget next = familyId != null
        ? const MainNavigationScreen()
        : const WelcomeScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
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