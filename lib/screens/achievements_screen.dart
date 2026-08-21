import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../services/cache_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Достижения"),
         bottom: const TabBar(
  isScrollable: false,
  labelColor: Colors.blue,
  unselectedLabelColor: Colors.grey,
  indicatorColor: Colors.blue,
  tabs: [
    Tab(
      icon: Icon(Icons.emoji_events),
      text: "Чемпионат",
    ),
    Tab(
      icon: Icon(Icons.person),
      text: "Личные",
    ),
    Tab(
      icon: Icon(Icons.groups),
      text: "Групповые",
    ),
  ],
),
        ),
        body: TabBarView(
          children: [

            _ChampionsTab(),

            _PersonalAchievementsTab(),

            _GroupAchievementsTab(),
          ],
        ),
        
      ),
    );
  }
}

class _PersonalAchievementsTab extends StatefulWidget {
  const _PersonalAchievementsTab();

  @override
  State<_PersonalAchievementsTab> createState() => _PersonalAchievementsTabState();
}


class _ChampionsTab extends StatefulWidget {
  const _ChampionsTab();

  @override
  State<_ChampionsTab> createState() =>
      _ChampionsTabState();
}

class _ChampionsTabState
    extends State<_ChampionsTab> {

  bool _loading = true;

  bool _weekExpanded = false;
  bool _monthExpanded = false;
  bool _showMonthChampion = false;

  Map<String, dynamic>? _weekChampion;
  Map<String, dynamic>? _monthChampion;

  List<Map<String, dynamic>>
      _weekRanking = [];

  List<Map<String, dynamic>>
      _monthRanking = [];

  bool _showWeek = true;
  bool _showMonth = true;

  @override
  void initState() {
    super.initState();
    _loadChampions();
  }

  Future<void> _loadChampions() async {

    final family =
        await FamilyStorage.loadFamily();

    final familyId =
        family["family_id"];

    final familyInfo =
        await ApiService
            .getFamilyInfo(
      familyId,
    );

    DateTime? createdAt;

    if (familyInfo != null &&
        familyInfo["created_at"] != null) {

      createdAt = DateTime.parse(
        familyInfo["created_at"],
      );
    }

    final now = DateTime.now();

    final startOfCurrentWeek =
        now.subtract(
      Duration(
        days:
            now.weekday - 1,
      ),
    );

    final startOfLastWeek =
        startOfCurrentWeek.subtract(
      const Duration(
        days: 7,
      ),
    );

    

    final startOfLastMonth =
        DateTime(
      now.month == 1
          ? now.year - 1
          : now.year,
      now.month == 1
          ? 12
          : now.month - 1,
      1,
    );

    if (createdAt != null) {

      _showWeek = createdAt
          .isBefore(
        startOfLastWeek,
      );

      _showMonth = createdAt
          .isBefore(
        startOfLastMonth,
      );
    }

    final membersResponse =
        await ApiService
            .getMembers(
      familyId,
    );

    if (membersResponse == null) {

      setState(() {
        _loading = false;
      });

      return;
    }

    final members =
        membersResponse[
                "members"] ??
            [];

    List<Map<String, dynamic>>
        weekStats = [];

    List<Map<String, dynamic>>
        monthStats = [];

    for (final member
        in members) {

      final userName =
          member[
              "user_name"];

      final week =
          await ApiService
              .getStats(
        userName,
        "week",
      );

      final month =
          await ApiService
              .getStats(
        userName,
        "month",
      );

      weekStats.add({
  "name": userName,
  "seconds": week?["total_seconds"] ?? 0,
  "avatar": member["avatar"] ?? "👤",
});

      monthStats.add({
  "name": userName,
  "seconds": month?["total_seconds"] ?? 0,
  "avatar": member["avatar"] ?? "👤",
});
    }

    weekStats.sort(
      (a, b) =>
          (a["seconds"]
                  as int)
              .compareTo(
        b["seconds"]
            as int,
      ),
    );

    monthStats.sort(
      (a, b) =>
          (a["seconds"]
                  as int)
              .compareTo(
        b["seconds"]
            as int,
      ),
    );

    // Проверить что все участники имеют данные за эту неделю
    bool allHaveData = weekStats.every((s) => s["seconds"] > 0);

    setState(() {
      _weekRanking = weekStats;
      _monthRanking = monthStats;

      if (_showWeek && weekStats.isNotEmpty && allHaveData) {
        _weekChampion = weekStats.first;
      } else {
        _weekChampion = null;
      }

      if (_showMonth && monthStats.isNotEmpty) {
        _monthChampion = monthStats.first;
      } else {
        _monthChampion = null;
      }

      _loading = false;
    });
  }

  @override
Widget build(BuildContext context) {
  if (_loading) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  final bool isMonth = _showMonthChampion;

  return ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
    children: [
      // Переключатель периода
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showMonthChampion = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !_showMonthChampion
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: !_showMonthChampion
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      "Неделя",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: !_showMonthChampion
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: !_showMonthChampion
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showMonthChampion = true;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _showMonthChampion
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _showMonthChampion
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      "Месяц",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _showMonthChampion
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _showMonthChampion
                            ? Colors.orange.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 18),

      

      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: isMonth
            ? _buildChampionCard(
                key: const ValueKey("month_champion"),
                title: "Чемпион прошлого месяца",
                champion: _monthChampion,
                ranking: _monthRanking,
                color: Colors.orange.shade600,
                icon: Icons.emoji_events_rounded,
                expanded: _monthExpanded,
                onTap: () {
                  setState(() {
                    _monthExpanded = !_monthExpanded;
                  });
                },
              )
            : _buildChampionCard(
                key: const ValueKey("week_champion"),
                title: "Чемпион прошлой недели",
                champion: _weekChampion,
                ranking: _weekRanking,
                color: Colors.green.shade600,
                icon: Icons.workspace_premium_rounded,
                expanded: _weekExpanded,
                onTap: () {
                  setState(() {
                    _weekExpanded = !_weekExpanded;
                  });
                },
              ),
      ),
    ],
  );
}

  Widget _buildChampionCard({
  Key? key,
  required String title,
  required Map<String, dynamic>? champion,
  required List<Map<String, dynamic>> ranking,
  required Color color,
  required IconData icon,
  required bool expanded,
  required VoidCallback onTap,
}) {

  final hasChampion = champion != null;

  final String infoText =
      title.contains("недели")
          ? "Для определения победителя нужно:\n"
              "1. Дата создания семьи должна быть не позднее понедельника прошлой недели\n"
              "2. Все участники должны быть синхронизированы и иметь количество экранного времени > 0"
          : "Для определения победителя нужно:\n"
              "1. Дата создания семьи должна быть не позднее 1–3 чисел прошлого месяца\n"
              "2. Все участники должны быть синхронизированы и иметь количество экранного времени > 0";

    final praises = [
    "🌟 Лучший результат семьи",
    "👏 Отличная дисциплина",
    "⭐ Продолжай в том же духе",
    "💚 Семья гордится тобой",
    "🌱 Настоящий пример для остальных",
    "🎉 Так держать!",
  ];

  final praise = hasChampion
      ? praises[champion!["name"].toString().hashCode.abs() % praises.length]
      : "";

  return Container(
      key: key,
      decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      children: [

        //--------------------------------------------------
        // Верхняя строка
        //--------------------------------------------------

        Padding(
  padding: const EdgeInsets.fromLTRB(
    20,
    20,
    20,
    0,
  ),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      IconButton(
        splashRadius: 22,
        icon: const Icon(
          Icons.info_outline_rounded,
          color: Colors.grey,
        ),
        onPressed: () {
         showDialog(
  context: context,
  builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),

    title: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.emoji_events_rounded,
            color: Colors.orange.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Условия определения победителя",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      infoText,
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            "Понятно",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  ),
);
        },
      ),
    ],
  ),
),

        const SizedBox(height: 18),

        //--------------------------------------------------
        // Карточка победителя
        //--------------------------------------------------

        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 28,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(26),
            color: hasChampion
                ? color.withValues(alpha: 0.08)
                : Colors.grey.shade100,
            border: Border.all(
              color: hasChampion
                  ? color.withValues(alpha: 0.22)
                  : Colors.grey.shade300,
            ),
          ),

          child: Column(
            children: [

              //--------------------------------------------------
              // Медаль
              //--------------------------------------------------

              Container(
  width: 94, height: 94,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: hasChampion ? color.withValues(alpha: 0.15) : Colors.grey.shade200,
    border: Border.all(color: Colors.white, width: 5),
    boxShadow: [
      BoxShadow(
        color: hasChampion ? color.withValues(alpha: 0.30) : Colors.transparent,
        blurRadius: 18,
      ),
    ],
  ),
  child: Icon(
    icon,
    color: hasChampion ? color : Colors.grey.shade400,
    size: 54,
  ),
),

              const SizedBox(height: 18),

              Text(
              hasChampion ? "👑 Чемпион" : "🏆 Чемпион определяется",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasChampion ? color : Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

              const SizedBox(height: 14),

           hasChampion
    ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            champion["avatar"] ?? "👤",
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(width: 10),
          Text(
            champion["name"],
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          ),
        ],
      )
    : const Text(
        "Ожидаем результаты",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
      ),

              if (hasChampion) ...[

                const SizedBox(height: 16),

                Text(
                  praise,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [

                      Icon(
                        Icons.schedule,
                        size: 18,
                        color: color,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        _formatTime(
                          champion["seconds"],
                        ),
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

              ] else ...[

                const SizedBox(height: 20),

                const Text(
                  "Все участники должны\nсинхронизировать данные,\nпосле чего появится победитель.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (hasChampion)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor:
                  color.withValues(alpha: 0.12),
              foregroundColor: color,
            ),
            onPressed: onTap,
            icon: Icon(
              expanded
                  ? Icons.keyboard_arrow_up
                  : Icons.emoji_events,
            ),
            label: Text(
              expanded
                  ? "Скрыть рейтинг"
                  : "🥇 Таблица чемпионата",
            ),
          ),

        const SizedBox(height: 12),

        AnimatedCrossFade(
          duration: const Duration(
            milliseconds: 250,
          ),

          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,

          firstChild: const SizedBox(),

          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16,
            ),
            child: Column(
              children:
                  ranking.asMap().entries.map(
                (entry) {

                  final index = entry.key;
                  final member = entry.value;

                  IconData placeIcon;
                  Color placeColor;

                  switch (index) {

                    case 0:
                      placeIcon =
                          Icons.looks_one;
                      placeColor =
                          Colors.amber;
                      break;

                    case 1:
                      placeIcon =
                          Icons.looks_two;
                      placeColor =
                          Colors.blueGrey;
                      break;

                    case 2:
                      placeIcon =
                          Icons.looks_3;
                      placeColor =
                          Colors.brown;
                      break;

                    default:
                      placeIcon =
                          Icons.person_outline;
                      placeColor =
                          Colors.grey;
                  }

                  return Container(
                    margin:
                        const EdgeInsets.only(
                      bottom: 8,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.grey.shade50,
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  ),
  child: Row(
    children: [

      CircleAvatar(
        radius: 24,
        backgroundColor: placeColor.withValues(alpha: 0.15),
        child: Icon(
          placeIcon,
          color: placeColor,
          size: 28,
        ),
      ),

      const SizedBox(width: 14),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              member["name"],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),

            
          ],
        ),
      ),

      const SizedBox(width: 16),

      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          Text(
            _formatTime(member["seconds"]),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 4),

          Text(
  index == 0
      ? "Лидер"
      : "+${_formatTime(member["seconds"] - ranking.first["seconds"])}",
            style: TextStyle(
              color: index == 0
                  ? Colors.green
                  : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ],
  ),
),
                  );
                },
              ).toList(),
            ),
          ),
        ),
      ],
    ),
  );
}

  String _formatTime(
    int seconds,
  ) {

    final hours =
        seconds ~/ 3600;

    final minutes =
        (seconds %
                3600) ~/
            60;

    return "$hours ч $minutes мин";
  }
}

