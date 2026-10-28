import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/session_storage.dart';
import '../services/usage_stats_helper.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../widgets/loading_dots.dart';
import '../widgets/error_state.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';


class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() =>
      _StatsScreenState();
}

class _StatsScreenState
    extends State<StatsScreen> {
  List<Map<String, dynamic>> _sessions = [];

  String _selectedPeriod = "Сегодня";

  List<MapEntry<String, int>> _topApps = [];

  bool _loadingApps = false;

  bool _appsError = false;


//   // ВРЕМЕННО ДЛЯ ДЕМО — УДАЛИТЬ ПОСЛЕ ЗАПИСИ
// bool _demoMode = true;

// List<Map<String, dynamic>> get _demoSessions => [
//   {"date": "2026-08-01", "duration_seconds": 5400, "social_seconds": 800, "apps": {}},
//   {"date": "2026-08-02", "duration_seconds": 7200, "social_seconds": 1200, "apps": {}},
//   {"date": "2026-08-03", "duration_seconds": 8900, "social_seconds": 1500, "apps": {}},
//   {"date": "2026-08-04", "duration_seconds": 6700, "social_seconds": 1100, "apps": {}},
//   {"date": "2026-08-05", "duration_seconds": 10300, "social_seconds": 1900, "apps": {}},
//   {"date": "2026-08-06", "duration_seconds": 9100, "social_seconds": 1400, "apps": {}},
//   {"date": "2026-08-07", "duration_seconds": 11800, "social_seconds": 2200, "apps": {}},
//   {"date": "2026-08-08", "duration_seconds": 7600, "social_seconds": 1000, "apps": {}},
//   {"date": "2026-08-09", "duration_seconds": 12400, "social_seconds": 2400, "apps": {}},
//   {"date": "2026-08-10", "duration_seconds": 6800, "social_seconds": 950, "apps": {}},
//   {"date": "2026-08-11", "duration_seconds": 8400, "social_seconds": 1300, "apps": {}},
//   {"date": "2026-08-12", "duration_seconds": 9200, "social_seconds": 1700, "apps": {}},
//   {"date": "2026-08-13", "duration_seconds": 7100, "social_seconds": 1050, "apps": {}},
//   {"date": "2026-08-14", "duration_seconds": 10600, "social_seconds": 2000, "apps": {}},
//   {"date": "2026-08-15", "duration_seconds": 13200, "social_seconds": 2600, "apps": {}},
//   {"date": "2026-08-16", "duration_seconds": 7800, "social_seconds": 1150, "apps": {}},
//   {"date": "2026-08-17", "duration_seconds": 9800, "social_seconds": 1400, "apps": {}},
//   {"date": "2026-08-18", "duration_seconds": 11200, "social_seconds": 2100, "apps": {}},
//   {"date": "2026-08-19", "duration_seconds": 8700, "social_seconds": 1600, "apps": {}},
//   {"date": "2026-08-20", "duration_seconds": 12400, "social_seconds": 2400, "apps": {}},
//   {"date": "2026-08-21", "duration_seconds": 6400, "social_seconds": 900, "apps": {}},
// ];

  @override
  void initState() {
    super.initState();

    initializeDateFormatting('ru');

    _loadWeekStats();
    _refreshApps();
  }

  Future<void> _loadWeekStats() async {
    final sessions =
        await SessionStorage.loadSessions();

    setState(() {
      _sessions = sessions;
    });
  }

//   Future<void> _loadWeekStats() async {
//   if (_demoMode) {
//     setState(() {
//       _sessions = _demoSessions;
//     });
//     return;
//   }

//   final sessions = await SessionStorage.loadSessions();
//   setState(() {
//     _sessions = sessions;
//   });
// }

  Future<void> _refreshApps() async {
    setState(() {
      _loadingApps = true;
      _appsError = false;
    });

    try {
      Map<String, int> result = {};

      if (_selectedPeriod == "Сегодня") {
        result = await UsageStatsHelper
            .getScreenTimeToday();
      } else if (_selectedPeriod ==
          "Вчера") {
        result = await UsageStatsHelper
            .getScreenTimeYesterday();
      } else {
        result = await UsageStatsHelper
            .getScreenTimeWeek();
      }

      final sorted = result.entries.toList()
        ..sort(
          (a, b) => b.value.compareTo(a.value),
        );

      setState(() {
        _topApps = sorted.take(10).toList();
      });
    } catch (e) {
      debugPrint("APPS ERROR: $e");
      _appsError = true;
    }

    setState(() {
      _loadingApps = false;
    });
  }

  String formatHoursMinutes(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes =
        (seconds % 3600) ~/ 60;

    return "$hoursч $minutesмин";
  }

  String extractAppName(
    String packageName,
  ) {
    final parts = packageName.split(".");

    if (parts.isEmpty) {
      return packageName;
    }

    String name = parts.last;

    name = name.replaceAll(
      "_",
      " ",
    );

    if (name == "android") {
      if (parts.length >= 2) {
        name = parts[parts.length - 2];
      }
    }

    return name.isNotEmpty
        ? name[0].toUpperCase() +
            name.substring(1)
        : packageName;
  }

  Future<Map<String, int>> _calculateWeekTotals() async {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final Map<String, int> totals = {};

  final daysPassed = now.weekday;

  for (int i = 0; i < daysPassed; i++) {
    final day = monday.add(Duration(days: i));
    final key = DateFormat('yyyy-MM-dd').format(day);
    totals[key] = 0;
  }

  // ВРЕМЕННО ДЛЯ ДЕМО
  // if (_demoMode) {
  //   for (final session in _sessions) {
  //     final date = session["date"];
  //     if (totals.containsKey(date)) {
  //       totals[date] = (totals[date]! + ((session["duration_seconds"] as int?) ?? 0));
  //     }
  //   }
  //   return totals;
  // }

  final today = DateFormat('yyyy-MM-dd').format(now);

  for (final date in totals.keys) {
    if (date == today) {
      totals[date] = await SessionStorage.getTodayTotal();
    } else {
      for (final session in _sessions) {
        if (session["date"] == date) {
          totals[date] = (totals[date] ?? 0) + ((session["duration_seconds"] as int?) ?? 0);
        }
      }
    }
  }

  return totals;
}

 Widget _buildWeekTab() {
  return FutureBuilder<Map<String, int>>(
    future: _calculateWeekTotals(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorState(
          message: 'Нет связи с сервером',
          onRetry: () => setState(() {}),
        );
      }

      if (!snapshot.hasData) {
        return const Center(
          child: LoadingDots(),
        );
      }

      final totals = snapshot.data!;
      final weekSeconds = totals.values.fold(
        0,
        (sum, item) => sum + item,
      );

      if (weekSeconds == 0) {
        return const EmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'Нет данных за неделю',
          subtitle: 'Как только появится статистика, здесь будет график',
        );
      }

      final now = DateTime.now();

      final passedDays = now.weekday;

      final averageSeconds = passedDays > 0
          ? weekSeconds ~/ passedDays
          : weekSeconds;

      final sortedDays = totals.keys.toList()..sort();

      const weekdays = [
        "Пн",
        "Вт",
        "Ср",
        "Чт",
        "Пт",
        "Сб",
        "Вс",
      ];

      return ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          30,
        ),
        children: [
          // Главная карточка недели
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade400,
                  Colors.blue.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.calendar_view_week_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Среднее за неделю",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        formatHoursMinutes(
                          averageSeconds,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "$passedDays из 7 дней",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            "По дням",
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ...sortedDays.map((date) {
            final dayObj = DateTime.parse(date);
            final weekday =
                weekdays[dayObj.weekday - 1];
            final shortDate =
                DateFormat('dd.MM').format(dayObj);
            final seconds = totals[date] ?? 0;

            return Container(
              margin: const EdgeInsets.only(
                bottom: 10,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blueGrey.shade100,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        weekday,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Text(
                      shortDate,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Text(
                    formatHoursMinutes(seconds),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    },
  );
}

  Widget _buildMonthTab() {
  final sessions = _sessions;

  final now = DateTime.now();

  final firstDay = DateTime(
    now.year,
    now.month,
    1,
  );

  final daysPassed = now.day;

  final monthTotals = <String, int>{};

  for (int i = 0; i < daysPassed; i++) {
    final day = firstDay.add(
      Duration(days: i),
    );

    final key = DateFormat(
      "yyyy-MM-dd",
    ).format(day);

    monthTotals[key] = 0;
  }

  for (final session in sessions) {
    final date = session["date"];
    final seconds =
        session["duration_seconds"] ?? 0;

    if (monthTotals.containsKey(date)) {
      monthTotals[date] =
          monthTotals[date]! +
              (seconds as int);
    }
  }

  final totalSeconds =
      monthTotals.values.fold(
    0,
    (a, b) => a + b,
  );

  final averageSeconds = daysPassed > 0
      ? totalSeconds ~/ daysPassed
      : totalSeconds;

  final monthName = DateFormat(
    'LLLL',
    'ru',
  ).format(now);

  const weekdays = [
    "Пн",
    "Вт",
    "Ср",
    "Чт",
    "Пт",
    "Сб",
    "Вс",
  ];

  return ListView(
    padding: const EdgeInsets.fromLTRB(
      20,
      20,
      20,
      30,
    ),
    children: [
      // Главная карточка месяца
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade400,
              Colors.green.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    "Среднее за $monthName",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    formatHoursMinutes(
                      averageSeconds,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "$daysPassed дней прошло",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

      const Text(
        "По дням",
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 12),

      ...monthTotals.keys.map((date) {
        final seconds =
            monthTotals[date] ?? 0;

        final day = DateTime.parse(date);

        final weekday =
            weekdays[day.weekday - 1];

        final formattedDate =
            DateFormat("dd.MM").format(day);

        return Container(
          margin: const EdgeInsets.only(
            bottom: 10,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: Colors.green.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    weekday,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Text(
                formatHoursMinutes(seconds),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

  Widget _buildAppsTab() {
  return Column(
    children: [
      // Выбор периода
      Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          12,
        ),
        child: DropdownButtonFormField<String>(
          initialValue: _selectedPeriod,
          decoration: InputDecoration(
            labelText: "Период",
            prefixIcon: const Icon(
              Icons.calendar_today_rounded,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(20),
              borderSide: BorderSide(
                color: Colors.blueGrey.shade100,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(20),
              borderSide: BorderSide(
                color: Colors.blueGrey.shade100,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(20),
              borderSide: BorderSide(
                color: Colors.orange.shade300,
                width: 1.5,
              ),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: "Сегодня",
              child: Text("Сегодня"),
            ),
            DropdownMenuItem(
              value: "Вчера",
              child: Text("Вчера"),
            ),
            DropdownMenuItem(
              value: "7 дней",
              child: Text("7 дней"),
            ),
          ],
          onChanged: (value) async {
            if (value == null) return;

            setState(() {
              _selectedPeriod = value;
            });

            await _refreshApps();
          },
        ),
      ),

      Expanded(
        child: _loadingApps
            ? const Center(
                child: LoadingDots(),
              )
            : _appsError
                ? ErrorState(
                    message: 'Нет связи с сервером',
                    onRetry: _refreshApps,
                  )
                : _topApps.isEmpty
                    ? const EmptyState(
                        icon: Icons.phone_android_rounded,
                        title: 'Нет данных',
                        subtitle: 'Статистика по приложениям появится позже',
                      )
                    : ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      30,
                    ),
                    itemCount: _topApps.length,
                    itemBuilder:
                        (context, index) {
                      final app =
                          _topApps[index];

                      final minutes =
                          app.value ~/ 60;

                      return Container(
                        margin:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                          border: Border.all(
                            color:
                                Colors.orange.shade100,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(
                                0.035,
                              ),
                              blurRadius: 10,
                              offset:
                                  const Offset(
                                0,
                                4,
                              ),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.orange.shade50,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  15,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: TextStyle(
                                    color: Colors
                                        .orange.shade700,
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    extractAppName(
                                      app.key,
                                    ),
                                    style:
                                        const TextStyle(
                                      fontSize: 17,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    app.key,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors
                                          .grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.orange.shade50,
                                borderRadius:
                                    BorderRadius.circular(
                                  16,
                                ),
                              ),
                              child: Text(
                                "$minutes мин",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.bold,
                                  color: Colors
                                      .orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
    length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Статистика",
          ),
          bottom: const TabBar(
            tabs: [
              Tab(
                text: "Дни недели",
              ),
              Tab(text: "Месяц"),  
              Tab(
                text: "Топ-10",
              ),

            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildWeekTab(),
            _buildMonthTab(),
            _buildAppsTab(),
            
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
      ),
    );
  }
}