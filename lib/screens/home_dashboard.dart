import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../services/usage_stats_helper.dart';
import '../utils/app_utils.dart';
import 'stats_screen.dart';
import '../services/session_storage.dart';
import '../services/sync_service_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:family_focus/screens/garden_screen.dart';
import 'dart:math' as math;

import 'package:yaml/yaml.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tasks_screen.dart';
import 'main_navigation_screen.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class TimeCirclePainter
    extends CustomPainter {

  final double progress;

  TimeCirclePainter(
    this.progress,
  );

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {

    final center =
        Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        size.width / 2 - 12;

    final backgroundPaint =
        Paint()
          ..color =
              Colors.grey.shade300
          ..strokeWidth = 12
          ..style =
              PaintingStyle.stroke;

    canvas.drawCircle(
      center,
      radius,
      backgroundPaint,
    );

    final progressPaint =
        Paint()
          ..color =
              progress <= 7200 / 43200
                  ? Colors.green
                  : progress <=
                          14400 /
                              43200
                      ? Colors.orange
                      : Colors.red
          ..strokeWidth = 12
          ..style =
              PaintingStyle.stroke
          ..strokeCap =
              StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
      -math.pi / 2,
      progress *
          math.pi *
          2,
      false,
      progressPaint,
    );

    void tick(
      double angle,
      String label,
      Color color,
    ) {

      final outer =
          Offset(
        center.dx +
            math.cos(angle) *
                radius,
        center.dy +
            math.sin(angle) *
                radius,
      );

      final inner =
          Offset(
        center.dx +
            math.cos(angle) *
                (radius - 15),
        center.dy +
            math.sin(angle) *
                (radius - 15),
      );

      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = color
          ..strokeWidth = 3,
      );

      final textPainter =
          TextPainter(
        text: TextSpan(
          text: label,
          style:
              const TextStyle(
            color:
                Colors.black,
            fontSize: 14,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        textDirection:
            TextDirection.ltr,
      );

      textPainter.layout();

      final labelPos =
          Offset(
        center.dx +
                math.cos(
                    angle) *
                    (radius +
                        18) -
            textPainter.width /
                2,
        center.dy +
                math.sin(
                    angle) *
                    (radius +
                        18) -
            textPainter.height /
                2,
      );

      textPainter.paint(
        canvas,
        labelPos,
      );
    }

    tick(
      -math.pi / 2,
      "0ч",
      Colors.black,
    );

    tick(
      -math.pi / 6,
      "2ч",
      Colors.green,
    );

    tick(
      math.pi / 6,
      "4ч",
      Colors.red,
    );

    tick(
      math.pi / 2,
      "6ч",
      Colors.black,
    );

    tick(
      5 * math.pi / 6,
      "8ч",
      Colors.black,
    );

    tick(
      7 * math.pi / 6,
      "10ч",
      Colors.black,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter
        oldDelegate,
  ) {
    return true;
  }
}

class _HomeDashboardState extends State<HomeDashboard>
    with SingleTickerProviderStateMixin {
  int _screenSeconds = 0;

  Map<String, dynamic>? _dashboard;
  Map<String, dynamic>? _gardenData;
  Map<String, dynamic>? _tasksData;

  late final AnimationController _refreshController;

  String _userName = "";
  String _greeting = "";

  Timer? _timer;

  Timer? _syncTimer;

  bool _serviceStarted = false;

  String _todayTitle = "💡 Совет дня";

  List<MapEntry<String, int>> _topApps = [];

  Future<void> _startBackgroundService() async {
    final family =
    await FamilyStorage.loadFamily();

    final userId =
        family["user_name"];

    final familyId =
        family["family_id"];

    final role = family["role"] ?? "";

    if (
      userId == null ||
      familyId == null
    ) {
      return;
    }

    await SyncServiceHelper.start(
      userId,
      familyId,
      role: role,
    );

    _serviceStarted = true;
  }

  @override
void initState() {
  super.initState();

  _refreshController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
          
    _ensureDeviceId();

    _checkPermission();

    _checkForUpdate();

    _loadDashboard();

    _loadGardenData();

    _loadTasksData();

    _loadHeader();

    _todayMessage =
    _motivationMessages[
        math.Random().nextInt(
            _motivationMessages.length)];

    _updateTodayMessage();        

    _startCounter();

    _refreshStats();

    _startBackgroundService();

    _syncToServer();

    _syncTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) {
        _syncToServer();
      },
    );
  }

  @override
