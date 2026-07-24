import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';

class TasksCreateScreen extends StatefulWidget {
  const TasksCreateScreen({super.key});

  @override
  State<TasksCreateScreen> createState() => _TasksCreateScreenState();
}

class _TasksCreateScreenState extends State<TasksCreateScreen> {
  final _titleController = TextEditingController();
  final _rewardController = TextEditingController();

  String _familyId = '';
  String _userName = '';
  String _role = '';

  List<dynamic> _children = [];
  List<dynamic> _rewardTypes = [];

  String? _selectedChild;
  bool _allChildren = false;
  int? _selectedRewardTypeId;
  String _repeatMode = 'none';

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

    final members = await ApiService.getMembers(_familyId);
    _children = (members?['members'] ?? [])
        .where((m) => m['role'] == 'child')
        .toList();

    _rewardTypes = await ApiService.getRewardTypes(_familyId);

    if (_rewardTypes.isNotEmpty) {
      _selectedRewardTypeId = _rewardTypes.first['id'];
    }

    setState(() => _loading = false);
  }

  Future<void> _createTask() async {
    final title = _titleController.text.trim();
    final reward = int.tryParse(_rewardController.text) ?? 0;

    if (title.isEmpty) {
      _showSnack('Введите название задания');
      return;
    }
    if (reward <= 0) {
      _showSnack('Введите размер награды');
      return;
    }
    if (_selectedRewardTypeId == null) {
      _showSnack('Выберите тип награды');
      return;
    }
    if (!_allChildren && _selectedChild == null) {
      _showSnack('Выберите ребёнка');
      return;
    }

    if (_allChildren) {
      for (final child in _children) {
        await ApiService.createTask(
          familyId: _familyId,
          title: title,
          stars: _selectedStars,
          createdBy: _userName,
          assignedTo: child['user_name'],
          repeatMode: _repeatMode,
        );
      }
    } else {
      await ApiService.createTask(
        familyId: _familyId,
        title: title,
        stars: _selectedStars,
        createdBy: _userName,
        assignedTo: _selectedChild!,
        repeatMode: _repeatMode,
      );
    }

    _showSnack('Задание создано');
    _titleController.clear();
    _rewardController.clear();
  }


 int _selectedStars = 10;

Widget _starChip(String emoji, String label, int stars) {
  final selected = _selectedStars == stars;
  return ChoiceChip(
    label: Text('$emoji $label'),
    selected: selected,
    onSelected: (_) => setState(() => _selectedStars = stars),
    selectedColor: Colors.amber.shade100,
  );
} 

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Создать задание')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // НАЗВАНИЕ
            _sectionTitle('Название'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Например: Помыть посуду',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: const Icon(Icons.edit),
              ),
            ),

            const SizedBox(height: 24),

            // ДЛЯ КОГО
            _sectionTitle('Для кого'),
            const SizedBox(height: 8),
            ..._children.map((child) => RadioListTile<String>(
                  title: Text('${child['avatar'] ?? '👦'} ${child['user_name']}'),
                  value: child['user_name'],
                  groupValue: _allChildren ? null : _selectedChild,
                  onChanged: (v) => setState(() {
                    _allChildren = false;
                    _selectedChild = v;
                  }),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                )),
            RadioListTile<bool>(
              title: const Text('👨‍👩‍👧 Всем детям'),
              value: true,
              groupValue: _allChildren,
              onChanged: (v) => setState(() {
                _allChildren = v ?? false;
                _selectedChild = null;
              }),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),

            const SizedBox(height: 24),

            // ЗВЁЗДЫ
_sectionTitle('Сложность и награда'),
const SizedBox(height: 8),
Wrap(
  spacing: 8,
  children: [
    _starChip('⭐', 'Очень легко', 5),
    _starChip('⭐⭐', 'Легко', 10),
    _starChip('⭐⭐⭐', 'Обычно', 20),
    _starChip('⭐⭐⭐⭐', 'Сложно', 40),
    _starChip('⭐⭐⭐⭐⭐', 'Очень сложно', 80),
  ],
),
const SizedBox(height: 24),

DropdownButtonFormField<int>(
  value: _selectedRewardTypeId,
  decoration: InputDecoration(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    prefixIcon: const Icon(Icons.category),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  ),
  items: [
    ..._rewardTypes.map((t) => DropdownMenuItem<int>(
          value: t['id'],
          child: Text(
            '${t['icon'] ?? '🎁'} ${t['name']}',
            overflow: TextOverflow.ellipsis,
          ),
        )),
    const DropdownMenuItem<int>(
      value: -1,
      child: Text('➕ Добавить новый тип'),
    ),
  ],
  onChanged: (v) async {
    if (v == -1) {
      final name = await _showAddRewardTypeDialog();
      if (name != null) {
        await ApiService.createRewardType(_familyId, name);
        setState(() {});
        _loadData();
      }
      return;
    }
    setState(() => _selectedRewardTypeId = v);
  },
),

            const SizedBox(height: 24),

            // ПОВТОРЕНИЕ
            _sectionTitle('Повторение'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _repeatMode,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: const Icon(Icons.repeat),
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Разовое')),
                DropdownMenuItem(value: 'daily', child: Text('Ежедневно')),
                DropdownMenuItem(value: 'weekly', child: Text('Еженедельно')),
                DropdownMenuItem(value: 'weekdays', child: Text('По будням')),
                DropdownMenuItem(value: 'weekends', child: Text('По выходным')),
              ],
              onChanged: (v) => setState(() => _repeatMode = v!),
            ),

            const SizedBox(height: 32),

            // КНОПКА
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _createTask,
                icon: const Icon(Icons.add),
                label: const Text('Создать задание', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
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

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Future<String?> _showAddRewardTypeDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый тип награды'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Например: Минуты игры'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}