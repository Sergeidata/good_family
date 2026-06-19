import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/usage_stats_helper.dart';

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
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(value ? "Включено" : "Выключено",
                       style: TextStyle(color: value ? Colors.green : Colors.red)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Разрешения")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPermissionTile(
              title: "Доступ к статистике",
              value: _usagePermission,
              onChanged: _requestUsagePermission,
            ),
            _buildPermissionTile(
              title: "Фоновые уведомления",
              value: _notificationPermission,
              onChanged: _requestNotificationPermission,
            ),
            _buildPermissionTile(
              title: "Фоновая работа",
              value: _batteryPermission,
              onChanged: _requestBatteryPermission,
            ),
            const Spacer(),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Автозапуск", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text("Откройте настройки автозапуска и активируйте", style: TextStyle(fontSize: 12,color: Colors.grey)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await const MethodChannel('family_focus/sync_service')
                            .invokeMethod('openAutostartSettings');
                      },
                      child: const Text("Открыть"),
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),

            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Данные разрешения не позволяют следить за личными данными устройства (пароли, переписки и т.п.). '
                  'Мы получаем только статистику используемых приложений и позволяем Good Family работать в фоновом режиме. '
                  'На разряд батареи значительного влияния не оказывается.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            
          ],
        ),
      ),
    );
  }
}