void dispose() {
  _timer?.cancel();
  _syncTimer?.cancel();
  _refreshController.dispose();
  super.dispose();
}

  void _startCounter() {
  _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    final now = DateTime.now();
    // Сброс в полночь
    if (now.hour == 0 && now.minute == 0 && now.second == 0) {
      _screenSeconds = 0;
    }
    setState(() {
      _screenSeconds++;
    });
  });
}

  Future<void> _checkPermission() async {
    // Статистика
    bool hasStatsPermission = await UsageStatsHelper.hasPermission();
    if (!hasStatsPermission) {
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Доступ к статистике"),
          content: const Text("Нужен доступ к статистике использования для подсчёта экранного времени."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Нет")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Да")),
          ],
        ),
      );
      if (result == true && mounted) {
        UsageStatsHelper.requestPermission();
        return;
      }
    }

   

    // Уведомления
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final notificationAsked = prefs.getBool("notification_asked") ?? false;
    if (!notificationAsked) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Уведомления"),
          content: const Text("Разрешите уведомления, чтобы получать напоминания и результаты соревнований."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Нет")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Да")),
          ],
        ),
      );
      await prefs.setBool("notification_asked", true);
      if (result == true && mounted) {
        final channel = const MethodChannel('family_focus/sync_service');
        channel.invokeMethod('requestNotificationPermission');
      }
    }

    // Информация о разрешениях (только при первом входе)
    final permissionsInfoShown = prefs.getBool("permissions_info_shown") ?? false;
    if (!permissionsInfoShown) {
      await prefs.setBool("permissions_info_shown", true);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Проверьте разрешения"),
          content: const Text("Для корректной работы приложения убедитесь, что все разрешения выданы. Перейдите в «Проверить разрешения» на главном экране."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }


Future<void> _refreshDashboard() async {
  _refreshController.repeat();

  try {
    await Future.wait([
      _refreshStats(),
      _loadDashboard(),
      _loadGardenData(),
      _loadTasksData(),
    ]);

    // чтобы пользователь успел увидеть анимацию
    await Future.delayed(const Duration(milliseconds: 500));
  } finally {
    _refreshController.stop();
    _refreshController.reset();
  }
}

  Future<void> _checkForUpdate() async {

  try {

    final prefs =
        await SharedPreferences.getInstance();

    final today =
        DateTime.now()
            .toIso8601String()
            .split("T")
            .first;

    final lastShown =
        prefs.getString(
      "last_update_dialog_date",
    );

    if (lastShown == today) {
      return;
    }

    final currentVersionCode = await _getCurrentVersionCode();

    final latest =
        await ApiService.getLatestVersion();

    if (latest == null) {
      return;
    }

    final serverVersionCode =
        latest["version_code"] ?? 0;

    final updateUrl =
        latest["update_url"] ?? "";

    if (serverVersionCode <=
        currentVersionCode) {
      return;
    }

    await prefs.setString(
      "last_update_dialog_date",
      today,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Доступно обновление",
        ),
        content: const Text(
          "Новая версия приложения доступна в RuStore. Обновитесь, чтобы получить новые функции.",
        ),
        actions: [

          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              "Позже",
            ),
          ),

          ElevatedButton(
            onPressed: () async {

              Navigator.pop(context);

              final uri =
                  Uri.parse(updateUrl);

              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text(
              "Обновить",
            ),
          ),
        ],
      ),
    );

  } catch (_) {}
}

Future<void> _loadGardenData() async {
  final family = await FamilyStorage.loadFamily();
  final familyId = family["family_id"];
  if (familyId == null) return;

  final data = await ApiService.getGarden(familyId);
  if (data != null && mounted) {
    setState(() {
      _gardenData = data;
    });
  }

  if (mounted) {
  setState(() {
    _updateTodayMessage();
  });
}
}


