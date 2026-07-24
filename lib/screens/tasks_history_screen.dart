import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';

class TasksHistoryScreen extends StatefulWidget {
  const TasksHistoryScreen({super.key});

  @override
  State<TasksHistoryScreen> createState() => _TasksHistoryScreenState();
}

class _TasksHistoryScreenState extends State<TasksHistoryScreen> {
  String _familyId = '';
  String _userName = '';
  List<dynamic> _tasks = [];
  String? _filterChild;
  String? _filterStatus;
  bool _loading = true;
  String _role = '';

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

    final tasks = await ApiService.getTasks(_familyId, _role == 'child' ? _userName : null);

    // Фильтруем: только завершённые за последние 30 дней
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));


    if (_role == 'child') {
      tasks.removeWhere((t) => t['assigned_to'] != _userName);
    }

    setState(() {
      _tasks = tasks.where((t) {
        final status = t['status'] as String? ?? '';
        // Только завершённые статусы
        if (!['approved', 'paid', 'rejected', 'done'].contains(status)) return false;

        // Проверяем дату (берём самую позднюю из created_at, done_at, approved_at)
        final dateStr = t['approved_at'] ?? t['done_at'] ?? t['created_at'] ?? '';
        if (dateStr.toString().isEmpty) return true;
        try {
          final date = DateTime.parse(dateStr.toString());
          return date.isAfter(thirtyDaysAgo);
        } catch (_) {
          return true;
        }
      }).toList();

      // Сортируем: свежие сверху
      _tasks.sort((a, b) {
        final aDate = a['approved_at'] ?? a['done_at'] ?? a['created_at'] ?? '';
        final bDate = b['approved_at'] ?? b['done_at'] ?? b['created_at'] ?? '';
        return bDate.toString().compareTo(aDate.toString());
      });

      _loading = false;
    });
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'paid': return Icons.payments;
      case 'rejected': return Icons.cancel;
      case 'done': return Icons.fact_check;
      default: return Icons.circle;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'paid': return Colors.orange;
      case 'rejected': return Colors.red;
      case 'done': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved': return 'Одобрено';
      case 'paid': return 'Выплачено';
      case 'rejected': return 'Отклонено';
      case 'done': return 'На проверке';
      default: return status;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).add(const Duration(hours: 3));
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  List<dynamic> get _filteredTasks {
    return _tasks.where((t) {
      if (_filterChild != null && t['assigned_to'] != _filterChild) return false;
      if (_filterStatus != null && t['status'] != _filterStatus) return false;
      return true;
    }).toList();
  }

  Set<String> get _childrenNames {
    return _tasks.map((t) => t['assigned_to'].toString()).toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _filteredTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('История')),
      body: Column(
        children: [
          // Фильтры
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Фильтр по ребёнку
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _filterChild,
                    decoration: InputDecoration(
                      labelText: 'Ребёнок',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Все')),
                      ..._childrenNames.map((name) => DropdownMenuItem(value: name, child: Text(name))),
                    ],
                    onChanged: (v) => setState(() => _filterChild = v),
                  ),
                ),
                const SizedBox(width: 10),
                // Фильтр по статусу
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _filterStatus,
                    decoration: InputDecoration(
                      labelText: 'Статус',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Все')),
                      DropdownMenuItem(value: 'approved', child: Text('Одобрено')),
                      DropdownMenuItem(value: 'paid', child: Text('Выплачено')),
                      DropdownMenuItem(value: 'rejected', child: Text('Отклонено')),
                      DropdownMenuItem(value: 'done', child: Text('На проверке')),
                    ],
                    onChanged: (v) => setState(() => _filterStatus = v),
                  ),
                ),
              ],
            ),
          ),

          // Список
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 72, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('История пуста', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text('Здесь появятся завершённые задания за последние 30 дней', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final task = filtered[index];
                      final status = task['status'] ?? '';
                      final color = _statusColor(status);
                      final dateStr = task['approved_at'] ?? task['done_at'] ?? task['created_at'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              // Иконка статуса
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_statusIcon(status), color: color, size: 20),
                              ),
                              const SizedBox(width: 12),

                              // Описание
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${task['assigned_to'] ?? ''} • ${_statusLabel(status)} • ⭐ ${task['stars'] ?? 10}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),

                              // Дата
                              Text(
                                _formatDate(dateStr),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
}