class _PersonalAchievementsTabState extends State<_PersonalAchievementsTab> {
  Map<String, dynamic>? _data;
  final Map<String, dynamic> _achievementInfo = {};

  int _countTotal() {
  // Считаем все возможные личные достижения из тех же списков, что в _buildAchievementsList
  const weekAchievements = ["3", "5", "7", "3p", "5p", "7p", "3s", "5s", "7s"];
  const monthAchievements = ["10", "20", "25", "-1", "10p", "20p", "25p", "-1p", "10s", "20s", "25s", "-1s"];
  return weekAchievements.length + monthAchievements.length;
}

int _countEarned() {
  int count = 0;
  for (final period in ["week", "month"]) {
    final achievers = _data?["${period}Achievers"] as Map<String, dynamic>? ?? {};
    for (final entry in achievers.entries) {
      if ((entry.value as List<dynamic>).isNotEmpty) count++;
    }
  }
  return count;
}

  DateTime? _lastUpdated;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
  final family = await FamilyStorage.loadFamily();
  final familyId = family["family_id"];

  try {
    final membersResponse = await ApiService.getMembers(familyId);
    final members = membersResponse?["members"] ?? [];

    

    List<Map<String, dynamic>> weekStats = [];
    List<Map<String, dynamic>> monthStats = [];

    for (final member in members) {
      final userName = member["user_name"];
      final weekResponse = await ApiService.getStats(userName, "week");
      final monthResponse = await ApiService.getStats(userName, "month");

      weekStats.add({"name": userName, "seconds": weekResponse?["total_seconds"] ?? 0});
      monthStats.add({"name": userName, "seconds": monthResponse?["total_seconds"] ?? 0});
    }

    weekStats.sort((a, b) => (a["seconds"] as int).compareTo(b["seconds"] as int));
    monthStats.sort((a, b) => (a["seconds"] as int).compareTo(b["seconds"] as int));

   // Получить личные ачивки с сервера
    final allAchievements = await ApiService.getAchievements(familyId, "personal", null);

Map<String, List<String>> weekAchievers = {};
Map<String, List<String>> monthAchievers = {};

// Группируем по ключам достижений (недельные: 3,5,7,3p,5p,7p,3s,5s,7s; месячные: 10,20,25,-1,10p,20p,25p,-1p,10s,20s,25s,-1s)
for (final a in allAchievements) {
  final key = a["achievement_key"].toString();
  final userName = a["user_name"].toString();
  
  // Недельные ключи — короткие (3, 5, 7, 3p, 5p, 7p, 3s, 5s, 7s)
  if (["3", "5", "7", "3p", "5p", "7p", "3s", "5s", "7s"].contains(key)) {
    weekAchievers.putIfAbsent(key, () => []);
    if (!weekAchievers[key]!.contains(userName)) {
      weekAchievers[key]!.add(userName);
    }
  } else {
    // Месячные ключи
    monthAchievers.putIfAbsent(key, () => []);
    if (!monthAchievers[key]!.contains(userName)) {
      monthAchievers[key]!.add(userName);
    }
  }
}

    final achievementsData = await ApiService.getAchievements(familyId, "", null);

      for (final achievement in achievementsData) {
        final key = achievement["achievement_key"];
        final userName = achievement["user_name"];
        _achievementInfo["${key}_$userName"] = {
          "count": achievement["count"] ?? 1,
          "last_earned": achievement["last_earned"],
        };
      }

    final familyInfo = await ApiService.getFamilyInfo(familyId);
    if (familyInfo != null && familyInfo["created_at"] != null) {
      final created = DateTime.parse(familyInfo["created_at"]);
      if (DateTime.now().difference(created).inDays < 3) weekStats = [];
      if (DateTime.now().difference(created).inDays < 28) monthStats = [];
    }

    await CacheStorage.save('achievements_$familyId', {
      "week": weekStats,
      "month": monthStats,
      "weekAchievers": weekAchievers,
      "monthAchievers": monthAchievers,
    });
    _lastUpdated = DateTime.now();
    _fromCache = false;

    setState(() {
      _data = {
        "week": weekStats,
        "month": monthStats,
        "weekAchievers": weekAchievers,
        "monthAchievers": monthAchievers,
      };
    });
  } catch (e) {
    final cache = await CacheStorage.load('achievements_$familyId');
    if (cache != null) {
      setState(() {
        _data = {
          "week": List<Map<String, dynamic>>.from(cache["data"]["week"] ?? []),
          "month": List<Map<String, dynamic>>.from(cache["data"]["month"] ?? []),
          "weekAchievers": Map<String, dynamic>.from(cache["data"]["weekAchievers"] ?? {}),
          "monthAchievers": Map<String, dynamic>.from(cache["data"]["monthAchievers"] ?? {}),
        };
        _lastUpdated = DateTime.tryParse(cache["updated_at"] ?? "");
        _fromCache = true;
      });
    }
  }
}

 

  String formatHoursMinutes(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return "$hoursч $minutesмин";
  }

  

 Widget _buildAchievementCard({
  required String title,
  required String description,
  required String rarity,
  required Color color,
  required IconData icon,
  required List<String> winners,
  required String achievementKey,
  Map<String, int>? counts, 
  Map<String, dynamic>? achievementInfo,
}) {

  final earned = winners.isNotEmpty;

  Color badgeColor;

  switch (rarity.toLowerCase()) {

    case "редкая":
      badgeColor = Colors.blue;
      break;

    case "эпическая":
      badgeColor = Colors.purple;
      break;

    case "легендарная":
      badgeColor = Colors.orange;
      break;

    case "божественная":
      badgeColor = const Color.fromARGB(255, 255, 238, 0);
      break;

    case "редкая+":
      badgeColor = Colors.lightBlue;
      break;

    case "эпическая+":
      badgeColor = Colors.deepPurple;
      break;

    case "легендарная+":
      badgeColor = Colors.deepOrange;
      break;

    case "божественная+":
      badgeColor = Colors.amber;
      break;

    default:
      badgeColor = Colors.grey;
  }

  return Card(
    elevation: earned ? 8 : 2,
    shadowColor: earned
    ? badgeColor.withValues(alpha: 0.45)
    : Colors.black12,
    color: earned
        ? color
        : Colors.grey.shade200,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: Icon(
                  earned
                      ? icon
                      : Icons.lock,
                  size: 30,
                  color: earned
                      ? badgeColor
                      : Colors.grey,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                    color: earned
                        ? Colors.black87
                        : Colors.grey.shade700,
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                ),
                onPressed: () {

                 showDialog(
  context: context,
  builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),

    title: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.emoji_events_rounded,
            color: Colors.green.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      description,
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            "Понятно",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  ),
);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),
            child: Text(
              rarity.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight:
                    FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),

          const SizedBox(height: 12),

           if (earned)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Получили:", style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...winners.map((name) {
          final info = _achievementInfo["${achievementKey}_$name"];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("🎉"),
                    const SizedBox(width: 8),
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if ((info?["count"] ?? 1) > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text("x${info!["count"]}", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                if (info?["last_earned"] != null)
                  Text("Последний раз: ${(info!["last_earned"] as String).substring(0, 10)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          );
        }),
      ],
    ),
  )

        ],
      ),
    ),
  );
}