Future<void> _loadTasksData() async {
  final family = await FamilyStorage.loadFamily();
  final familyId = family["family_id"];
  if (familyId == null) return;

  final tasks = await ApiService.getTasks(familyId, null);
  final active = tasks.where((t) => t["status"] == "pending").length;
  final review = tasks.where((t) => t["status"] == "done").length;

  if (mounted) {
    setState(() {
      _tasksData = {"active": active, "review": review};
    });
  }

  if (mounted) {
  setState(() {
    _updateTodayMessage();
  });
}
}

Future<void> _loadDashboard() async {
  final family = await FamilyStorage.loadFamily();
  final familyId = family["family_id"];
  final userName = family["user_name"];
  if (familyId == null || userName == null) return;

  // Загружаем статус синхронизации
  final status = await ApiService.getFamilyMemberStatus(familyId);
  
  if (!mounted) return;

  setState(() {
    _dashboard = status; // {"members": [...]}
  });

  if (mounted) {
    setState(() {
      _updateTodayMessage();
    });
  }
}


Future<int> _getCurrentVersionCode() async {
  try {
    final yamlString = await rootBundle.loadString('pubspec.yaml');
    final yamlDoc = loadYaml(yamlString);
    final version = yamlDoc['version'] as String? ?? '1.0.0+1';
    final parts = version.split('+');
    return int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
  } catch (e) {
    return 1;
  }
}

  Future<void> _ensureDeviceId() async {

        final prefs =
            await SharedPreferences.getInstance();

        final existing =
            prefs.getString(
          "device_id",
        );

        if (existing != null) {
          return;
        }

        final deviceId =
            await SyncServiceHelper.getDeviceId();

        if (deviceId != null) {

          await prefs.setString(
            "device_id",
            deviceId,
          );
        }
      }


Future<void> _loadHeader() async {
  final family = await FamilyStorage.loadFamily();

  final name = family["user_name"] ?? "";

  final hour = DateTime.now().hour;

  String greeting;

  if (hour >= 5 && hour < 12) {
    greeting = "Доброе утро";
  } else if (hour >= 12 && hour < 17) {
    greeting = "Добрый день";
  } else if (hour >= 17 && hour < 23) {
    greeting = "Добрый вечер";
  } else {
    greeting = "Доброй ночи";
  }

  setState(() {
    _userName = name;
    _greeting = greeting;
  });
}


  Future<void> _refreshStats() async {
    final stats =
        await UsageStatsHelper
            .getScreenTimeToday();

    final sorted = stats.entries.toList()
      ..sort(
        (a, b) =>
            b.value.compareTo(a.value),
      );

    final totalSeconds = stats.values.fold(
      0,
      (sum, value) => sum + value,
    );

    final socialSeconds = UsageStatsHelper.getSocialSeconds(stats);

    await SessionStorage.saveTodayTotal(
  totalSeconds,
  {
    "apps": stats,
    "social_seconds": socialSeconds,
  },
);

    setState(() {
      _screenSeconds =
          totalSeconds;

      _topApps = sorted.take(10).toList();
    });

    await _syncToServer();

    if (mounted) {
      setState(() {
        _updateTodayMessage();
      });
    }

  }

  Future<void> _syncToServer() async {
  try {
    final family = await FamilyStorage.loadFamily();
    final userId = family["user_name"];
    final familyId = family["family_id"];
  


    if (!_serviceStarted && userId != null && familyId != null) {
      final family = await FamilyStorage.loadFamily();
      final role = family["role"] ?? "";
      await SyncServiceHelper.start(userId, familyId, role: role);
      _serviceStarted = true;
    }

    final totalSeconds = await SessionStorage.getTodayTotal();
    
    final sessions = await SessionStorage.loadSessions();
    final today = DateTime.now().toIso8601String().split("T").first;
    int socialSeconds = 0;
    for (final session in sessions) {
      if (session["date"] == today) {
        socialSeconds += (session["social_seconds"] as int?) ?? 0;
      }
    }

    final topApps = _topApps.map((e) {
      return {"app": extractAppName(e.key), "minutes": e.value ~/ 60};
    }).toList();

    await ApiService.syncData(userId, totalSeconds, topApps, today, socialSeconds: socialSeconds);
  } catch (e) {
    // silently ignore
  }
}

  

