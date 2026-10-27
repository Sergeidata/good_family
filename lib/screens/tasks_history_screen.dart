import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/loading_dots.dart';
import '../utils/app_utils.dart';

class TasksHistoryScreen extends StatefulWidget {
  const TasksHistoryScreen({super.key});

  @override
  State<TasksHistoryScreen> createState() => _TasksHistoryScreenState();
}

class _TasksHistoryScreenState extends State<TasksHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _familyId = '';
  String _userName = '';
  String _role = '';
  List<dynamic> _tasks = [];
  List<dynamic> _rewardRequests = [];
  String? _filterChild;
  String? _filterStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final family = await FamilyStorage.loadFamily();
    _familyId = family['family_id'] ?? '';
    _userName = family['user_name'] ?? '';
    _role = family['role'] ?? '';

    // История заданий
    final tasks = await ApiService.getTasks(_familyId, _role == 'child' ? _userName : null);
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final filteredTasks = tasks.where((t) {
      final status = t['status'] as String? ?? '';
      if (!['approved', 'paid', 'rejected', 'done'].contains(status)) return false;
      final dateStr = t['approved_at'] ?? t['done_at'] ?? t['created_at'] ?? '';
      if (dateStr.toString().isEmpty) return true;
      try {
        return DateTime.parse(dateStr.toString()).isAfter(thirtyDaysAgo);
      } catch (_) {
        return true;
      }
    }).toList();

    filteredTasks.sort((a, b) {
      final aDate = a['approved_at'] ?? a['done_at'] ?? a['created_at'] ?? '';
      final bDate = b['approved_at'] ?? b['done_at'] ?? b['created_at'] ?? '';
      return bDate.toString().compareTo(aDate.toString());
    });

    // История наград (покупок)
    final requests = await ApiService.getRewardRequests(_familyId);
    final filteredRequests = _role == 'child'
        ? requests.where((r) => r['child_name'] == _userName).toList()
        : requests;

    setState(() {
      _tasks = filteredTasks;
      _rewardRequests = filteredRequests;
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
      final dt = parseServerDate(dateStr);
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
    final names = _tasks.map((t) => t['assigned_to'].toString()).toSet();
    names.addAll(_rewardRequests.map((r) => r['child_name'].toString()));
    return names;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: LoadingDots()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Задания'),
            Tab(text: 'Награды'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Фильтр по ребёнку (для родителя)
          if (_role != 'child')
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
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
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTasksHistory(),
                _buildRewardsHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Вкладка "Задания"
  Widget _buildTasksHistory() {
    final filtered = _filteredTasks;
    if (filtered.isEmpty) {
      return const Center(child: Text('История заданий пуста'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final task = filtered[i];
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
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(_statusIcon(status), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('${task['assigned_to'] ?? ''} • ${_statusLabel(status)} • 🪙 ${task['stars'] ?? 10}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Text(_formatDate(dateStr), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Вкладка "Награды"
  Widget _buildRewardsHistory() {
    final filtered = _rewardRequests.where((r) {
      if (_filterChild != null && r['child_name'] != _filterChild) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('История наград пуста'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final req = filtered[i];
        final status = req['status'] ?? '';
        Color color;
        IconData icon;
        String label;
        switch (status) {
          case 'pending': color = Colors.orange; icon = Icons.schedule; label = 'Ожидает'; break;
          case 'approved': color = Colors.green; icon = Icons.check_circle; label = 'Одобрено'; break;
          case 'completed': color = Colors.blue; icon = Icons.done_all; label = 'Получено'; break;
          case 'rejected': color = Colors.red; icon = Icons.cancel; label = 'Отклонено'; break;
          default: color = Colors.grey; icon = Icons.circle; label = status;
        }

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
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${req['emoji'] ?? "🎁"} ${req['title'] ?? ""}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('${req['child_name']} • $label • ${req['cost_stars']} 🪙',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Text(_formatDate(req['created_at']),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}