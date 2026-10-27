import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../utils/app_utils.dart';
import '../services/cache_storage.dart';
import '../widgets/loading_dots.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() =>
      _GroupScreenState();
}

class _GroupScreenState
    extends State<GroupScreen> {
  String _selectedPeriod =
      "Сегодня";

  String _currentPeriod = "Сегодня";

  bool _loading = true;

  String _familyName = "Семья";

  String _myName = "";

  String? _error;

  DateTime? _lastUpdated;
  bool _fromCache = false;

  List<Map<String, dynamic>>
      _groupStats = [];

  @override
  void initState() {
    super.initState();

    _refreshGroup();
  }

  Future<void> _refreshGroup() async {

    setState(() {
      _loading = true;
    });

    final family =
        await FamilyStorage.loadFamily();

    final familyId =
        family["family_id"];

    _familyName =
        family["family_name"] ??
            "Семья";

    _myName =
        family["user_name"] ?? "";

    
    final membersResponse =
        await ApiService.getMembers(
      familyId,
    );

    if (membersResponse == null) {
      final cache = await CacheStorage.load('group_$familyId');
      setState(() {  // ← добавить setState
        if (cache != null) {
          _groupStats = List<Map<String, dynamic>>.from(cache["data"]["stats"] ?? []);
          _lastUpdated = DateTime.tryParse(cache["updated_at"] ?? "");
          _fromCache = true;
        } else {
          _groupStats = [];
        }
        _loading = false;
        _error = cache == null ? "Нет связи с сервером" : null;
      });
      return;
    }

    final List<dynamic> members =
        membersResponse["members"] ?? [];

    final periodMap = {
      "Сегодня": "today",
      "Вчера": "yesterday",
      "Неделя": "week",
      "Месяц": "month", 
    };

    final apiPeriod =
        periodMap[_selectedPeriod] ??
            "today";

    // Запросы по участникам — параллельно, чтобы не ждать таймауты по очереди.
    final results = await Future.wait<Map<String, dynamic>>(
      members.map(
        (member) async {
          final userName = member["user_name"];

          final response = await ApiService.getStats(
            userName,
            apiPeriod,
          );

          return <String, dynamic>{
            "name": userName,
            "seconds": response?["total_seconds"] ?? 0,
          };
        },
      ),
    );

    final List<Map<String, dynamic>> stats = results;

    stats.sort(
      (a, b) => (a["seconds"] as int)
          .compareTo(
        b["seconds"] as int,
      ),
    );

    await CacheStorage.save('group_$familyId', {"stats": stats});
    _lastUpdated = DateTime.now();
    _fromCache = false;

    setState(() {
      _groupStats = stats;
      _loading = false;
    });
  }

  Color _statusColor(int seconds) {
    if (seconds < 7200) return Colors.green;
    if (seconds < 14400) return Colors.orange;
    return Colors.red;
  }

  String _statusText(int seconds) {
    if (seconds < 7200) return "Отлично";
    if (seconds < 14400) return "Норма";
    return "Многовато";
  }

  // Сервер отдаёт среднесуточное значение для всех периодов.
  bool get _isAveragePeriod =>
      _currentPeriod == "Неделя" ||
      _currentPeriod == "Месяц";

  

 Widget _buildMotivation() {
  if (_groupStats.isEmpty) {
    return const SizedBox();
  }

  final averageSeconds =
      _groupStats
              .map((e) => e["seconds"] as int)
              .reduce((a, b) => a + b) ~/
          _groupStats.length;

  late Color accentColor;
  late Color backgroundColor;
  late IconData icon;
  late String title;
  late String subtitle;

  if (averageSeconds < 7200) {
    accentColor = Colors.green.shade600;
    backgroundColor = Colors.green.shade50;
    icon = Icons.celebration_rounded;
    title = "Отличный результат!";
    subtitle = "В среднем семья проводит с экраном меньше 2 часов.";
  } else if (averageSeconds < 14400) {
    accentColor = Colors.orange.shade600;
    backgroundColor = Colors.orange.shade50;
    icon = Icons.balance_rounded;
    title = "Неплохой баланс";
    subtitle = "Есть куда стремиться, но ситуация пока под контролем.";
  } else {
    accentColor = Colors.red.shade500;
    backgroundColor = Colors.red.shade50;
    icon = Icons.schedule_rounded;
    title = "Стоит немного сократить";
    subtitle = "Среднее экранное время семьи уже довольно высокое.";
  }

  final hours = averageSeconds ~/ 3600;
  final minutes = (averageSeconds % 3600) ~/ 60;

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: accentColor.withValues(alpha: 0.12),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 28,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 17,
                    color: accentColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "В среднем $hours ч $minutes мин",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(
          "Семья: $_familyName",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      DropdownButtonFormField<String>(
  initialValue: _selectedPeriod,
  decoration: InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.blue.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.blue, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
            items: const [
            DropdownMenuItem(
              value: "Сегодня",
              child: Text("Сегодня", style: TextStyle(fontSize: 14)),
            ),
            DropdownMenuItem(
              value: "Вчера",
              child: Text("Вчера", style: TextStyle(fontSize: 14)),
            ),
            DropdownMenuItem(
              value: "Неделя",
              child: Text("За эту неделю", style: TextStyle(fontSize: 14)),
            ),
            DropdownMenuItem(
              value: "Месяц",
              child: Text("За этот месяц", style: TextStyle(fontSize: 14)),
            ),
          ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedPeriod = value;
                        _currentPeriod = value;
                      });
                      _refreshGroup();
                    },
                  ),
                ),

                const SizedBox(width: 10),

                ElevatedButton.icon(
                  onPressed: _refreshGroup,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Обновить"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_error != null)
            
              Center(child: Text(_error!, style: const TextStyle(fontSize: 18))),
              
              if (_groupStats.isNotEmpty)
              _buildMotivation(),

              const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(child: LoadingDots())
                  : ListView.builder(
                      itemCount: _groupStats.length,
                      itemBuilder: (context, index) {

                        final member = _groupStats[index];

                        final seconds = member["seconds"] as int? ?? 0;

                        final isLeader = index == 0;

                        final medalColor =
                            index == 0
                                ? Colors.amber
                                : index == 1
                                    ? Colors.grey
                                    : index == 2
                                        ? Colors.brown
                                        : Colors.blueGrey;

                        return Container(
  margin: const EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: isLeader
          ? Colors.orange.withValues(alpha: 0.25)
          : Colors.grey.withValues(alpha: 0.10),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: isLeader ? 0.07 : 0.04,
        ),
        blurRadius: isLeader ? 16 : 10,
        offset: const Offset(0, 5),
      ),
    ],
  ),
  child: Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    child: Row(
      children: [
        // Место в рейтинге
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: isLeader
                ? Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.orange.shade600,
                    size: 24,
                  )
                : Text(
                    "${index + 1}",
                    style: TextStyle(
                      color: medalColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),

        const SizedBox(width: 14),

        // Имя + время
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      member["name"],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: isLeader
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),

                  if (isLeader) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Лидер",
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 5),

              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 15,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatHoursMinutes(seconds),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              if (_isAveragePeriod) ...[
                const SizedBox(height: 2),
                Text(
                  "в среднем в день",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Статус
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _statusColor(seconds).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _statusText(seconds),
            style: TextStyle(
              color: _statusColor(seconds),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  ),
);
                      },
                    )
            ),

            

           
          ],
        ),
      ),
    );
  }
}