Widget _buildScreenTimeCard(
  int hours,
  int minutes,
) {

  return InkWell(
    borderRadius: BorderRadius.circular(28),
   onTap: () async {
  final result = await Navigator.push<int>(
    context,
    MaterialPageRoute(builder: (_) => const StatsScreen()),
  );
  if (result != null) {
    mainNavKey.currentState?.switchToTab(result);
  }
},
    child: Container(
      height: 250,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade400,
            Colors.blue.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
  children: [

  

    Row(
      children: [

        const Icon(
          Icons.phone_android,
          color: Colors.white,
          size: 54,
        ),

        const SizedBox(width: 22),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                "Контроль экранного времени",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "$hours ч $minutes мин",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _screenSeconds <= 7200
                    ? "Отличный результат"
                    : _screenSeconds <= 14400
                        ? "Многовато"
                        : "Пора отдохнуть",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ],
),
    ),
  );
}


Widget _buildGardenCard() {
  final level = _gardenData?["level"];
  final isOffline = level == null;
  final achievements = _gardenData?["achievements_count"] ?? 0;
  final needForNext = (level ?? 1) + 1;
  final enoughAchievements = achievements >= needForNext;

  return InkWell(
    borderRadius: BorderRadius.circular(28),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GardenScreen2()),
      );
    },
    child: Container(
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade700],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.eco, color: Colors.white, size: 54),
          const SizedBox(height: 12),
          const Text(
            "Сад семьи",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (isOffline)
            const Text("Нет связи", style: TextStyle(color: Colors.white70, fontSize: 17))
          else ...[
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 17),
                children: [
                  const TextSpan(text: "Уровень "),
                  TextSpan(
                    text: "$level",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              enoughAchievements
                  ? "В понедельник сад вырастет!"
                  : "Не хватает наград для роста",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildTasksCard() {
  final active = _tasksData?["active"];
  final review = _tasksData?["review"];
  final isOffline = active == null && review == null;

  return InkWell(
    borderRadius: BorderRadius.circular(28),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TasksScreen()),
      );
    },
    child: Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade700],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt, color: Colors.white, size: 42),
            const SizedBox(height: 14),
            const Text(
              "Хорошие дела",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            if (isOffline)
              const Text("Нет связи", style: TextStyle(color: Colors.white70, fontSize: 17))
            else ...[
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                  children: [
                    TextSpan(
                      text: "${active ?? 0}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const TextSpan(text: " активных"),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                  children: [
                    TextSpan(
                      text: "${review ?? 0}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const TextSpan(text: " на проверке"),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}


Widget _buildTodayCard() {
  final isOffline = _gardenData == null && _tasksData == null;

  if (isOffline) {
    _todayTitle = "Нет связи с сервером";
    _todayMessage = "Проверьте подключение к интернету и обновите данные.";
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.blueGrey.shade50,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.blueGrey.shade100),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
       Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: Colors.red.shade50,
    borderRadius: BorderRadius.circular(12),
  ),
  child: const Stack(
    alignment: Alignment.center,
    children: [
      Icon(Icons.mail_outline, color: Colors.redAccent, size: 26),
      Icon(Icons.favorite, color: Colors.redAccent, size: 12),
    ],
  ),
),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_todayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(_todayMessage, style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}


  void _updateTodayMessage() {
    
    // 1. Есть задания на проверке
    final review = _tasksData?["review"] ?? 0;

    

    if (review > 0) {
      _todayTitle = "📝 Требуется проверка";
      _todayMessage =
          "У вас $review ${review == 1 ? "задание ожидает" : "задания ожидают"} проверки.";
      return;
    }

    // 2. Сегодня не синхронизировались
final members = _dashboard?["members"] ?? [];
final today = DateTime.now().toIso8601String().split("T")[0];

final notSynced = members.where((m) {
  final lastSync = m["last_sync"]?.toString() ?? "";
  return !lastSync.startsWith(today);
}).toList();

    if (notSynced.isNotEmpty) {
      final names = notSynced
          .map((e) => e["user_name"])
          .join(", ");

      _todayTitle = "Синхронизация";

      _todayMessage =
          "Сегодня ещё не синхронизированы: $names. Следуеет зайти в приложение, чтобы обновить данные по наградам и экранному времени.";

      return;
    }

    // 3. Не хватает достижений до сада
  // DEBUG
  print('GARDEN: level=${_gardenData?["level"]}, unique=${_gardenData?["unique_achievements"]}, task=${_gardenData?["task_progress"]}');

    final achievements = (_gardenData?["unique_achievements"] ?? 0).toDouble();
    final taskPart = (_gardenData?["task_progress"] ?? 0.0).toDouble();
    final gardenLevel = (_gardenData?["level"] ?? 1).toDouble();
    final totalAchievements = achievements + taskPart;
    final required = gardenLevel + 1;

    if (totalAchievements < required) {
      final need = required - totalAchievements;
      _todayTitle = "🌱 Рост сада";
      _todayMessage = "Для роста сада не хватает ${need.toStringAsFixed(2)} достижения.";
      return;
    }

    // 4. Экранное время >4 часа
    if (_screenSeconds >= 4 * 3600) {
      _todayTitle = "📱 Экранное время";

      _todayMessage =
          "Сегодня экранное время уже высокое. Попробуйте провести вечер без телефона.";

      return;
    }

    // 5. Экранное время >2 часа
    if (_screenSeconds >= 2 * 3600) {
      _todayTitle = "⏳ Экранное время";

      _todayMessage =
          "Экранное время превысило 2 часа. Самое время сделать небольшой перерыв.";

      return;
    }

    // 6. Мотивация
    _todayTitle = "💚 Совет дня";

    _todayMessage =
        _motivationMessages[
            math.Random().nextInt(_motivationMessages.length)];
  }


String _weekday() {

  const days = [

    "",
    "понедельник",
    "вторник",
    "среда",
    "четверг",
    "пятница",
    "суббота",
    "воскресенье",

  ];

  return days[DateTime.now().weekday];


  
}


final List<String> _motivationMessages = [

  "❤️ Сегодня отличный день провести вечер без телефонов.",

  "🌳 Каждый хороший поступок помогает вырастить ваш семейный сад.",

  "🚶 Совместная прогулка делает семью крепче.",

  "📚 Попробуйте сегодня почитать книгу.",

  "🎲 Настольная игра — отличный способ провести вечер вместе.",

  "🤗 Иногда ребёнку важнее ваше внимание, чем подарок.",

  "☕ Попробуйте сегодня вместе поужинать без смартфонов.",

  "💚Маленькие привычки создают счастливую семью.",

  "💚 Поблагодарите сегодня друг друга хотя бы один раз.",

  "😊 Добрые слова запоминаются надолго.",

];

late String _todayMessage;



@override
Widget build(BuildContext context) {
  final hours = _screenSeconds ~/ 3600;
  final minutes = (_screenSeconds % 3600) ~/ 60;

  return Scaffold(
    body: SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          // Приветствие
          Text(
            "$_greeting${_userName.isNotEmpty ? ", $_userName" : ""} 👋",
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Сегодня ${_weekday()}",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
         
          const SizedBox(height: 24),

          // Экранное время
          Stack(
  clipBehavior: Clip.none,
  children: [

    _buildScreenTimeCard(hours, minutes),

   Positioned(
  top: 10,
  right: 10,
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _refreshDashboard,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedBuilder(
          animation: _refreshController,
          builder: (_, child) {
            return Transform.rotate(
              angle: _refreshController.value * 2 * math.pi,
              child: child,
            );
          },
          child: Icon(
            Icons.refresh_rounded,
            color: Colors.white70,
            size: 26,
          ),
        ),
      ),
    ),
  ),
),
  ],
),

const SizedBox(height: 24),

Row(
  children: [
    Expanded(child: _buildGardenCard()),
    const SizedBox(width: 16),
    Expanded(child: _buildTasksCard()),
  ],
),

const SizedBox(height: 20),

_buildTodayCard(),




        ],
      ),
    ),
  );
}
    }