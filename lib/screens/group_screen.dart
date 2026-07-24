import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../utils/app_utils.dart';
import '../services/cache_storage.dart';

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

    final members =
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

    List<Map<String, dynamic>>
        stats = [];

    final now = DateTime.now();

    int passedDays =
        now.weekday;

    if (passedDays < 1) {
      passedDays = 1;
    }

    for (final member in members) {

      final userName =
          member["user_name"];

      final response =
          await ApiService.getStats(
        userName,
        apiPeriod,
      );

      int totalSeconds =
          response?["total_seconds"] ?? 0;

      if (_selectedPeriod == "Неделя") {

        totalSeconds =
            (totalSeconds / passedDays)
                .round();
      }

      stats.add({
        "name": userName,
        "seconds": totalSeconds,
      });
    }

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

  Color _statusColor(int seconds, String period) {
    int threshold2h = period == "Неделя" ? 7200 * 7 : period == "Месяц" ? 7200 * 30 : 7200;
    int threshold4h = period == "Неделя" ? 14400 * 7 : period == "Месяц" ? 14400 * 30 : 14400;

    if (seconds < threshold2h) return Colors.green;
    if (seconds < threshold4h) return Colors.orange;
    return Colors.red;
  }

  String _statusText(int seconds, String period) {
    int threshold2h = period == "Неделя" ? 7200 * 7 : period == "Месяц" ? 7200 * 30 : 7200;
    int threshold4h = period == "Неделя" ? 14400 * 7 : period == "Месяц" ? 14400 * 30 : 14400;

    if (seconds < threshold2h) return "Отлично";
    if (seconds < threshold4h) return "Норма";
    return "Многовато";
  }

  

 Widget _buildMotivation() {

  if (_groupStats.isEmpty) {
    return const SizedBox();
  }

  final averageSeconds =
      _groupStats
          .map((e) => e["seconds"] as int)
          .reduce((a, b) => a + b) ~/
      _groupStats.length;

  Color cardColor;
  Color accentColor;
  IconData icon;
  String subtitle;

  if (averageSeconds < 7200) {

    cardColor = const Color(0xFFE8F5E9);
    accentColor = Colors.green;

    icon = Icons.groups_rounded;

    subtitle =
        "Семья укладывается в рекомендуемое время";

  } else if (averageSeconds < 10800) {

    cardColor = const Color(0xFFFFF3E0);
    accentColor = Colors.orange;

    icon = Icons.family_restroom;

    subtitle =
        "Немного сократите использование для получения достижений";

  } else {

    cardColor = const Color(0xFFFFEBEE);
    accentColor = Colors.red;

    icon = Icons.access_time_filled;

    subtitle =
        "Для групповых достижений стоит проводить меньше времени в телефоне";
  }

  return SizedBox(
    width: double.infinity,

    child: Card(
      elevation: 6,

      color: cardColor,

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(24),
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          children: [

            Container(
              width: 70,
              height: 70,

              decoration: BoxDecoration(
                color:
                    accentColor.withValues(
                  alpha: 0.15,
                ),

                shape: BoxShape.circle,
              ),

              child: Icon(
                icon,
                size: 38,
                color: accentColor,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              "Среднее время семьи",

              style: TextStyle(
                fontSize: 18,
                color:
                    const Color.fromARGB(255, 0, 0, 0),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              formatHoursMinutes(
                averageSeconds,
              ),

              style: TextStyle(
                fontSize: 34,
                fontWeight:
                    FontWeight.bold,

                color: accentColor,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              subtitle,

              textAlign:
                  TextAlign.center,

              style: TextStyle(
                color:
                    Colors.grey.shade700,

                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {

    return Scaffold(
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
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
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

                        return Card(
                          elevation: isLeader ? 6 : 3,
                          color: isLeader
                              ? const Color(0xFFFFF8E1)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                            leading: CircleAvatar(
                              backgroundColor:
                                  medalColor.withValues(alpha: 0.15),
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color: medalColor,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),

                            title: Text(
                              member["name"],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: isLeader
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),

                            subtitle: Text(
                              formatHoursMinutes(
                                seconds,
                              ),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),

                            trailing: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  seconds,
                                  _currentPeriod,
                                ).withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                              child: Text(
                                _statusText(
                                  seconds,
                                  _currentPeriod,
                                ),
                                style: TextStyle(
                                  color: _statusColor(
                                    seconds,
                                    _currentPeriod,
                                  ),
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
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