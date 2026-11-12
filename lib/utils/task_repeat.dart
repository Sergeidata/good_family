// Общие хелперы повторяемости задач.
//
// Файл намеренно оставлен без Flutter-виджетов (только Dart): логику
// повторения и «активна ли задача сегодня» удобно переиспользовать и
// проверять отдельно от UI. Импорт из foundation нужен только ради
// visibleForTesting у тестовых хелперов.

import 'package:flutter/foundation.dart' show visibleForTesting;

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

// ──────────────────────────────────────
// «Когда наступит» — для блока «Скоро»
// ──────────────────────────────────────

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _addDays(DateTime day, int count) =>
    DateTime(day.year, day.month, day.day + count);

bool _isLastDayOfMonth(DateTime day) => _addDays(day, 1).month != day.month;

/// Отладочные/тестовые хелперы для проверки календарной логики.
/// Используются только тестами и руками — в UI не нужны.
@visibleForTesting
int debugDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

@visibleForTesting
bool debugIsLastDayOfMonth(DateTime day) => _isLastDayOfMonth(day);

/// Разница в днях между двумя календарными датами (без времени).
int _dayDiff(DateTime from, DateTime to) =>
    _dateOnly(to).difference(_dateOnly(from)).inDays;

/// Остаток дней от [now] до [when] (по календарю, не по часам).
@visibleForTesting
int debugDaysUntil(DateTime now, DateTime when) => _dayDiff(now, when);

/// Подходит ли [day] под правило повторения.
///
/// Правило общее для «активна сегодня» и «когда наступит», чтобы обе функции
/// не разъезжались. Учитывает:
/// - дни недели из repeat_days (1=Пн ... 7=Вс);
/// - числа месяца из repeat_month_days; если выбранное число больше, чем
///   дней в этом месяце (31-е в феврале), срабатывает последний день месяца;
/// - legacy-режимы weekdays / weekends.
bool _matchesDay(
  Map<String, dynamic> task,
  DateTime day,
  List<int> monthDays,
  int daysInMonth,
) {
  final mode = repeatModeOf(task);

  if (mode == 'weekdays') {
    return day.weekday >= DateTime.monday && day.weekday <= DateTime.friday;
  }
  if (mode == 'weekends') {
    return day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  }
  if (mode != 'custom') return true;

  if (repeatDaysOf(task).contains(day.weekday)) return true;

  for (final wanted in monthDays) {
    final effective = wanted > daysInMonth ? daysInMonth : wanted;
    if (effective == day.day) return true;
  }
  return false;
}

/// Насколько далеко вперёд ищем наступление (дней).
/// 32-е число месяца не существует, а самый длинный реальный цикл — 31 день,
/// поэтому 60 дней с запасом покрывают любой корректный набор.
const int _kSearchHorizonDays = 60;

/// Следующий день, когда задача снова станет доступной.
///
/// Ищет СТРОГО позже сегодняшнего дня, начиная с завтрашнего: если задача
/// активна сегодня, «скоро» это не про неё (её место в основном списке), а
/// если сегодня ещё и не наступила — следующий раз всё равно будет позже.
///
/// Возвращает null, если подходящего дня нет в пределах [horizonDays]:
/// разовая задача без повторения, некорректный custom-набор без единого дня.
///
/// Считается строго по календарю устройства, без времени сервера, — иначе
/// задачи «на сегодня» пропадали бы до 03:00 МСК из-за UTC в БД.
DateTime? nextOccurrence(
  Map<String, dynamic> task,
  DateTime now, {
  int horizonDays = _kSearchHorizonDays,
}) {
  final mode = repeatModeOf(task);

  // Ежедневные и еженедельные сервер сам переносит на следующий день через
  // next_available_at; локально они «активны сегодня», пока не отработаны.
  if (mode == 'daily' || mode == 'weekly') return null;

  // Разовая задача не повторяется — «наступить позже» она не может.
  if (mode == 'none') return null;

  if (mode == 'custom') {
    if (repeatDaysOf(task).isEmpty && repeatMonthDaysOf(task).isEmpty) {
      return null;
    }
  }

  final start = _dateOnly(now);
  final monthDays = repeatMonthDaysOf(task);

  for (var offset = 1; offset <= horizonDays; offset++) {
    final day = _addDays(start, offset);
    final daysInMonth = DateTime(day.year, day.month + 1, 0).day;

    // 31-е в апреле и подобные случаи: _matchesDay зажимает желаемое число
    // по daysInMonth, поэтому сравнивать нужно именно реальную дату.
    if (!_matchesDay(task, day, monthDays, daysInMonth)) continue;

    return day;
  }

  return null;
}

/// Короткая подпись для блока «Скоро»: «Сегодня» / «Завтра» /
/// «Чт, 13» / «12 числа».
String taskUpcomingLabel(
  Map<String, dynamic> task,
  DateTime now,
) {
  final when = nextOccurrence(task, now);
  if (when == null) {
    return taskRepeatBadgeLabel(task);
  }

  final today = _dateOnly(now);
  final target = _dateOnly(when);
  final diff = _dayDiff(today, target);

  if (diff == 1) return 'Завтра';
  if (diff == 7) return 'Через неделю';

  final monthDays = repeatMonthDaysOf(task);
  final weekdays = repeatDaysOf(task);
  final daysInTargetMonth = DateTime(target.year, target.month + 1, 0).day;

  // Для задачи «по числам» понятнее «12 числа», чем день недели.
  if (repeatModeOf(task) == 'custom' && weekdays.isEmpty && monthDays.isNotEmpty) {
    final wanted = monthDays.firstWhere(
      (d) => (d > daysInTargetMonth ? daysInTargetMonth : d) == target.day,
      orElse: () => target.day,
    );
    return '$wanted числа';
  }

  return '${kWeekdayLabels[target.weekday - 1]}, ${target.day}';
}

