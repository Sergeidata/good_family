
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';
import '../utils/app_utils.dart';

class TasksCreateScreen extends StatefulWidget {
  const TasksCreateScreen({super.key});

  @override
  State<TasksCreateScreen> createState() => _TasksCreateScreenState();
}

class _TasksCreateScreenState extends State<TasksCreateScreen> {
  final _titleController = TextEditingController();
  final _starsController = TextEditingController(text: '10');

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
      _selectedChild ??= _children.first['user_name'];
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
    final stars =
        int.tryParse(_starsController.text.trim()) ?? 0;

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

      showSuccessSnackBar(context, "Задание создано");

      _titleController.clear();
      _setStars(10);

      setState(() {
        _repeatMode = 'none';
        _allChildren = false;
        _selectedChild =
            _children.isNotEmpty
                ? _children.first['user_name']
                : null;
      });
    } catch (_) {
      _showSnack('Не удалось создать задание');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _sectionTitle(
    String title,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _starPreset(
    int stars,
    String label,
  ) {
    final selected = _selectedStars == stars;

    return GestureDetector(
      onTap: () => _setStars(stars),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.orange.shade50
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Colors.orange.shade300
                : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$stars ⭐',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.deepOrange
                    : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _childChoice({
  required String name,
  required String avatar,
  required bool selected,
  required VoidCallback onTap,
  bool isImage = false,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          isImage
              ? CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    Uri.encodeFull('http://159.194.219.146:8000$avatar'),
                  ),
                )
              : CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.green.shade50,
                  child: Text(avatar, style: const TextStyle(fontSize: 20)),
                ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (selected) const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    ),
  );
}

  Widget _repeatChip(
    String value,
    String label,
    IconData icon,
  ) {
    final selected = _repeatMode == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _repeatMode = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blue.shade50
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Colors.blue.shade300
                : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.blue
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новое задание'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          110,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            // ─────────────────────────
            // НАЗВАНИЕ
            // ─────────────────────────

            _sectionTitle(
              'Что нужно сделать?',
              Icons.edit_rounded,
              Colors.blue,
            ),

            const SizedBox(height: 12),

            _sectionCard(
              child: TextField(
                controller: _titleController,
                textInputAction:
                    TextInputAction.done,
                decoration: InputDecoration(
                  hintText:
                      'Например: Помыть посуду',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: const Icon(
                    Icons.check_circle_outline,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────
            // ДЛЯ КОГО
            // ─────────────────────────

            _sectionTitle(
              'Для кого?',
              Icons.people_alt_outlined,
              Colors.green,
            ),

            const SizedBox(height: 12),

            _sectionCard(
              child: Column(
                children: [
                  _childChoice(
                    name: 'Всем детям',
                    avatar: '👨‍👩‍👧‍👦',
                    selected: _allChildren,
                    onTap: () {
                      setState(() {
                        _allChildren = true;
                        _selectedChild = null;
                      });
                    },
                  ),

                  ..._children.map(
  (child) => _childChoice(
    name: child['user_name'] ?? 'Ребёнок',
    avatar: child['avatar'] ?? '👦',
    isImage: (child['avatar'] ?? '').toString().startsWith('/uploads/'),
    selected: !_allChildren && _selectedChild == child['user_name'],
    onTap: () {
      setState(() {
        _allChildren = false;
        _selectedChild = child['user_name'];
      });
    },
  ),
),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────
            // НАГРАДА
            // ─────────────────────────

            _sectionTitle(
              'Награда',
              Icons.stars_rounded,
              Colors.deepOrange,
            ),

            const SizedBox(height: 12),

            _sectionCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Сколько монет дать? Введите значение',
                          style: TextStyle(
                            fontSize: 15,
                            color:
                                Colors.grey.shade700,
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller:
                              _starsController,
                          keyboardType:
                              TextInputType.number,
                          textAlign:
                              TextAlign.center,
                          onChanged: (value) {
                            final stars =
                                int.tryParse(value);

                            if (stars != null &&
                                stars > 0) {
                              setState(() {
                                _selectedStars =
                                    stars;
                              });
                            }
                          },
                          decoration:
                              InputDecoration(
                            suffixIcon: Padding(
  padding: const EdgeInsets.only(right: 8),
  child: Stack(
    alignment: Alignment.center,
    children: [
      Icon(Icons.stars, color: Colors.amber, size: 28)
    ],
  ),
),
                            filled: true,
                            fillColor:
                                Colors.orange.shade50,
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      16),
                              borderSide:
                                  BorderSide.none,
                            ),
                          ),
                          style:
                              const TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Быстрый выбор',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _starPreset(5, 'Легко'),
                      _starPreset(10, 'Обычно'),
                      _starPreset(20, 'Средне'),
                      _starPreset(40, 'Сложно'),
                      _starPreset(
                        80,
                        'Очень сложно',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────
            // ПОВТОРЕНИЕ
            // ─────────────────────────

            _sectionTitle(
              'Повторение',
              Icons.repeat_rounded,
              Colors.blue,
            ),

            const SizedBox(height: 12),

            _sectionCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _repeatChip(
                    'none',
                    'Разовое',
                    Icons.radio_button_checked,
                  ),
                  _repeatChip(
                    'daily',
                    'Ежедневно',
                    Icons.repeat,
                  ),
                  _repeatChip(
                    'weekdays',
                    'Будни',
                    Icons.work_outline,
                  ),
                  _repeatChip(
                    'weekends',
                    'Выходные',
                    Icons.weekend_outlined,
                  ),
                  _repeatChip(
                    'weekly',
                    'Еженедельно',
                    Icons.calendar_month,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ─────────────────────────
            // СОЗДАТЬ
            // ─────────────────────────

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _createTask,
                icon: const Icon(
                  Icons.add_task_rounded,
                ),
                label: const Text(
                  'Создать задание',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
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
              builder: (_) =>
                  MainNavigationScreen(
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
