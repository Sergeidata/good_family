import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';

class TasksActiveScreen extends StatefulWidget {
  const TasksActiveScreen({super.key});

  @override
  State<TasksActiveScreen> createState() => _TasksActiveScreenState();
}

class _TasksActiveScreenState extends State<TasksActiveScreen> {
  String _familyId = '';
  String _userName = '';
  String _role = '';
  List<dynamic> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final family = await FamilyStorage.loadFamily();
    _familyId = family['family_id'] ?? '';
    _userName = family['user_name'] ?? '';
    _role = family['role'] ?? '';

    final tasks = await ApiService.getTasks(_familyId, null);
    setState(() {
      if (_role == 'child') {
        _tasks = tasks.where((t) => t['status'] == 'pending' && t['assigned_to'] == _userName).toList();
      } else {
        _tasks = tasks.where((t) => t['status'] == 'pending').toList();
      }
      _loading = false;
    });
  }

  Future<void> _markDone(int taskId) async {
    await ApiService.markTaskDone(taskId, _userName);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отлично! Задание выполнено ✅')),
      );
    }
  }

  Future<void> _deleteTask(int taskId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить задание?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ApiService.deleteTask(taskId, _userName);
    _loadData();
  }

  Color _repeatColor(String mode) {
    switch (mode) {
      case 'daily': return Colors.blue;
      case 'weekly': return Colors.purple;
      case 'weekdays': return Colors.teal;
      case 'weekends': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _repeatLabel(String mode) {
    switch (mode) {
      case 'daily': return 'Ежедневно';
      case 'weekly': return 'Еженедельно';
      case 'weekdays': return 'По будням';
      case 'weekends': return 'По выходным';
      default: return 'Разовое';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isChild = _role == 'child';

    return Scaffold(
      appBar: AppBar(title: Text(isChild ? 'Мои задания' : 'Активные задания')),
      body: _tasks.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Нет активных заданий', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                final repeatMode = task['repeat_mode'] ?? 'none';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        // Цветная полоска
                        Container(
                          width: 6,
                          decoration: BoxDecoration(
                            color: _repeatColor(repeatMode),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                        ),
                        // Содержимое
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task['title'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                if (!isChild)
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(task['assigned_to'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.repeat, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(_repeatLabel(repeatMode), style: TextStyle(color: _repeatColor(repeatMode), fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                if (isChild)
                                  Row(
                                    children: [
                                      const Icon(Icons.repeat, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(_repeatLabel(repeatMode), style: TextStyle(color: _repeatColor(repeatMode), fontSize: 13, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('От: ${task['created_by'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                    ],
                                  ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.card_giftcard, size: 16, color: Colors.orange.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      '⭐ ${task['stars'] ?? 10}',
                                      style: TextStyle(color: Colors.orange.shade700, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Кнопка: Я сделал (ребёнок) или Удалить (родитель)
                        if (isChild)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ElevatedButton.icon(
                              onPressed: () => _markDone(task['id']),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Я сделал!'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteTask(task['id']),
                          ),
                      ],
                    ),
                  ),
                );
              },
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
}