import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../services/usage_stats_helper.dart';
import '../utils/app_utils.dart';
import '../utils/task_repeat.dart';
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
import '../services/achievement_progress_service.dart';
import '../widgets/next_achievement_card.dart';
import '../widgets/loading_dots.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _screenSeconds = 0;

  Map<String, dynamic>? _dashboard;
  Map<String, dynamic>? _gardenData;
  Map<String, dynamic>? _tasksData;
  AchievementProgress? _achievementProgress;
  bool _loading = true;

  late final AnimationController _refreshController;

  String _userName = "";
  String _greeting = "";

  Timer? _syncTimer;

  Timer? _statsTimer;

  bool _serviceStarted = false;

  String _todayTitle = "💡 Совет дня";

  List<MapEntry<String, int>> _topApps = [];
  String _role = "";

  Future<void> _startBackgroundService() async {
    final family =
    await FamilyStorage.loadFamily();

    final userId =
        family["user_name"];

    final familyId =
        family["family_id"];

    final role = family["role"] ?? "";

    final userName = family["user_name"] ?? "";

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
      userName: userName
    );

    _serviceStarted = true;
  }

  @override
void initState() {
  super.initState();

  WidgetsBinding.instance.addObserver(this);

  _refreshController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
          
    _ensureDeviceId();

    _checkPermission();

    _checkForUpdate();

    _loadAllData();

    _loadHeader();

    _todayMessage =
    _motivationMessages[
        math.Random().nextInt(
            _motivationMessages.length)];

    _updateTodayMessage();        

    _refreshStats();

    _startBackgroundService();

    _syncToServer();

    _syncTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) {
        _syncToServer();
      },
    );

    _statsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        _refreshStats(syncToServer: false);
      },
    );
  }

  @override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _syncTimer?.cancel();
  _statsTimer?.cancel();
  _refreshController.dispose();
  super.dispose();
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStats();
    }
  }

  Future<void> _checkPermission() async {
    // Статистика
    bool hasStatsPermission = await UsageStatsHelper.hasPermission();
    if (!hasStatsPermission) {
      if (!mounted) return;
      final result = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
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
            Icons.bar_chart_rounded,
            color: Colors.orange.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Доступ к статистике",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Нужен доступ к статистике использования для подсчёта экранного времени.",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Нет",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Да",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
            Icons.notifications_active_rounded,
            color: Colors.orange.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Уведомления",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Разрешите уведомления, чтобы получать напоминания и результаты соревнований.",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Нет",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Да",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
            Icons.security_rounded,
            color: Colors.blue.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Проверьте разрешения",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Для корректной работы приложения убедитесь, что все разрешения выданы. "
      "Перейдите в «Проверить разрешения» на главном экране.",
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
    }
  }


