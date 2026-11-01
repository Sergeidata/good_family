import 'package:flutter/material.dart';
import 'group_screen.dart';
import 'achievements_screen.dart';
import 'family_info_screen.dart';
import 'more_screen.dart';
import 'home_dashboard.dart';
import '../widgets/main_bottom_bar.dart';

/// Открыть «Достижения» на нужной внутренней вкладке.
/// 0 — Чемпионат, 1 — Личные, 2 — Групповые.
void openAchievementsTab(int innerIndex) {
  // Переключаем нижнюю вкладку на «Ачивки» (index 2)
  MainNavigationScreenState.current?.switchToTab(2);

  // Ждём кадр, чтобы IndexedStack показал вкладку,
  // и только потом переключаем внутренний TabBar.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AchievementsScreenState.current?.selectTab(innerIndex);
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

  /// Текущий живой экземпляр навигации.
  /// GlobalKey вешался на Scaffold, из-за чего currentState всегда был null.
  static MainNavigationScreenState? current;

  late int _currentIndex;

   void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

@override
void initState() {
  super.initState();
  current = this;
  _currentIndex = widget.initialIndex;
}

  @override
  void dispose() {
    if (current == this) current = null;
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    body: IndexedStack(
      index: _currentIndex,
      children: [
        const HomeDashboard(),
        const GroupScreen(),
        const AchievementsScreen(),
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