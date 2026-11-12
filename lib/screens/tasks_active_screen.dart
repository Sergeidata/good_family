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
  List<dynamic> _upcoming = [];
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
    // Сервер отдаёт все задачи семьи (включая ещё не наступившие), поэтому
    // делим на клиенте по местному времени устройства:
    //   _tasks    — активные сегодня (или разовые без срока);
    //   _upcoming — ещё не наступили, показываем полупрозрачными.
    final mine = _role == 'child'
        ? tasks.where((t) => t['assigned_to'] == _userName)
        : tasks.where((t) => true);

    final pending = mine.where((t) => t['status'] == 'pending').toList();

    _tasks = pending.where((t) => isTaskActiveToday(t, now)).toList();

    // Разовая задача без повторения не может «наступить» — её никогда
    // не отправляем в «Скоро», иначе она застряла бы там навсегда.
    _upcoming = pending
        .where((t) => !isTaskActiveToday(t, now))
        .where((t) => repeatModeOf(t) != 'none')
        .where((t) => nextOccurrence(t, now) != null)
        .toList()
      ..sort((a, b) {
        final aNext = nextOccurrence(a, now);
        final bNext = nextOccurrence(b, now);
        if (aNext == null) return 1;
        if (bNext == null) return -1;
        return aNext.compareTo(bNext);
      });

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
    const pageTitleActive = 'Активные задания';
    const pageTitleMine = 'Мои задания';
    final title = isChild ? pageTitleMine : pageTitleActive;

    if (_loading) {
      return const Scaffold(body: Center(child: LoadingDots()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorState(
          message: _error!,
          onRetry: _loadData,
        ),
      );
    }

    // Обе группы пусты — показываем полноэкранную заглушку как раньше.
    if (_tasks.isEmpty && _upcoming.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: EmptyState(
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
        ),
        bottomNavigationBar: _bottomBar(),
      );
    }

    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_tasks.isNotEmpty) ...[
              _sectionHeader(
                label: 'Активные',
                count: _tasks.length,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 8),
              ..._tasks.map((task) => _taskCard(task, isChild, now)),
            ],
            if (_upcoming.isNotEmpty) ...[
              if (_tasks.isNotEmpty) const SizedBox(height: 12),
              _sectionHeader(
                label: 'Скоро',
                count: _upcoming.length,
                color: Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Эти задания ещё не наступили — выполнить их пока нельзя',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              ..._upcoming.map((task) => _taskCard(task, isChild, now)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _sectionHeader({
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return MainBottomBar(
      currentIndex: null,
      onTap: (index) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigationScreen(initialIndex: index),
          ),
          (_) => false,
        );
      },
    );
  }

  /// Карточка задания.
  ///
  /// [upcomingEnabled] == false — задание ещё не наступило: карточка
  /// полупрозрачная, вместо бейджа повторения показано КОГДА наступит,
  /// и кнопки действия нет (ни «Выполнено», ни «Удалить»).
  Widget _taskCard(Map<String, dynamic> task, bool isChild, DateTime now) {
    final isUpcoming = _upcoming.contains(task);
    final repeatColor = _repeatColor(task);
    final label = isUpcoming
        ? taskUpcomingLabel(task, now)
        : taskRepeatBadgeLabel(task);

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 108),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Цветная полоска
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: repeatColor,
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
                    Text(
                      task['title'] ?? '',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (!isChild)
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              task['assigned_to'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            isUpcoming ? Icons.schedule : Icons.repeat,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUpcoming ? Colors.grey.shade700 : repeatColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (isChild)
                      Row(
                        children: [
                          Icon(
                            isUpcoming ? Icons.schedule : Icons.repeat,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUpcoming ? Colors.grey.shade700 : repeatColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'От: ${task['created_by'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ),
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
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Кнопки действия — только у заданий, которые уже можно выполнять.
            if (!isUpcoming)
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

    // Пометка о наступлении — поверх полупрозрачной карточки.
    if (!isUpcoming) return card;

    return Opacity(
      opacity: 0.55,
      child: Stack(
        children: [
          IgnorePointer(child: card),
          Positioned(
            right: 12,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}