Future<void> _refreshDashboard() async {
  _refreshController.repeat();

  try {
    await Future.wait([
      _loadHeader(), 
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
    final currentVersionCode = await _getCurrentVersionCode();
    final latest = await ApiService.getLatestVersion();

    if (latest == null) return;

    final serverVersionCode = latest["version_code"] ?? 0;
    final minVersionCode = latest["min_version_code"] ?? 0;
    final updateUrl = latest["update_url"] ?? "";

    // Принудительное обновление: наша версия ниже минимальной, которую
    // поддерживает сервер. Сравниваем локально — сервер не знает
    // версию клиента.
    final forceUpdate = currentVersionCode < minVersionCode;

    if (serverVersionCode <= currentVersionCode && !forceUpdate) return;

    if (!mounted) return;

    if (forceUpdate) {
      // Принудительное — без "Позже"
     showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => WillPopScope(
    onWillPop: () async => false,
    child: AlertDialog(
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
              Icons.system_update_rounded,
              color: Colors.blue.shade600,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              "Требуется обновление",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        "Вышла новая версия приложения.\n\n"
        "Чтобы продолжить использование, обновите приложение в RuStore.",
        style: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: Colors.grey.shade700,
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () async {
              await launchUrl(
                Uri.parse(updateUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(
              Icons.download_rounded,
              size: 20,
            ),
            label: const Text(
              "Обновить приложение",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);
    } else {
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
            Icons.system_update_rounded,
            color: Colors.orange.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Доступно обновление",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
    content: Text(
      "Новая версия приложения доступна в RuStore.",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),
    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Позже",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await launchUrl(
                    Uri.parse(updateUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(
                  Icons.download_rounded,
                  size: 19,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Обновить",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
);
    }
  } catch (_) {}
}

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadGardenData(),
      _loadTasksData(),
      _loadDashboard(),
      _loadAchievementProgress(),
    ]);

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Ближайшее личное достижение — одним запросом.
  /// При ошибке сети карточка не показывается.
  Future<void> _loadAchievementProgress() async {
    final family = await FamilyStorage.loadFamily();
    final familyId = family["family_id"];
    final userName = family["user_name"];
    if (familyId == null || userName == null) return;

    final progress = await AchievementProgressService.load(
      familyId: familyId,
      userName: userName,
    );

    if (!mounted) return;
    setState(() {
      _achievementProgress = progress;
    });
  }

  /// Переход на вкладку «Личные» экрана «Достижения».
  void _openAchievements() {
    openAchievementsTab(1); // 1 = «Личные»
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
  final userName = family["user_name"];
  final role = family["role"] ?? "";
  if (familyId == null) return;

  final tasks = await ApiService.getTasks(familyId, null);

  if (!mounted) return;

  // Нет связи — не подменяем реальные данные нулями.
  if (tasks == null) {
    setState(() {
      _tasksData = null;
      _updateTodayMessage();
    });
    return;
  }

  final now = DateTime.now();

  final isChild = role == "child";
  final filtered = (isChild
      ? tasks.where((t) => t["assigned_to"] == userName)
      : tasks).where((t) => isTaskActiveToday(t, now)).toList();

  final active = filtered.where((t) => t["status"] == "pending").length;
  final review = filtered.where((t) => t["status"] == "done").length;

  if (mounted) {
    setState(() {
      _tasksData = {"active": active, "review": review};
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

  _role = family["role"] ?? "";   
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


  Future<void> _refreshStats({bool syncToServer = true}) async {
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

    if (!mounted) return;

    setState(() {
      _screenSeconds =
          totalSeconds;

      _topApps = sorted.take(10).toList();
    });

    if (syncToServer) {
      await _syncToServer();
    }

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
      await SyncServiceHelper.start(userId, familyId, role: role, userName: userId);
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
    MainNavigationScreenState.current?.switchToTab(result);
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
  IconData icon = Icons.lightbulb_rounded;
  Color iconColor = Colors.amber;

  final title = _todayTitle.toLowerCase();

  if (title.contains("проверк")) {
    icon = Icons.task_alt_rounded;
    iconColor = Colors.orange;
  } else if (title.contains("чемпион")) {
    icon = Icons.emoji_events_rounded;
    iconColor = Colors.amber;
  } else if (title.contains("синх")) {
    icon = Icons.sync_rounded;
    iconColor = Colors.blue;
  } else if (title.contains("сад")) {
    icon = Icons.park_rounded;
    iconColor = Colors.green;
  } else if (title.contains("экран")) {
    icon = Icons.phone_android_rounded;
    iconColor = Colors.deepPurple;
  } else if (title.contains("связ")) {
    icon = Icons.wifi_off_rounded;
    iconColor = Colors.redAccent;
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFFEAF5FF),
          const Color(0xFFF6FBFF),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.blue.shade100,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.blue.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 30,
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _todayTitle,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF263238),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _todayMessage,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade800,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


  void _updateTodayMessage() {
  // Нет данных вообще — показываем честную ошибку, а не «не хватает достижений».
  if (_gardenData == null && _tasksData == null) {
    _todayTitle = "Нет связи";
    _todayMessage = "Проверьте подключение к интернету и обновите данные.";
    return;
  }

  // 0. Для ребёнка — его задания
  if (_role == "child") {
    final active = _tasksData?["active"] ?? 0;
    if (active > 0) {
      _todayTitle = "📝 Твои задания";
      _todayMessage = "У тебя $active ${active == 1 ? "задание ожидает" : "заданий ожидают"} выполнения.";
      return;
    }
  }

  // 1. Есть задания на проверке (только для родителя)
  if (_role != "child") {
    final review = _tasksData?["review"] ?? 0;
    if (review > 0) {
      _todayTitle = "📝 Требуется проверка";
      _todayMessage = "У вас $review ${review == 1 ? "задание ожидает" : "задания ожидают"} проверки.";
      return;
    }
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
    if (_gardenData != null) {
      final achievements = (_gardenData?["unique_achievements"] ?? 0).toDouble();
      final taskPart = (_gardenData?["task_progress"] ?? 0.0).toDouble();
      final gardenLevel = (_gardenData?["level"] ?? 1).toDouble();
      final totalAchievements = achievements + taskPart;
      final required = gardenLevel;

      if (totalAchievements < required) {
        final need = required - totalAchievements;
        _todayTitle = "🌱 Рост сада";
        _todayMessage = "Для роста сада не хватает ${need.toStringAsFixed(2)} достижения.";
        return;
      }
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

if (_loading)
  const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Center(child: LoadingDots()),
  )
else ...[
  Row(
    children: [
      Expanded(child: _buildGardenCard()),
      const SizedBox(width: 16),
      Expanded(child: _buildTasksCard()),
    ],
  ),

  const SizedBox(height: 20),

  _buildTodayCard(),

  if (_achievementProgress != null &&
      (_achievementProgress!.next != null ||
          _achievementProgress!.allEarned)) ...[
    const SizedBox(height: 20),
    if (_achievementProgress!.next != null)
      NextAchievementCard(
        title: AchievementProgressService.titleOf(
          _achievementProgress!.next!,
        ),
        current:
            (_achievementProgress!.next!["current"] as num?)?.toInt() ?? 0,
        target:
            (_achievementProgress!.next!["target"] as num?)?.toInt() ?? 0,
        onTap: _openAchievements,
        gradientColors: const[Color(0xFFD81B60), Color(0xFFAD1457)],
      )
    else
      AllAchievementsEarnedCard(onTap: _openAchievements),
  ],
],




        ],
      ),
    ),
  );
}
    }