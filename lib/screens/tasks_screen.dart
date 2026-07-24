import 'package:flutter/material.dart';

import 'tasks_create_screen.dart';
import 'tasks_active_screen.dart';
import 'tasks_review_screen.dart';
import 'tasks_balances_screen.dart';
import 'tasks_history_screen.dart';
import '../services/family_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  Widget _menuCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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

              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(.12),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right),
            ],
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
                subtitle: 'Активные задания',
                screen: TasksActiveScreen(),
              ),
              _menuCard(
                context: context,
                icon: Icons.account_balance_wallet,
                color: Colors.teal,
                title: 'Мой счёт',
                subtitle: 'Накопленные награды',
                screen: TasksBalancesScreen(),
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
              subtitle: 'Выполненные задания',
              screen: TasksReviewScreen(),
            ),
            _menuCard(
              context: context,
              icon: Icons.account_balance_wallet,
              color: Colors.teal,
              title: 'Балансы',
              subtitle: 'Накопленные награды',
              screen: TasksBalancesScreen(),
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