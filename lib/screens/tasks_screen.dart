import 'package:flutter/material.dart';

import 'tasks_create_screen.dart';
import 'tasks_active_screen.dart';
import 'tasks_review_screen.dart';
import 'tasks_history_screen.dart';
import '../services/family_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';
import 'reward_shop_screen.dart';
import 'reward_requests_screen.dart';
import '../services/api_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _familyId = '';

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  Future<void> _loadFamily() async {
    final family = await FamilyStorage.loadFamily();
    setState(() => _familyId = family["family_id"] ?? '');
  }

  Widget _badge(int count) {
    if (count <= 0) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _menuCard({
  required BuildContext context,
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
  required Widget screen,
  Widget? trailing,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: color.withOpacity(0.12),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.045),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => screen,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Иконка
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),

              const SizedBox(width: 16),

              // Текст
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Стрелка + счётчик
              if (trailing != null)
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                      size: 26,
                    ),
                    Positioned(
                      right: -4,
                      bottom : -32,
                      child: trailing,
                    ),
                  ],
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

 @override
Widget build(BuildContext context) {
  return FutureBuilder<Map<String, dynamic>>(
    future: FamilyStorage.loadFamily(),
    builder: (context, snapshot) {
      final role = snapshot.data?['role'] ?? 'child';
      final isChild = role == 'child';

      if (isChild) {
  return Scaffold(
    appBar: AppBar(title: const Text('Хорошие дела')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
       _menuCard(
          context: context,
          icon: Icons.assignment,
          color: Colors.green,
          title: 'Мои задания',
          subtitle: 'Выполняй задания и зарабатывай монеты!',
          screen: TasksActiveScreen(),
          trailing: FutureBuilder<List<dynamic>?>(
  future: ApiService.getTasks(_familyId, null),
  builder: (ctx, snap) {
    final tasks = snap.data ?? [];
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final count = tasks.where((t) {
      if (t["status"] != "pending") return false;
      if (t["assigned_to"] != snapshot.data?["user_name"]) return false;
      final repeatMode = t["repeat_mode"] ?? "none";
      if (repeatMode == "weekends" && !isWeekend) return false;
      if (repeatMode == "weekdays" && isWeekend) return false;
      return true;
    }).length;
    return _badge(count);
  },
),
        ),
        _menuCard(
          context: context,
          icon: Icons.store,
          color: Colors.amber,
          title: 'Магазин наград',
          subtitle: 'Тратьте заработанные монеты на награды',
          screen: RewardShopScreen(childMode: true),
        ),
        _menuCard(
          context: context,
          icon: Icons.history,
          color: Colors.purple,
          title: 'История',
          subtitle: 'Последние 30 дней',
          screen: TasksHistoryScreen(),
        ),
      ],
    ),
  );
}

      // Родитель — полное меню
      return Scaffold(
        appBar: AppBar(title: const Text('Хорошие дела')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _menuCard(
              context: context,
              icon: Icons.add_circle,
              color: Colors.blue,
              title: 'Создать задание',
              subtitle: 'Добавить новое хорошее дело',
              screen: const TasksCreateScreen(),
            ),
            _menuCard(
              context: context,
              icon: Icons.assignment,
              color: Colors.green,
              title: 'Активные задания',
              subtitle: 'Все действующие задания',
              screen: TasksActiveScreen(),
            ),
            _menuCard(
              context: context,
              icon: Icons.fact_check,
              color: Colors.orange,
              title: 'На проверке',
              subtitle: 'Выполненные задания, которые нужно проверить',
              screen: TasksReviewScreen(),
              trailing: FutureBuilder<List<dynamic>?>(
                future: ApiService.getTasks(_familyId, null),
                builder: (ctx, snap) {
                  final count = snap.data?.where((t) => t["status"] == "done").length ?? 0;
                  return _badge(count);
                },
              ),
            ),
           _menuCard(
              context: context,
              icon: Icons.store,
              color: Colors.amber,
              title: 'Магазин наград',
              subtitle: 'Добавляйте и управляйте наградами',
              screen: RewardShopScreen(),
            ),

            _menuCard(
              context: context,
              icon: Icons.shopping_bag,
              color: Colors.deepOrange,
              title: 'Балансы и запросы',
              subtitle: 'Монеты детей и запросы на награды',
              screen: const RewardRequestsScreen(),
              trailing: FutureBuilder<List<dynamic>>(
                future: ApiService.getRewardRequests(_familyId),
                builder: (ctx, snap) {
                  final count = snap.data?.where((r) => r["status"] == "pending").length ?? 0;
                  return _badge(count);
                },
              ),
            ),
            _menuCard(
              context: context,
              icon: Icons.history,
              color: Colors.purple,
              title: 'История',
              subtitle: 'Последние 30 дней',
              screen: TasksHistoryScreen(),
            ),
          ],
        ),
bottomNavigationBar: MainBottomBar(
  currentIndex: null,
  onTap: (index) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(
          initialIndex: index,
        ),
      ),
      (_) => false,
    );
  },
),

      );
    },
  );
}
}