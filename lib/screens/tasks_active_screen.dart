import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';
import 'tasks_create_screen.dart';
import '../utils/app_utils.dart';
import '../utils/task_repeat.dart';
import '../widgets/loading_dots.dart';
import '../widgets/error_state.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  final family = await FamilyStorage.loadFamily();
  _familyId = family['family_id'] ?? '';
  _userName = family['user_name'] ?? '';
  _role = family['role'] ?? '';

  final tasks = await ApiService.getTasks(_familyId, null);

  if (!mounted) return;

  if (tasks == null) {
    setState(() {
      _loading = false;
      _error = 'Нет связи с сервером';
    });
    return;
  }

  final now = DateTime.now();

  setState(() {
    if (_role == 'child') {
      _tasks = tasks.where((t) {
        if (t['status'] != 'pending' || t['assigned_to'] != _userName) return false;
        return isTaskActiveToday(t, now);
      }).toList();
    } else {
      _tasks = tasks.where((t) {
        if (t['status'] != 'pending') return false;
        return isTaskActiveToday(t, now);
      }).toList();
    }
    _loading = false;
    _error = null;
  });
}

 Future<void> _markDone(int taskId) async {
 final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),

    title: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Отметить выполненным?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Ты уверен, что выполнил задание? Родитель проверит его.",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Ещё нет",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Да, я сделал!",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
);

  if (confirmed != true) return;

  await ApiService.markTaskDone(taskId, _userName);
  _loadData();

  if (mounted) {
    showSuccessSnackBar(context, "Отлично! Задание выполнено ✅");
  }
}

  Future<void> _deleteTask(int taskId) async {
  final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),

    title: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: Colors.red.shade500,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Удалить задание?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Это действие нельзя отменить.",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Отмена",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade500,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Удалить",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
);
    if (confirmed != true) return;

    await ApiService.deleteTask(taskId, _userName);
    _loadData();
  }

  Color _repeatColor(Map<String, dynamic> task) {
    switch (repeatModeOf(task)) {
      case 'daily': return Colors.blue;
      case 'weekly': return Colors.purple;
      case 'weekdays': return Colors.teal;
      case 'weekends': return Colors.orange;
      case 'custom': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChild = _role == 'child';

    if (_loading) {
      return const Scaffold(body: Center(child: LoadingDots()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(isChild ? 'Мои задания' : 'Активные задания')),
        body: ErrorState(
          message: _error!,
          onRetry: _loadData,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(isChild ? 'Мои задания' : 'Активные задания')),
      body: _tasks.isEmpty
          ? EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Нет активных заданий',
              subtitle: isChild
                  ? 'Выполни задание и заработай монеты'
                  : 'Создай первое задание для семьи',
              actionText: isChild ? null : 'Создать задание',
              onAction: isChild
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TasksCreateScreen(),
                        ),
                      ).then((_) => _loadData());
                    },
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];

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
                            color: _repeatColor(task),
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
                                      Flexible(
                                        child: Text(
                                          taskRepeatBadgeLabel(task),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: _repeatColor(task), fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (isChild)
                                  Row(
                                    children: [
                                      const Icon(Icons.repeat, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          taskRepeatBadgeLabel(task),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: _repeatColor(task), fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('От: ${task['created_by'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                    ],
                                  ),
                                const SizedBox(height: 6),
                                Row(
  children: [
    const Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.circle, size: 24, color: Colors.amber),
        Icon(Icons.star, size: 13, color: Colors.white),
      ],
    ),
    const SizedBox(width: 6),
    Text(
      '${task['stars'] ?? 10}',
      style: TextStyle(color: Colors.orange.shade700, fontSize: 18, fontWeight: FontWeight.w600),
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
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _markDone(task['id']),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 20),
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