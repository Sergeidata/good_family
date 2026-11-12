// Общие хелперы повторяемости задач.
//
// Файл намеренно оставлен без Flutter-импортов (только Dart): логику
// повторения и «активна ли задача сегодня» удобно переиспользовать и
// проверять отдельно от UI.

/// Короткие названия дней недели: индекс 0 → Пн, ... 6 → Вс.
const List<String> kWeekdayLabels = [
  'Пн',
  'Вт',
  'Ср',
  'Чт',
  'Пт',
  'Сб',
  'Вс',
];

/// Режим повторения задачи: none / daily / weekdays / weekends / weekly / custom.
String repeatModeOf(Map<String, dynamic> task) {
  final raw = task['repeat_mode'];
  if (raw == null) return 'none';
  final mode = raw.toString().trim();
  return mode.isEmpty ? 'none' : mode;
}

int? _toInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString().trim());
}

/// Терпимо читает список чисел (int/num/String) и оставляет значения в [min]..[max].
List<int> _readDays(dynamic raw, int min, int max) {
  if (raw is! List) return const [];
  final result = <int>{};
  for (final item in raw) {
    final value = _toInt(item);
    if (value != null && value >= min && value <= max) {
      result.add(value);
    }
  }
  final list = result.toList()..sort();
  return list;
}

/// Дни недели повторения: 1=Пн ... 7=Вс (как DateTime.weekday).
List<int> repeatDaysOf(Map<String, dynamic> task) =>
    _readDays(task['repeat_days'], 1, 7);

/// Числа месяца повторения: 1..31.
List<int> repeatMonthDaysOf(Map<String, dynamic> task) =>
    _readDays(task['repeat_month_days'], 1, 31);

String _weekdaysLabel(List<int> days) =>
    days.map((d) => kWeekdayLabels[d - 1]).join(', ');

/// Полная текстовая метка повторения (для списков и диалогов).
String taskRepeatLabel(Map<String, dynamic> task) {
  final mode = repeatModeOf(task);

  switch (mode) {
    case 'daily':
      return 'Ежедневно';
    case 'weekly':
      return 'Еженедельно';
    case 'weekdays':
      return 'По будням';
    case 'weekends':
      return 'По выходным';
    case 'custom':
      final weekdays = repeatDaysOf(task);
      final monthDays = repeatMonthDaysOf(task);
      if (weekdays.isEmpty && monthDays.isEmpty) return 'По дням';
      if (weekdays.isNotEmpty && monthDays.isNotEmpty) {
        return '${_weekdaysLabel(weekdays)} и ${monthDays.join(', ')} числа';
      }
      if (weekdays.isNotEmpty) return _weekdaysLabel(weekdays);
      return '${monthDays.join(', ')} числа';
  }

  return 'Разовое';
}

/// Компактная метка повторения для бейджа в списке задач.
String taskRepeatBadgeLabel(Map<String, dynamic> task) {
  final mode = repeatModeOf(task);
  if (mode != 'custom') return taskRepeatLabel(task);

  final weekdays = repeatDaysOf(task);
  final monthDays = repeatMonthDaysOf(task);

  if (weekdays.isEmpty && monthDays.isEmpty) return 'По дням';

  final parts = <String>[];
  if (weekdays.isNotEmpty) {
    parts.add(weekdays.map((d) => kWeekdayLabels[d - 1]).join(' • '));
  }
  if (monthDays.isNotEmpty) {
    parts.add('${monthDays.join(' • ')} числа');
  }
  return parts.join(' • ');
}

/// Активна ли задача сегодня с учётом режима повторения.
///
/// - none — разовая задача, активна всегда (сервер отдаёт только доступные);
/// - daily — каждый день;
/// - weekly — текущее поведение: не фильтруем по дню, решает сервер
///   (next_available_at);
/// - weekdays / weekends — legacy-режимы, поддержаны для старых задач;
/// - custom — день недели из repeat_days ИЛИ число месяца из
///   repeat_month_days; если выбранное число больше числа дней в месяце,
///   срабатывает последний день месяца.
bool isTaskActiveToday(Map<String, dynamic> task, DateTime now) {
  final mode = repeatModeOf(task);

  switch (mode) {
    case 'daily':
    case 'weekly':
      return true;
    case 'weekdays':
      return now.weekday >= DateTime.monday &&
          now.weekday <= DateTime.friday;
    case 'weekends':
      return now.weekday == DateTime.saturday ||
          now.weekday == DateTime.sunday;
    case 'custom':
      if (repeatDaysOf(task).contains(now.weekday)) {
        return true;
      }

      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      for (final day in repeatMonthDaysOf(task)) {
        final effectiveDay = day > daysInMonth ? daysInMonth : day;
        if (effectiveDay == now.day) return true;
      }
      return false;
  }

  return true;
}
