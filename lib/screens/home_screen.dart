import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../services/usage_stats_helper.dart';
import '../utils/app_utils.dart';
import 'group_screen.dart';
import 'stats_screen.dart';
import '../services/session_storage.dart';
import 'package:family_focus/screens/welcome_screen.dart';
import '../services/sync_service_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'permissions_screen.dart';
import 'package:family_focus/screens/achievements_screen.dart';
import 'package:family_focus/screens/garden_screen.dart';
import 'package:family_focus/screens/family_info_screen.dart';
import 'info_screen.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

import 'package:yaml/yaml.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();

  
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

class _HomeScreenState
    extends State<HomeScreen> {
  int _screenSeconds = 0;

  Timer? _timer;

  Timer? _syncTimer;

  bool _serviceStarted = false;

  List<MapEntry<String, int>> _topApps = [];

  Future<void> _startBackgroundService() async {
    final family =
    await FamilyStorage.loadFamily();

    final userId =
        family["user_name"];

    final familyId =
        family["family_id"];

    if (
      userId == null ||
      familyId == null
    ) {
      return;
    }

    await SyncServiceHelper.start(
      userId,
      familyId,
    );

    _serviceStarted = true;
  }

  @override
  void initState() {
    super.initState();
    
    _ensureDeviceId();

    _checkPermission();

    _checkForUpdate();

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
    super.dispose();
  }

  void _startCounter() {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        setState(() {
          _screenSeconds++;
        });
      },
    );
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
  }

  Future<void> _syncToServer() async {
  try {
    final family = await FamilyStorage.loadFamily();
    final userId = family["user_name"];
    final familyId = family["family_id"];

    if (!_serviceStarted && userId != null && familyId != null) {
      await SyncServiceHelper.start(userId, familyId);
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

  Widget _menuCard({
    required String emoji,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(20),
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),
        child: Container(
          height: 120,
          padding:
              const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(
                  fontSize: 34,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                title,
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
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

  final hours =
      _screenSeconds ~/ 3600;

  final minutes =
      (_screenSeconds % 3600) ~/ 60;


  return Scaffold(
    appBar: AppBar(
      title:
          const Text("Good Family"),
      actions: [

        IconButton(
          icon: const Icon(
            Icons.help_outline,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const InfoScreen(),
              ),
            );
          },
        ),

        IconButton(
          icon: const Icon(
            Icons.exit_to_app,
          ),
          onPressed: () async {

            final familyData =
                await FamilyStorage
                    .loadFamily();

            final familyName =
                familyData[
                        "family_name"] ??
                    "семьи";

            if (!mounted) return;

            final confirmed =
                await showDialog<bool>(
              context: context,
              builder: (context) =>
                  AlertDialog(
                title: const Text(
                  "Выйти из группы?",
                ),
                content: Text(
                  "Хотите выйти из семейной группы «$familyName»?",
                ),
                actions: [

                  TextButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                      false,
                    ),
                    child:
                        const Text(
                      "Нет",
                    ),
                  ),

                  TextButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                      true,
                    ),
                    child:
                        const Text(
                      "Да",
                    ),
                  ),
                ],
              ),
            );

            if (confirmed ==
                true) {

              await FamilyStorage
                  .saveFamily({});

              if (mounted) {

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WelcomeScreen(),
                  ),
                );
              }
            }
          },
        ),
      ],
    ),

    body: SingleChildScrollView(

      padding:
          const EdgeInsets.all(20),

      child: Column(

        children: [

          Card(
            elevation: 8,
            color: _screenSeconds <= 7200
                ? Colors.green.shade50
                : _screenSeconds <= 14400
                    ? Colors.orange.shade50
                    : Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                28,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                children: [

                  const Text(
                    "Сегодня вы провели\nв телефоне",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Text(
                    "$hours ч $minutes мин",
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment:
                          Alignment.center,
                      children: [

                        CustomPaint(
                          size:
                              const Size(
                            220,
                            220,
                          ),
                          painter:
                              TimeCirclePainter(
                            (_screenSeconds /
                                    (12 *
                                        3600))
                                .clamp(
                              0.0,
                              1.0,
                            ),
                          ),
                        ),

                        const Text(
                          "📱",
                          style: TextStyle(
                            fontSize: 42,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                

                  Text(
                    _screenSeconds <= 7200
                        ? "Отличный результат"
                        : _screenSeconds <=
                                14400
                            ? "Многовато"
                            : "Пора отдохнуть от телефона",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          _screenSeconds <=
                                  7200
                              ? Colors.green
                              : _screenSeconds <=
                                      14400
                                  ? Colors.orange
                                  : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          GridView.count(

            crossAxisCount: 2,

            shrinkWrap: true,

            physics:
                const NeverScrollableScrollPhysics(),

            crossAxisSpacing: 12,
            mainAxisSpacing: 12,

            childAspectRatio: 1.2,

            children: [

              _menuCard(
                emoji: "📊",
                title:
                    "Моя статистика",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const StatsScreen(),
                    ),
                  );
                },
              ),

              _menuCard(
                emoji: "👨‍👩‍👧‍👦",
                title:
                    "Время группы",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const GroupScreen(),
                    ),
                  );
                },
              ),

              _menuCard(
                emoji: "🏆",
                title:
                    "Достижения",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const AchievementsScreen(),
                    ),
                  );
                },
              ),

              _menuCard(
                emoji: "🌱",
                title: "Семейный сад",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GardenScreen2(),
                    ),
                  );
                },
              ),

              _menuCard(
                emoji: "👤",
                title:
                    "Моя семья",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const FamilyInfoScreen(),
                    ),
                  );
                },
              ),

              _menuCard(
                emoji: "⚙️",
                title:
                    "Разрешения",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PermissionsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          SizedBox(
            width: double.infinity,

            child: ElevatedButton.icon(

              icon: const Icon(
                Icons.refresh,
              ),

              label: const Text(
                "Обновить данные",
              ),

              style:
                  ElevatedButton.styleFrom(
                minimumSize:
                    const Size(
                  double.infinity,
                  56,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
              ),

              onPressed:
                  _refreshStats,
            ),
          ),
        ],
      ),
    ),
  );
}
}