Widget _buildSectionTitle(
  String title,
  IconData icon,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 16,
    ),
    child: Row(
      children: [

        Icon(
          icon,
          color: Colors.orange,
        ),

        const SizedBox(width: 8),

        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

  List<Widget> _buildAchievementsList(String period) {
    final achievers = _data?["${period}Achievers"] as Map<String, dynamic>? ?? {};
    

    List<Map<String, dynamic>> achievements;
    if (period == "week") {
      achievements = [
        {"title": "3 дня минимум телефона", "description": "3 дня за неделю вы должны провести в телефоне меньше 2 часов в день","rarity": "редкая", "color": const Color(0xFFE3F2FD), "key": "3", "icon": Icons.star},
        {"title": "5 дней минимум телефона", "description": "5 дней за неделю вы должны провести в телефоне меньше 2 часов в день", "rarity": "эпическая", "color": const Color(0xFFF3E5F5), "key": "5", "icon": Icons.auto_awesome},
        {"title": "7 дней минимум телефона","description": "7 дней за неделю вы должны провести в телефоне меньше 2 часов в день", "rarity": "легендарная", "color": const Color(0xFFFFF3E0), "key": "7", "icon": Icons.workspace_premium},
        {"title": "3 дня без телефона", "description": "3 дня за неделю вы должны провести в телефоне меньше 20 минут в день", "rarity": "редкая+", "color": const Color(0xFFB3E5FC), "key": "3p", "icon": Icons.workspace_premium},
        {"title": "5 дней без телефона", "description": "5 дней за неделю вы должны провести в телефоне меньше 20 минут в день", "rarity": "эпическая+", "color": const Color(0xFFD1C4E9), "key": "5p", "icon": Icons.workspace_premium},
        {"title": "7 дней без телефона", "description": "7 дней за неделю вы должны провести в телефоне меньше 20 минут в день", "rarity": "легендарная+", "color": const Color(0xFFFFCC80), "key": "7p", "icon": Icons.workspace_premium},
        {"title": "3 дня минимум соцсетей", "description": "3 дня за неделю вы должны провести в соцсетях меньше 30 минут в день", "rarity": "редкая", "color": const Color(0xFFE3F2FD), "key": "3s", "icon": Icons.forum},
        {"title": "5 дней минимум соцсетей", "description": "5 дней за неделю вы должны провести в соцсетях меньше 30 минут в день", "rarity": "эпическая", "color": const Color(0xFFF3E5F5), "key": "5s", "icon": Icons.groups},
        {"title": "7 дней минимум соцсетей", "description": "7 дней за неделю вы должны провести в соцсетях меньше 30 минут в день", "rarity": "легендарная", "color": const Color(0xFFFFF3E0), "key": "7s", "icon": Icons.public},
      ];
    } else {
      achievements = [
        {"title": "10 дней минимум телефона", "description": "10 дней за месяц вы должны провести в телефоне меньше 2 часов в день","rarity": "редкая", "color": const Color(0xFFE3F2FD), "key": "10", "icon": Icons.star},
        {"title": "20 дней минимум телефона", "description": "20 дней за месяц вы должны провести в телефоне меньше 2 часов в день","rarity": "эпическая", "color": const Color(0xFFF3E5F5), "key": "20", "icon": Icons.auto_awesome},
        {"title": "25 дней минимум телефона", "description": "25 дней за месяц вы должны провести в телефоне меньше 2 часов в день", "rarity": "легендарная", "color": const Color(0xFFFFF3E0), "key": "25", "icon": Icons.workspace_premium},
        {"title": "Весь месяц минимум телефона", "description": "Весь месяц вы должны провести в телефоне меньше 2 часов в день","rarity": "божественная", "color": const Color(0xFFFFFDE7), "key": "-1", "icon": Icons.emoji_events},
        {"title": "10 дней без телефона", "description": "10 дней за месяц вы должны провести в телефоне меньше 20 минут в день", "rarity": "редкая+", "color": const Color(0xFFB3E5FC), "key": "10p", "icon": Icons.workspace_premium},
        {"title": "20 дней без телефона", "description": "20 дней за месяц вы должны провести в телефоне меньше 20 минут в день", "rarity": "эпическая+", "color": const Color(0xFFD1C4E9), "key": "20p", "icon": Icons.workspace_premium},
        {"title": "25 дней без телефона", "description": "25 дней за месяц вы должны провести в телефоне меньше 20 минут в день", "rarity": "легендарная+", "color": const Color(0xFFFFCC80), "key": "25p", "icon": Icons.workspace_premium},
        {"title": "Весь месяц без телефона", "description": "Весь месяц вы должны провести в телефоне меньше 20 минут в день", "rarity": "божественная+", "color": const Color(0xFFFFF59D), "key": "-1p", "icon": Icons.workspace_premium},
        {"title": "10 дней минимум соцсетей", "description": "10 дней за месяц вы должны провести в соцсетях меньше 30 минут в день", "rarity": "редкая", "color": const Color(0xFFE3F2FD), "key": "10s", "icon": Icons.forum},
        {"title": "20 дней минимум соцсетей", "description": "20 дней за месяц вы должны провести в соцсетях меньше 30 минут в день", "rarity": "эпическая", "color": const Color(0xFFF3E5F5), "key": "20s", "icon": Icons.groups},
        {"title": "25 дней минимум соцсетей", "description": "25 дней за месяц вы должны провести в соцсетях меньше 30 минут в день", "rarity": "легендарная", "color": const Color(0xFFFFF3E0), "key": "25s", "icon": Icons.public},
        {"title": "Весь месяц минимум соцсетей", "description": "Весь месяц вы должны провести в соцсетях меньше 30 минут в день", "rarity": "божественная", "color": const Color(0xFFFFFDE7), "key": "-1s", "icon": Icons.emoji_events},
      ];
    }

    return achievements.map((a) {

    final winners =
        (achievers[a["key"]]
                as List<dynamic>?)
            ?.cast<String>() ??
        [];

    return _buildAchievementCard(
  title: a["title"] as String,
  rarity: a["rarity"] as String,
  color: a["color"] as Color,
  icon: a["icon"] as IconData,
  winners: winners,
  description: a["description"] as String,
  achievementKey: a["key"] as String,  // ← добавить
  counts: null,
  achievementInfo: winners.isNotEmpty ? _achievementInfo["${a["key"]}_${winners.first}"] : null,
);
  }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
          // Карточка коллекции
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.amber),
                      SizedBox(width: 8),
                      Text("Коллекция достижений", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "${_countEarned()} из ${_countTotal()}",
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _countTotal() == 0 ? 0 : _countEarned() / _countTotal(),
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(height: 8),
                  Text("Соберите все ачивки!", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                ],
              ),
            ),
          ),
          


         
        const SizedBox(height: 32),
        _buildSectionTitle(
          "Достижения недель",
          Icons.calendar_view_week,
        ),
        const SizedBox(height: 12),
        ..._buildAchievementsList("week"),
        const SizedBox(height: 32),
       _buildSectionTitle(
          "Достижения месяцев",
          Icons.calendar_month,
        ),
        const SizedBox(height: 12),
        ..._buildAchievementsList("month"),

        if (_lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _fromCache
                    ? "Последние данные: ${_lastUpdated!.day.toString().padLeft(2, '0')}.${_lastUpdated!.month.toString().padLeft(2, '0')}.${_lastUpdated!.year} ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}"
                    : "Обновлено: ${_lastUpdated!.day.toString().padLeft(2, '0')}.${_lastUpdated!.month.toString().padLeft(2, '0')}.${_lastUpdated!.year} ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
      ],
    );
  }
}

  



