// Проверка календарной логики task_repeat.dart без Flutter.
// Запуск: dart run tool/check_repeat_logic.dart
//
// Проверяет, что nextOccurrence()/isTaskActiveToday() согласованы между собой
// на ключевых датах: 31-е в коротких месяцах, обычные дни недели, наборы чисел.

import '../lib/utils/task_repeat.dart';

int _failed = 0;
int _passed = 0;

void check(String name, Object? actual, Object? expected) {
  final a = actual?.toString();
  final e = expected?.toString();
  if (a == e) {
    _passed++;
  } else {
    _failed++;
    print('FAIL: $name\n  ожидалось: $e\n  получено:  $a');
  }
}

DateTime d(int y, int m, int day) => DateTime(y, m, day);

Map<String, dynamic> task({
  String mode = 'custom',
  List<int>? weekdays,
  List<int>? monthDays,
}) =>
    {
      'repeat_mode': mode,
      'repeat_days': weekdays,
      'repeat_month_days': monthDays,
    };

void main() {
  // ── Дни недели ─────────────────────────────────────────────
  // Сегодня среда 2026-11-11 (weekday=3). Задача Пн/Ср/Пт.
  final monWedFri = task(mode: 'custom', weekdays: [1, 3, 5]);
  final wed = d(2026, 11, 11);
  check('ПнСрПт активна в среду', isTaskActiveToday(monWedFri, wed), true);
  // Следующая пятница — 2026-11-13, разница 2 дня.
  check('ПнСрПт следующая пятница', nextOccurrence(monWedFri, wed), d(2026, 11, 13));

  // Четверг 2026-11-12 — не активна, следующая пятница 13-го.
  final thu = d(2026, 11, 12);
  check('ПнСрПт неактивна в четверг', isTaskActiveToday(monWedFri, thu), false);
  check('ПнСрПт в четверг следующая пятница', nextOccurrence(monWedFri, thu), d(2026, 11, 13));

  // Только четверг — создана в четверг, активна.
  final thuOnly = task(mode: 'custom', weekdays: [4]);
  check('Задача на чт активна в чт', isTaskActiveToday(thuOnly, thu), true);
  // И в «Скоро» её быть не должно.
  check('Задача на чт: следующее наступление 19-го', nextOccurrence(thuOnly, thu), d(2026, 11, 19));

  // ── Числа месяца ───────────────────────────────────────────
  final day12 = task(mode: 'custom', monthDays: [12]);
  check('12 числа активна 12-го', isTaskActiveToday(day12, thu), true);
  check('12 числа: следующее наступление 12 декабря', nextOccurrence(day12, thu), d(2026, 12, 12));

  // 13-го — следующее 12-е это следующего месяца.
  final fri13 = d(2026, 11, 13);
  check('12 числа 13-го → 12 декабря', nextOccurrence(day12, fri13), d(2026, 12, 12));

  // ── Смещение на последний день месяца ─────────────────────
  final day31 = task(mode: 'custom', monthDays: [31]);
  // В апреле 31-го нет → 30 апреля.
  final apr1 = d(2026, 4, 1);
  check('31-е в апреле → 30 апреля', nextOccurrence(day31, apr1), d(2026, 4, 30));

  // Февраль невисокосный 2027 → 28 февраля.
  final feb1_2027 = d(2027, 2, 1);
  check('31-е в феврале 2027 → 28 февраля', nextOccurrence(day31, feb1_2027), d(2027, 2, 28));

  // Февраль високосный 2028 → 29 февраля.
  final feb1_2028 = d(2028, 2, 1);
  check('31-е в феврале 2028 → 29 февраля', nextOccurrence(day31, feb1_2028), d(2028, 2, 29));

  // И в этих днях isTaskActiveToday должна давать true.
  check('31-е активно 30 апреля', isTaskActiveToday(day31, d(2026, 4, 30)), true);
  check('31-е активно 28 февраля 2027', isTaskActiveToday(day31, d(2027, 2, 28)), true);
  check('31-е активно 29 февраля 2028', isTaskActiveToday(day31, d(2028, 2, 29)), true);

  // 30-е в феврале тоже съезжает на последний день.
  final day30 = task(mode: 'custom', monthDays: [30]);
  check('30-е в феврале 2027 → 28 февраля', nextOccurrence(day30, feb1_2027), d(2027, 2, 28));

  // ── Объединение дней недели и чисел ───────────────────────
  final both = task(mode: 'custom', weekdays: [1], monthDays: [15]);
  // Понедельник 2026-11-09 → следующий понедельник 16-го? Нет: 15-е раньше.
  check('Пн + 15 → ближайшее 15 ноября', nextOccurrence(both, d(2026, 11, 9)), d(2026, 11, 15));

  // ── Разовая задача ────────────────────────────────────────
  final once = task(mode: 'none');
  check('Разовая не в Скоро', nextOccurrence(once, thu), null);

  // ── Ежедневная / еженедельная ─────────────────────────────
  check('Ежедневная не в Скоро', nextOccurrence(task(mode: 'daily'), thu), null);
  check('Еженедельная не в Скоро', nextOccurrence(task(mode: 'weekly'), thu), null);

  // ── Legacy-режимы ─────────────────────────────────────────
  final weekdaysOnly = task(mode: 'weekdays');
  // Суббота 2026-11-14 → следующий будний день = понедельник 16-го.
  check('Будни: в субботу → понедельник', nextOccurrence(weekdaysOnly, d(2026, 11, 14)), d(2026, 11, 16));

  final weekendsOnly = task(mode: 'weekends');
  // Среда 11-го → ближайшие выходные = суббота 14-го.
  check('Выходные: в среду → суббота', nextOccurrence(weekendsOnly, wed), d(2026, 11, 14));

  // ── Пустой custom ─────────────────────────────────────────
  final emptyCustom = task(mode: 'custom');
  check('Пустой custom не в Скоро', nextOccurrence(emptyCustom, thu), null);

  print('\nИтого: $_passed прошло, $_failed упало');

  if (_failed > 0) {
    throw Exception('Есть упавшие проверки');
  }
}


