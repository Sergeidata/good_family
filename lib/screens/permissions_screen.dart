import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/usage_stats_helper.dart';
import 'main_navigation_screen.dart';
import '../widgets/main_bottom_bar.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _usagePermission = false;
  bool _notificationPermission = false;
  bool _batteryPermission = false;


  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final usage = await UsageStatsHelper.hasPermission();
    
    bool notifications = true;
    try {
      final result = await const MethodChannel('family_focus/sync_service')
          .invokeMethod('checkNotificationPermission');
      notifications = result == true;
    } catch (e) {
      notifications = false;
    }

    bool battery = true;
    try {
      final result = await const MethodChannel('family_focus/sync_service')
          .invokeMethod('checkBatteryPermission');
      battery = result == true;
    } catch (e) {
      battery = false;
    }


    

    setState(() {
      _usagePermission = usage;
      _notificationPermission = notifications;
      _batteryPermission = battery;
    });
  }

  Future<void> _requestUsagePermission(bool value) async {
    if (value) await UsageStatsHelper.requestPermission();
    await Future.delayed(const Duration(seconds: 1));
    await _loadPermissions();
  }

  Future<void> _requestNotificationPermission(bool value) async {
    if (value) {
      await const MethodChannel('family_focus/sync_service')
          .invokeMethod('openNotificationSettings');
    }
    await _loadPermissions();
  }

  Future<void> _requestBatteryPermission(bool value) async {
    if (value) {
      await const MethodChannel('family_focus/sync_service')
          .invokeMethod('openBatterySettings');
    }
    await _loadPermissions();
  }


 Widget _buildPermissionTile({
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [

          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF5F7FA),
      appBar: AppBar(title: const Text("Разрешения")),
      body: SafeArea(
  child: ListView(
    padding: const EdgeInsets.all(20),
    children: [

     

      const SizedBox(height: 28),

      _buildPermissionTile(
        icon: Icons.bar_chart,
        color: Colors.blue,
        title: "Статистика использования",
        subtitle: "Позволяет считать экранное время",
        value: _usagePermission,
        onChanged: _requestUsagePermission,
      ),

      _buildPermissionTile(
        icon: Icons.notifications_active,
        color: Colors.orange,
        title: "Уведомления",
        subtitle: "Напоминания о заданиях и достижениях",
        value: _notificationPermission,
        onChanged: _requestNotificationPermission,
      ),

      _buildPermissionTile(
        icon: Icons.battery_saver,
        color: Colors.green,
        title: "Фоновая работа",
        subtitle: "Позволяет приложению работать постоянно",
        value: _batteryPermission,
        onChanged: _requestBatteryPermission,
      ),

      const SizedBox(height: 10),

      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [

            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.rocket_launch,
                color: Colors.purple,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Автозапуск",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Желательно, чтобы не приходилось открывать после перегазрузок",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                await const MethodChannel(
                  'family_focus/sync_service',
                ).invokeMethod(
                  'openAutostartSettings',
                );
              },
              child: const Text("Открыть"),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.lightBlue.shade50,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Icon(
                Icons.lock_outline,
                color: Colors.blue.shade700,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  "Good Family не получает доступ к фотографиям, сообщениям, контактам, паролям и другим личным данным.\n\n"
                  "Используется только статистика экранного времени и системные разрешения, необходимые для работы приложения.",
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),

      const SizedBox(height: 20),
    ],
  ),



  
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
    );
  }
}