class _GroupAchievementsTab extends StatefulWidget {
  const _GroupAchievementsTab();

  @override
  State<_GroupAchievementsTab> createState() =>
      _GroupAchievementsTabState();
}

class _GroupAchievementsTabState
    extends State<_GroupAchievementsTab> {

  bool _loading = true;

  String _familyName = "Семья";
  int _earnedGroupCount = 0;

  final List<Map<String, dynamic>>
      _achievements = [];

  final Map<String, int> _groupCounts = {};

  final Set<String>
    _weeklyAchievements = {};

  final Set<String>
      _monthlyAchievements = {};

  final Map<String, dynamic> _achievementInfo = {};

  Set<String> _groupKeysFromServer = {};


  String _getTitle(String key) {
  switch (key) {

    case "3":
      return "3 дня минимум телефона";

    case "5":
      return "5 дней минимум телефона";

    case "7":
      return "7 дней минимум телефона";

    case "10":
      return "10 дней минимум телефона";

    case "20":
      return "20 дней минимум телефона";

    case "25":
      return "25 дней минимум телефона";

    case "-1":
      return "Весь месяц минимум телефона";

    case "3p":
      return "3 дня без телефона";

    case "5p":
      return "5 дней без телефона";

    case "7p":
      return "7 дней без телефона";

    case "10p":
      return "10 дней без телефона";

    case "20p":
      return "20 дней без телефона";

    case "25p":
      return "25 дней без телефона";

    case "-1p":
      return "Весь месяц без телефона";

    case "3s":
  return "3 дня минимум соцсетей";

    case "5s":
      return "5 дней минимум соцсетей";

    case "7s":
      return "7 дней минимум соцсетей";

    case "10s":
      return "10 дней минимум соцсетей";

    case "20s":
      return "20 дней минимум соцсетей";

    case "25s":
      return "25 дней минимум соцсетей";

    case "-1s":
      return "Весь месяц минимум соцсетей";

    default:
      return "";
  }
}


String _getDescription(String key) {

  final isWeek =
      ["3", "5", "7", "3p", "5p", "7p"]
          .contains(key);

  final isPhoneFree =
      key.endsWith("p");

  final days = key == "-1" || key == "-1p"
      ? "Весь месяц"
      : key.replaceAll("p", "");

  final threshold =
      isPhoneFree
          ? "30 минут"
          : "3 часов";

  if (key == "-1" || key == "-1p") {

    return isPhoneFree
        ? "Весь месяц ваша семья должна проводить в телефоне меньше $threshold в день в среднем."
        : "Весь месяц ваша семья должна проводить в телефоне меньше $threshold в день в среднем.";
  }

  return isWeek
      ? "$days дней за неделю ваша семья должна проводить в телефоне меньше $threshold в день в среднем."
      : "$days дней за месяц ваша семья должна проводить в телефоне меньше $threshold в день в среднем.";
}

String _getRarity(String key) {

  switch (key) {

    case "3":
    case "10":
      return "редкая";

    case "5":
    case "20":
      return "эпическая";

    case "7":
    case "25":
      return "легендарная";

    case "-1":
      return "божественная";

    case "3p":
    case "10p":
      return "редкая+";

    case "5p":
    case "20p":
      return "эпическая+";

    case "7p":
    case "25p":
      return "легендарная+";

    case "-1p":
      return "божественная+";

      case "3s":
      case "10s":
        return "редкая";

      case "5s":
      case "20s":
        return "эпическая";

      case "7s":
      case "25s":
        return "легендарная";

      case "-1s":
        return "божественная";

    default:
      return "";
  }
}

Color _getColor(String key) {

  switch (key) {

    case "3":
    case "10":
      return const Color(0xFFE3F2FD);

    case "5":
    case "20":
      return const Color(0xFFF3E5F5);

    case "7":
    case "25":
      return const Color(0xFFFFF3E0);

    case "-1":
      return const Color(0xFFFFFDE7);

    case "3p":
    case "10p":
      return const Color(0xFFB3E5FC);

    case "5p":
    case "20p":
      return const Color(0xFFD1C4E9);

    case "7p":
    case "25p":
      return const Color(0xFFFFCC80);

    case "-1p":
      return const Color(0xFFFFF59D);

    case "3s":
    case "10s":
      return const Color(0xFFE3F2FD);

    case "5s":
    case "20s":
      return const Color(0xFFF3E5F5);

    case "7s":
    case "25s":
      return const Color(0xFFFFF3E0);

    case "-1s":
      return const Color(0xFFFFFDE7);  

    default:
      return Colors.grey;
  }
}

IconData _getIcon(String key) {

  switch (key) {

    case "3":
    case "10":
      return Icons.star;

    case "5":
    case "20":
      return Icons.auto_awesome;

    case "7":
    case "25":
      return Icons.workspace_premium;

    case "-1":
      return Icons.emoji_events;

    // "без телефона"

    case "3p":
    case "10p":
      return Icons.star;

    case "5p":
    case "20p":
      return Icons.auto_awesome;

    case "7p":
    case "25p":
      return Icons.workspace_premium;

    case "-1p":
      return Icons.emoji_events;

    case "3s":
    case "10s":
      return Icons.forum;

    case "5s":
    case "20s":
      return Icons.groups;

    case "7s":
    case "25s":
      return Icons.forum_outlined;

    case "-1s":
      return Icons.public;  

    default:
      return Icons.lock;

      
  }
}

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Widget _buildSectionTitle(
  String title,
  IconData icon,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 16,
    ),
    child: Row(
      children: [
        Icon(
          icon,
          color: Colors.orange,
        ),

        const SizedBox(width: 8),

        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

 Future<void> _loadAchievements() async {
    final family = await FamilyStorage.loadFamily();
    final familyId = family["family_id"];
    _familyName = family["family_name"] ?? "Семья";

    DateTime familyCreated = DateTime(2000);
    final familyInfo = await ApiService.getFamilyInfo(familyId);
    if (familyInfo != null && familyInfo["created_at"] != null) {
      familyCreated = DateTime.parse(familyInfo["created_at"]);
    }

    final membersResponse = await ApiService.getMembers(familyId);
    final members = membersResponse?["members"] ?? [];
    final now = DateTime.now();

    // Прошлая неделя
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekMonday = currentMonday.subtract(const Duration(days: 7));
    final lastWeekSunday = currentMonday.subtract(const Duration(days: 1));

    final familyCreatedDate = DateTime(familyCreated.year, familyCreated.month, familyCreated.day);
    final canUseLastWeek = !familyCreatedDate.isAfter(lastWeekMonday);

    int goodWeekDays = 0;
    int superGoodWeekDays = 0;
    int socialGoodWeekDays = 0;

    if (canUseLastWeek) {
      for (DateTime day = lastWeekMonday; !day.isAfter(lastWeekSunday); day = day.add(const Duration(days: 1))) {
        final dateStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
        final stats = await ApiService.getFamilyDailyStats(familyId, dateStr);
        if (stats != null && stats["members_count"] > 0) {
          final avgSeconds = stats["average_seconds"] as int;
          final avgSocial = stats["average_social_seconds"] as int;
          if (avgSeconds < 10800) goodWeekDays++;
          if (avgSeconds < 1800) superGoodWeekDays++;
          if (avgSocial < 2700) socialGoodWeekDays++;
        }
      }
    }

    // Прошлый месяц
    final firstDayCurrentMonth = DateTime(now.year, now.month, 1);
    final lastDayPreviousMonth = firstDayCurrentMonth.subtract(const Duration(days: 1));
    final firstDayPreviousMonth = DateTime(lastDayPreviousMonth.year, lastDayPreviousMonth.month, 1);
    final totalDaysInMonth = lastDayPreviousMonth.day;
    final canUseLastMonth = !familyCreatedDate.isAfter(firstDayPreviousMonth);

    int goodMonthDays = 0;
    int superGoodMonthDays = 0;
    int socialGoodMonthDays = 0;

    if (canUseLastMonth) {
      for (DateTime day = firstDayPreviousMonth; !day.isAfter(lastDayPreviousMonth); day = day.add(const Duration(days: 1))) {
        final dateStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
        final stats = await ApiService.getFamilyDailyStats(familyId, dateStr);
        if (stats != null && stats["members_count"] > 0) {
          final avgSeconds = stats["average_seconds"] as int;
          final avgSocial = stats["average_social_seconds"] as int;
          if (avgSeconds < 10800) goodMonthDays++;
          if (avgSeconds < 1800) superGoodMonthDays++;
          if (avgSocial < 2700) socialGoodMonthDays++;
        }
      }
    }

    _achievements.clear();
    _weeklyAchievements.clear();
    _monthlyAchievements.clear();

    // Недельные
    _addAchievement(title: "3 дня минимум телефона", rarity: "редкая", color: const Color(0xFFE3F2FD), earned: goodWeekDays >= 3, key: "3");
    _addAchievement(title: "5 дней минимум телефона", rarity: "эпическая", color: const Color(0xFFF3E5F5), earned: goodWeekDays >= 5, key: "5");
    _addAchievement(title: "7 дней минимум телефона", rarity: "легендарная", color: const Color(0xFFFFF3E0), earned: goodWeekDays >= 7, key: "7");
    _addAchievement(title: "3 дня без телефона", rarity: "редкая+", color: const Color(0xFFB3E5FC), earned: superGoodWeekDays >= 3, key: "3p");
    _addAchievement(title: "5 дней без телефона", rarity: "эпическая+", color: const Color(0xFFD1C4E9), earned: superGoodWeekDays >= 5, key: "5p");
    _addAchievement(title: "7 дней без телефона", rarity: "легендарная+", color: const Color(0xFFFFCC80), earned: superGoodWeekDays >= 7, key: "7p");
    _addAchievement(title: "3 дня минимум соцсетей", rarity: "редкая", color: const Color(0xFFE3F2FD), earned: socialGoodWeekDays >= 3, key: "3s");
    _addAchievement(title: "5 дней минимум соцсетей", rarity: "эпическая", color: const Color(0xFFF3E5F5), earned: socialGoodWeekDays >= 5, key: "5s");
    _addAchievement(title: "7 дней минимум соцсетей", rarity: "легендарная", color: const Color(0xFFFFF3E0), earned: socialGoodWeekDays >= 7, key: "7s");

    // Месячные
    _addAchievement(title: "10 дней минимум телефона", rarity: "редкая", color: const Color(0xFFE3F2FD), earned: goodMonthDays >= 10, key: "10");
    _addAchievement(title: "20 дней минимум телефона", rarity: "эпическая", color: const Color(0xFFF3E5F5), earned: goodMonthDays >= 20, key: "20");
    _addAchievement(title: "25 дней минимум телефона", rarity: "легендарная", color: const Color(0xFFFFF3E0), earned: goodMonthDays >= 25, key: "25");
    _addAchievement(title: "Весь месяц минимум телефона", rarity: "божественная", color: const Color(0xFFFFFDE7), earned: goodMonthDays >= totalDaysInMonth, key: "-1");
    _addAchievement(title: "10 дней без телефона", rarity: "редкая+", color: const Color(0xFFB3E5FC), earned: superGoodMonthDays >= 10, key: "10p");
    _addAchievement(title: "20 дней без телефона", rarity: "эпическая+", color: const Color(0xFFD1C4E9), earned: superGoodMonthDays >= 20, key: "20p");
    _addAchievement(title: "25 дней без телефона", rarity: "легендарная+", color: const Color(0xFFFFCC80), earned: superGoodMonthDays >= 25, key: "25p");
    _addAchievement(title: "Весь месяц без телефона", rarity: "божественная+", color: const Color(0xFFFFF59D), earned: superGoodMonthDays >= totalDaysInMonth, key: "-1p");
    _addAchievement(title: "10 дней минимум соцсетей", rarity: "редкая", color: const Color(0xFFE3F2FD), earned: socialGoodMonthDays >= 10, key: "10s");
    _addAchievement(title: "20 дней минимум соцсетей", rarity: "эпическая", color: const Color(0xFFF3E5F5), earned: socialGoodMonthDays >= 20, key: "20s");
    _addAchievement(title: "25 дней минимум соцсетей", rarity: "легендарная", color: const Color(0xFFFFF3E0), earned: socialGoodMonthDays >= 25, key: "25s");
    _addAchievement(title: "Весь месяц минимум соцсетей", rarity: "божественная", color: const Color(0xFFFFFDE7), earned: socialGoodMonthDays >= totalDaysInMonth, key: "-1s");

   // Проверка на сервере — ТОЛЬКО по понедельникам и 1-го числа
final isMonday = DateTime.now().weekday == DateTime.monday;
final isFirstDay = DateTime.now().day == 1;
final today = DateTime.now().toIso8601String().split("T")[0];
final prefs = await SharedPreferences.getInstance();

// Групповые достижения
if (isMonday) {
  final lastGroupCheck = prefs.getString('last_group_achievement_check');
  if (lastGroupCheck != today) {
    for (final achievement in _achievements) {
      if (achievement["earned"] == true) {
        final count = await ApiService.checkAchievement(familyId, _familyName, achievement["key"], "group");
        _groupCounts[achievement["key"]] = count;
      }
    }
    await prefs.setString('last_group_achievement_check', today);
  }
}

// Личные достижения
if (isMonday || isFirstDay) {
  final lastPersonalCheck = prefs.getString('last_personal_achievement_check');
  if (lastPersonalCheck != today) {
    for (final member in members) {
      final userName = member["user_name"];
      if (userName == _familyName) continue;
      for (final achievement in _achievements) {
        if (achievement["earned"] == true) {
          await ApiService.checkAchievement(familyId, userName, achievement["key"], "personal");
        }
      }
    }
    await prefs.setString('last_personal_achievement_check', today);
  }
}

    // Заполнить _weeklyAchievements и _monthlyAchievements для build
    if (goodWeekDays >= 3) _weeklyAchievements.add("3");
    if (goodWeekDays >= 5) _weeklyAchievements.add("5");
    if (goodWeekDays >= 7) _weeklyAchievements.add("7");
    if (superGoodWeekDays >= 3) _weeklyAchievements.add("3p");
    if (superGoodWeekDays >= 5) _weeklyAchievements.add("5p");
    if (superGoodWeekDays >= 7) _weeklyAchievements.add("7p");
    if (socialGoodWeekDays >= 3) _weeklyAchievements.add("3s");
    if (socialGoodWeekDays >= 5) _weeklyAchievements.add("5s");
    if (socialGoodWeekDays >= 7) _weeklyAchievements.add("7s");

    if (goodMonthDays >= 10) _monthlyAchievements.add("10");
    if (goodMonthDays >= 20) _monthlyAchievements.add("20");
    if (goodMonthDays >= 25) _monthlyAchievements.add("25");
    if (goodMonthDays >= totalDaysInMonth) _monthlyAchievements.add("-1");
    if (superGoodMonthDays >= 10) _monthlyAchievements.add("10p");
    if (superGoodMonthDays >= 20) _monthlyAchievements.add("20p");
    if (superGoodMonthDays >= 25) _monthlyAchievements.add("25p");
    if (superGoodMonthDays >= totalDaysInMonth) _monthlyAchievements.add("-1p");
    if (socialGoodMonthDays >= 10) _monthlyAchievements.add("10s");
    if (socialGoodMonthDays >= 20) _monthlyAchievements.add("20s");
    if (socialGoodMonthDays >= 25) _monthlyAchievements.add("25s");
    if (socialGoodMonthDays >= totalDaysInMonth) _monthlyAchievements.add("-1s");


// Считаем уникальные групповые ключи из уже загруженных данных
final groupData = await ApiService.getAchievements(familyId, "group", null);
_groupKeysFromServer = groupData.map((a) => a["achievement_key"].toString()).toSet();
_earnedGroupCount = _groupKeysFromServer.length;

    final achievementsData = await ApiService.getAchievements(familyId, "", null);
    for (final achievement in achievementsData) {
      _achievementInfo[achievement["achievement_key"]] = {
        "count": achievement["count"] ?? 1,
        "last_earned": achievement["last_earned"],
      };
    }

    setState(() { _loading = false; });
  }

  void _addAchievement({
    required String title,
    required String rarity,
    required Color color,
    required bool earned,
    required String key,
  }) {

    _achievements.add({
      "title": title,
      "rarity": rarity,
      "color": color,
      "earned": earned,
      "key": key,
    });
  }





Widget _buildGroupAchievementCard(Map<String, dynamic> data) {
  final earned = data["earned"] as bool;
  final color = earned ? data["color"] as Color : Colors.grey.shade200;
  final title = data["title"] as String;
  final rarity = data["rarity"] as String;
  final icon = _getIcon(data["key"] as String);
  final achievementInfo = data["achievementInfo"] as Map<String, dynamic>?;

  return Card(
    elevation: earned ? 8 : 2,
    shadowColor: earned ? color.withValues(alpha: 0.45) : Colors.black12,
    color: earned ? color : Colors.grey.shade200,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Icon(
                earned
                    ? icon
                    : Icons.lock,
                size: 30,
                color: earned
                    ? _badgeColor(rarity)
                    : Colors.grey,
              ),
              ),
              const SizedBox(width: 14),
             Expanded(
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: earned
                ? Colors.black87
                : Colors.grey.shade700,
          ),
        ),
      ),

      IconButton(
        icon: const Icon(
          Icons.info_outline,
          size: 22,
        ),
        color: Colors.grey.shade700,
        onPressed: () {
          showDialog(
  context: context,
  builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),

    title: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.info_outline_rounded,
            color: Colors.blue.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      _getDescription(
        data["key"] as String,
      ),
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            "Понятно",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  ),
);
        },
      ),
    ],
  ),
),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: _badgeColor(rarity), borderRadius: BorderRadius.circular(20)),
            child: Text(rarity.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 12),
          if (earned)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Center(
      child: Column(
        children: [
          Text("🎉 Обладатель: $_familyName 🎉", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          if ((achievementInfo?["count"] ?? 1) > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("x${achievementInfo!["count"]}", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
            ),
          if (achievementInfo?["last_earned"] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("Последний раз: ${(achievementInfo!["last_earned"] as String).substring(0, 10)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
        ],
      ),
    ),
  )
        ],
      ),
    ),
  );
}

