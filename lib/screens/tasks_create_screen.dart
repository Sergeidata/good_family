
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/loading_dots.dart';
import '../widgets/error_state.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';
import '../utils/app_utils.dart';
import '../utils/task_repeat.dart';

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

  // Мультивыбор дней для режима 'custom' (1=Пн..7=Вс / 1..31).
  final Set<int> _weekdayDays = {};
  final Set<int> _monthDays = {};
  bool _weekdayPickerOpen = false;
  bool _monthPickerOpen = false;

  int _selectedStars = 10;
  bool _loading = true;
  String? _error;

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
    setState(() {
      _loading = true;
      _error = null;
    });

    final family = await FamilyStorage.loadFamily();

    _familyId = family['family_id'] ?? '';
    _userName = family['user_name'] ?? '';

    final members = await ApiService.getMembers(_familyId);

    if (!mounted) return;

    if (members == null) {
      setState(() {
        _loading = false;
        _error = 'Нет связи с сервером';
      });
      return;
    }

    _children = (members['members'] ?? [])
        .where((m) => m['role'] == 'child')
        .toList();

    if (_children.isNotEmpty) {
      _selectedChild ??= _children.first['user_name'];
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _error = null;
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

    if (_repeatMode == 'custom' &&
        _weekdayDays.isEmpty &&
        _monthDays.isEmpty) {
      _showSnack('Выберите хотя бы один день');
      return;
    }

    final repeatDays =
        _repeatMode == 'custom' ? (_weekdayDays.toList()..sort()) : null;
    final repeatMonthDays =
        _repeatMode == 'custom' ? (_monthDays.toList()..sort()) : null;

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
            repeatDays: repeatDays,
            repeatMonthDays: repeatMonthDays,
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
          repeatDays: repeatDays,
          repeatMonthDays: repeatMonthDays,
        );
      }

      showSuccessSnackBar(context, "Задание создано");

      _titleController.clear();
      _setStars(10);

      setState(() {
        _repeatMode = 'none';
        _weekdayDays.clear();
        _monthDays.clear();
        _weekdayPickerOpen = false;
        _monthPickerOpen = false;
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
                    Uri.encodeFull('http://89.108.66.36$avatar'),
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
    IconData icon, {
    bool? selected,
    String? suffix,
    VoidCallback? onTap,
  }) {
    final isSelected = selected ?? (_repeatMode == value);

    return GestureDetector(
      onTap: onTap ?? () => _selectRepeatMode(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.shade50
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.blue.shade300
                : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.blue
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 7),
            Text(
              suffix == null ? label : '$label · $suffix',
              style: TextStyle(
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectRepeatMode(String mode) {
    setState(() {
      _repeatMode = mode;
      if (mode != 'custom') {
        _weekdayPickerOpen = false;
        _monthPickerOpen = false;
      }
    });
  }

  void _toggleWeekdayPicker() {
    setState(() {
      _repeatMode = 'custom';
      _weekdayPickerOpen = !_weekdayPickerOpen;
    });
  }

  void _toggleMonthPicker() {
    setState(() {
      _repeatMode = 'custom';
      _monthPickerOpen = !_monthPickerOpen;
    });
  }

  void _toggleWeekdayDay(int day) {
    setState(() {
      _repeatMode = 'custom';
      if (!_weekdayDays.add(day)) {
        _weekdayDays.remove(day);
      }
    });
  }

  void _toggleMonthDay(int day) {
    setState(() {
      _repeatMode = 'custom';
      if (!_monthDays.add(day)) {
        _monthDays.remove(day);
      }
    });
  }

  void _applyWeekdayPreset(Set<int> days) {
    setState(() {
      _repeatMode = 'custom';
      if (_weekdayDays.containsAll(days)) {
        _weekdayDays.removeAll(days);
      } else {
        _weekdayDays.addAll(days);
      }
    });
  }

  int get _maxMonthDay =>
      _monthDays.isEmpty ? 0 : _monthDays.reduce((a, b) => a > b ? a : b);

  Widget _weekdayPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (index) {
        final day = index + 1;
        return SizedBox(
          width: 42,
          height: 42,
          child: _dayCircle(
            label: kWeekdayLabels[index],
            selected: _weekdayDays.contains(day),
            onTap: () => _toggleWeekdayDay(day),
          ),
        );
      }),
    );
  }

  Widget _monthDayPicker() {
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: List.generate(31, (index) {
        final day = index + 1;
        return _dayCircle(
          label: '$day',
          selected: _monthDays.contains(day),
          onTap: () => _toggleMonthDay(day),
          fitCell: true,
        );
      }),
    );
  }

  Widget _dayCircle({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool fitCell = false,
  }) {
    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: fitCell ? null : 38,
      height: fitCell ? null : 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.green.shade600 : Colors.grey.shade50,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.green.shade600 : Colors.grey.shade200,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Colors.white : Colors.grey.shade800,
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: fitCell ? circle : Center(child: circle),
    );
  }

  Widget _weekdayPreset(String label, Set<int> days) {
    return TextButton(
      onPressed: () => _applyWeekdayPreset(days),
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 34),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _shortMonthHint() {
    final text = _maxMonthDay == 31
        ? '31-го нет в феврале и апреле — задание переедет на последний день месяца'
        : 'Этого дня нет в коротких месяцах — задание переедет на последний день месяца';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekdayPickerBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Дни недели',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            _weekdayPreset('Пн–Пт', const {1, 2, 3, 4, 5}),
            _weekdayPreset('Сб–Вс', const {6, 7}),
          ],
        ),
        const SizedBox(height: 8),
        _weekdayPicker(),
      ],
    );
  }

  Widget _monthPickerBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Дни месяца',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        _monthDayPicker(),
        if (_maxMonthDay > 28) ...[
          const SizedBox(height: 10),
          _shortMonthHint(),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: LoadingDots(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Новое задание')),
        body: ErrorState(
          message: _error!,
          onRetry: _loadData,
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
                textCapitalization: TextCapitalization.sentences,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
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
                        'custom',
                        'По дням недели',
                        Icons.calendar_view_week,
                        selected: _repeatMode == 'custom' &&
                            (_weekdayPickerOpen ||
                                _weekdayDays.isNotEmpty),
                        suffix: _weekdayDays.isEmpty
                            ? null
                            : '${_weekdayDays.length}',
                        onTap: _toggleWeekdayPicker,
                      ),
                      _repeatChip(
                        'custom',
                        'По дням месяца',
                        Icons.calendar_month,
                        selected: _repeatMode == 'custom' &&
                            (_monthPickerOpen || _monthDays.isNotEmpty),
                        suffix: _monthDays.isEmpty
                            ? null
                            : '${_monthDays.length}',
                        onTap: _toggleMonthPicker,
                      ),
                      _repeatChip(
                        'weekly',
                        'Еженедельно',
                        Icons.date_range,
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_weekdayPickerOpen) ...[
                          const SizedBox(height: 16),
                          _weekdayPickerBlock(),
                        ],
                        if (_monthPickerOpen) ...[
                          const SizedBox(height: 16),
                          _monthPickerBlock(),
                        ],
                      ],
                    ),
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
