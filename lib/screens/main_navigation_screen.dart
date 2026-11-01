import 'package:flutter/material.dart';
import 'group_screen.dart';
import 'achievements_screen.dart';
import 'family_info_screen.dart';
import 'more_screen.dart';
import 'home_dashboard.dart';
import '../widgets/main_bottom_bar.dart';

final GlobalKey<MainNavigationScreenState> mainNavKey = GlobalKey();

/// Ключ к вкладке «Ачивки»: нужен, чтобы выбрать внутреннюю вкладку извне.
final GlobalKey<AchievementsScreenState> achievementsKey = GlobalKey();

/// Открыть «Достижения» на нужной внутренней вкладке.
/// 0 — Чемпионат, 1 — Личные, 2 — Групповые.
void openAchievementsTab(int innerIndex) {
  // Переключаем нижнюю вкладку на «Ачивки» (index 2)
  mainNavKey.currentState?.switchToTab(2);

  // Ждём кадр, чтобы IndexedStack показал вкладку,
  // и только потом переключаем внутренний TabBar.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    achievementsKey.currentState?.selectTab(innerIndex);
  });
}

enum AppScreen {
  home,
  stats,
  garden,
  tasks,
  group,
  achievements,
  family,
  more,
}

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {

  late int _currentIndex;

   void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

@override
void initState() {
  super.initState();
  _currentIndex = widget.initialIndex;
}

 @override
Widget build(BuildContext context) {
  return Scaffold(
    key: mainNavKey,
    body: IndexedStack(
      index: _currentIndex,
      children: [
        const HomeDashboard(),
        const GroupScreen(),
        AchievementsScreen(key: achievementsKey),
        const FamilyInfoScreen(),
        const MoreScreen(),
      ],
    ),
    bottomNavigationBar: MainBottomBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
    ),
  );
}
}