Color _badgeColor(String rarity) {

  switch (rarity) {

    case "редкая":
      return Colors.blue;

    case "эпическая":
      return Colors.purple;

    case "легендарная":
      return Colors.orange;

    case "божественная":
      return Colors.amber.shade700;

    case "редкая+":
      return Colors.lightBlue;

    case "эпическая+":
      return Colors.deepPurple;

    case "легендарная+":
      return Colors.deepOrange;

    case "божественная+":
      return Colors.amber;

    default:
      return Colors.grey;
  }
}


 @override
Widget build(BuildContext context) {
  if (_loading) {
    return const Center(child: CircularProgressIndicator());
  }

  final earnedCount = _earnedGroupCount;
  const totalCount = 21;

  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // Коллекция
      Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
             const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.emoji_events, color: Colors.amber),
                SizedBox(width: 8),
                Text("Коллекция достижений", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              Text("$earnedCount из $totalCount", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
            
              LinearProgressIndicator(
                value: earnedCount / totalCount,
                minHeight: 12,
                borderRadius: BorderRadius.circular(20),
                
              ),
                const SizedBox(height: 8),
                  Text("Соберите все ачивки!", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ],
          ),
        ),
      ),
       const SizedBox(height: 32),
      _buildSectionTitle(
        "Достижения недель",
        Icons.calendar_view_week,
      ),

      
      for (final key in ["3", "5", "7", "3p", "5p", "7p", "3s", "5s", "7s"])
        _buildGroupAchievementCard({
          "title": _getTitle(key),
          "rarity": _getRarity(key),
          "color": _getColor(key),
          "earned": _groupKeysFromServer.contains(key),
          "key": key,
          "achievementInfo": _achievementInfo[key],
        }),

      const SizedBox(height: 32),
      _buildSectionTitle("Достижения месяцев", Icons.calendar_month),

      for (final key in ["10", "20", "25", "-1", "10p", "20p", "25p", "-1p", "10s", "20s", "25s", "-1s"])
        _buildGroupAchievementCard({
          "title": _getTitle(key),
          "rarity": _getRarity(key),
          "color": _getColor(key),
          "earned": _groupKeysFromServer.contains(key),
          "key": key,
          "achievementInfo": _achievementInfo[key],
        }),


    ],
  );
}
}
