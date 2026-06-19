import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/session_storage.dart';
import '../services/usage_stats_helper.dart';
import 'package:intl/date_symbol_data_local.dart';

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

  Future<void> _refreshApps() async {
    setState(() {
      _loadingApps = true;
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

    final daysPassed =
    now.weekday;

    for (int i = 0; i < daysPassed; i++) {
      final day = monday.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      totals[key] = 0;
    }

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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
      
      final totals = snapshot.data!;
      final now = DateTime.now();

      final passedDays =
          now.weekday; // Пн=1 ... Вс=7

      final weekSeconds =
          totals.values.fold(
            0,
            (sum, item) => sum + item,
          );

      final averageSeconds =
          passedDays > 0
              ? weekSeconds ~/ passedDays
              : weekSeconds;
        final sortedDays = totals.keys.toList()..sort();
        const weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    elevation: 6,
                    color: const Color(0xFFE8F1FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.calendar_view_week,
                            size: 42,
                            color: Colors.blue,
                          ),

                          const SizedBox(height: 10),

                          Text(
                            "Среднее за неделю",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            formatHoursMinutes(
                              averageSeconds,
                            ),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            "$passedDays из 7 дней",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ...sortedDays.map((date) {
                    final dayObj = DateTime.parse(date);
                    final weekday = weekdays[dayObj.weekday - 1];
                    final shortDate = DateFormat('dd.MM').format(dayObj);
                    final seconds = totals[date] ?? 0;
                    return Card(
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  ),
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor:
          Colors.blue.shade50,
      child: Text(
        weekday,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    title: Text(
      shortDate,
      style: const TextStyle(
        fontSize: 18,
      ),
    ),
    trailing: Text(
      formatHoursMinutes(seconds),
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
);
                  }),
                ],
              ),
            ),
            
          ],
        );
      },
    );
  }

  Widget _buildMonthTab() {

    final sessions =
        _sessions;

    final now =
        DateTime.now();

    final firstDay =
        DateTime(
          now.year,
          now.month,
          1,
        );

    final daysPassed =
        now.day;

    final monthTotals =
        <String, int>{};

    for (
      int i = 0;
      i < daysPassed;
      i++
    ) {

      final day =
          firstDay.add(
        Duration(
          days: i,
        ),
      );

      final key =
          DateFormat(
        "yyyy-MM-dd",
      ).format(day);

      monthTotals[key] = 0;
    }

    for (final session in sessions) {

      final date =
          session["date"];

      final seconds =
          session["duration_seconds"] ?? 0;

      if (
          monthTotals.containsKey(
            date,
          )
      ) {

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

    final averageSeconds =
        daysPassed > 0
            ? totalSeconds ~/ daysPassed
            : totalSeconds;

    final monthName =
    DateFormat(
      'LLLL',
      'ru',
    ).format(now);

    final weekdays = [
      "Пн",
      "Вт",
      "Ср",
      "Чт",
      "Пт",
      "Сб",
      "Вс",
    ];

    return Column(
      children: [

        Padding(
  padding: const EdgeInsets.fromLTRB(
    20,
    20,
    20,
    10,
  ),
  child: Card(
    elevation: 6,
    color: const Color(0xFFEAF7EC),
    shape: RoundedRectangleBorder(
      borderRadius:
          BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [

          const Icon( Icons.calendar_month, size: 42, color: Colors.deepOrange, ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Text(
                  "Среднее за $monthName",
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  formatHoursMinutes(
                    averageSeconds,
                  ),
                  style:
                      const TextStyle(
                    fontSize: 32,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "$daysPassed дней прошло",
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
),

        Expanded(
          child: ListView.builder(
            itemCount:
                monthTotals.length,
            itemBuilder:
                (
              context,
              index,
            ) {

              final date =
                  monthTotals.keys
                      .elementAt(
                index,
              );

              final seconds =
                  monthTotals[
                      date] ??
                      0;

              final day =
                  DateTime.parse(
                date,
              );

              final weekday =
                  weekdays[
                      day.weekday -
                          1];

              final formattedDate =
                  DateFormat(
                "dd.MM",
              ).format(day);

              return Card(
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  ),
  child: ListTile(
    leading: CircleAvatar(
     backgroundColor:
     Colors.green.shade50,
      child: Text(
        weekday,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    title: Text(
  formattedDate,
  style: const TextStyle(
    fontSize: 18,
  ),
),
    trailing: Text(
      formatHoursMinutes(seconds),
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
);
            },
          ),
        ),

        
      ],
    );
  }

  Widget _buildAppsTab() {

  return Column(
    children: [

      Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<String>(
          initialValue: _selectedPeriod,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(18),
            ),
            filled: true,
            fillColor: Colors.white,
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

     

      const SizedBox(height: 10),

      Expanded(
        child: _loadingApps
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : _topApps.isEmpty
                ? const Center(
                    child: Text(
                      "Нет данных",
                      style: TextStyle(
                        fontSize: 24,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.all(12),
                    itemCount:
                        _topApps.length,
                    itemBuilder:
                        (context, index) {

                      final app =
                          _topApps[index];

                      final minutes =
                          app.value ~/ 60;

                      return Card(
                        elevation: 3,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),

                          leading: CircleAvatar(
                            backgroundColor:
                                Colors.orange.shade50,
                            child: Text(
                              "${index + 1}",
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          title: Text(
                            extractAppName(
                              app.key,
                            ),
                            style:
                                const TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),

                          subtitle: Text(
                            app.key,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  Colors.grey.shade600,
                            ),
                          ),

                          trailing: Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.orange.shade50,
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                            child: Text(
                              "$minutes мин",
                              style:
                                  const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
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
      ),
    );
  }
}