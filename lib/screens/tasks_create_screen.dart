import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';

class TasksCreateScreen extends StatefulWidget {
  const TasksCreateScreen({super.key});

  @override
  State<TasksCreateScreen> createState() =>
      _TasksCreateScreenState();
}

class _TasksCreateScreenState
    extends State<TasksCreateScreen> {
  final _titleController =
      TextEditingController();
  final _starsController =
      TextEditingController(text: '10');

  String _familyId = '';
  String _userName = '';
  

  List<dynamic> _children = [];

  String? _selectedChild;
  bool _allChildren = false;
  String _repeatMode = 'none';

  int _selectedStars = 10;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final family = await FamilyStorage.loadFamily();

    _familyId = family['family_id'] ?? '';
    _userName = family['user_name'] ?? '';
    

    final members = await ApiService.getMembers(_familyId);

    _children = (members?['members'] ?? [])
        .where((m) => m['role'] == 'child')
        .toList();

    if (_children.isNotEmpty) {
      _selectedChild ??=
          _children.first['user_name'];
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _setStars(int stars) {
    setState(() {
      _selectedStars = stars;
      _starsController.text = stars.toString();
    });
  }

  Future<void> _createTask() async {
    final title = _titleController.text.trim();
    final stars = int.tryParse(
          _starsController.text.trim(),
        ) ??
        0;

    if (_children.isEmpty) {
      _showSnack('Сначала добавьте ребёнка в семью');
      return;
    }

    if (title.isEmpty) {
      _showSnack('Введите название задания');
      return;
    }

    if (stars <= 0) {
      _showSnack('Введите количество звёзд');
      return;
    }

    if (!_allChildren && _selectedChild == null) {
      _showSnack('Выберите ребёнка');
      return;
    }

    try {
      if (_allChildren) {
        for (final child in _children) {
          await ApiService.createTask(
            familyId: _familyId,
            title: title,
            stars: stars,
            createdBy: _userName,
            assignedTo: child['user_name'],
            repeatMode: _repeatMode,
          );
        }
      } else {
        await ApiService.createTask(
          familyId: _familyId,
          title: title,
          stars: stars,
          createdBy: _userName,
          assignedTo: _selectedChild!,
          repeatMode: _repeatMode,
        );
      }

      _showSnack('Задание создано');

      _titleController.clear();
      _setStars(10);

      setState(() {
        _repeatMode = 'none';
        _allChildren = false;
        _selectedChild = _children.isNotEmpty
            ? _children.first['user_name']
            : null;
      });
    } catch (_) {
      _showSnack('Не удалось создать задание');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

 

  

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _repeatChip(String mode, String label) {
    final selected = _repeatMode == mode;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _repeatMode = mode;
        });
      },
      selectedColor: Colors.blue.shade100,
      labelStyle: TextStyle(
        color: selected ? Colors.blue.shade900 : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _childChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.green.shade100,
      labelStyle: TextStyle(
        color: selected ? Colors.green.shade900 : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать задание'),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           _sectionCard(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade400,
              Colors.orange.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Новое хорошее дело',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Задайте количество звездочек за выполнение и выберите кому назначить задание.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),

            const SizedBox(height: 16),

            _sectionTitle('Название'),
            _sectionCard(
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Например: Помыть посуду',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _sectionTitle('Для кого'),
            _sectionCard(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _childChip(
                    label: '👨‍👩‍👧 Всем детям',
                    selected: _allChildren,
                    onTap: () {
                      setState(() {
                        _allChildren = true;
                        _selectedChild = null;
                      });
                    },
                  ),
                  ..._children.map((child) {
                    final name = child['user_name'] ?? '';
                    final avatar = child['avatar'] ?? '👦';
                    final selected =
                        !_allChildren && _selectedChild == name;

                    return _childChip(
                      label: '$avatar $name',
                      selected: selected,
                      onTap: () {
                        setState(() {
                          _allChildren = false;
                          _selectedChild = name;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _sectionTitle(
              'Звёздочки',
              subtitle:
                  'Можно выбрать готовый вариант или ввести своё число',
            ),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _starPresetChip(5, '⭐ Очень легко'),
                      _starPresetChip(10, '⭐⭐ Легко'),
                      _starPresetChip(20, '⭐⭐⭐ Обычно'),
                      _starPresetChip(40, '⭐⭐⭐⭐ Сложно'),
                      _starPresetChip(80, '⭐⭐⭐⭐⭐ Очень сложно'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _starsController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        _selectedStars = parsed;
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Введите своё количество звёзд',
                      prefixIcon: const Icon(Icons.star_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _sectionTitle('Повторение'),
            _sectionCard(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _repeatChip('none', 'Разовое'),
                  _repeatChip('daily', 'Ежедневно'),
                  _repeatChip('weekly', 'Еженедельно'),
                  _repeatChip('weekdays', 'По будням'),
                  _repeatChip('weekends', 'По выходным'),
                ],
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _createTask,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Создать задание',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 18),
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

  Widget _starPresetChip(int stars, String label) {
    final selected = _selectedStars == stars;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        _setStars(stars);
      },
      selectedColor: Colors.amber.shade100,
      labelStyle: TextStyle(
        color: selected ? Colors.brown.shade900 : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}