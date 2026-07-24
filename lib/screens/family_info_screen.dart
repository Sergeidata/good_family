import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FamilyInfoScreen extends StatefulWidget {
  const FamilyInfoScreen({super.key});

  @override
  State<FamilyInfoScreen> createState() => _FamilyInfoScreenState();
}

class _FamilyInfoScreenState extends State<FamilyInfoScreen> {
  bool _loading = true;

  List<dynamic> _members = [];
  String _familyName = '';
  String _inviteCode = '';
  String _createdAt = '';
  bool _isAdmin = false;
  String _deviceId = "";
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatDate(dynamic value) {
    if (value == null) return "-";
    try {
      final dt = DateTime.parse(value.toString()).add(const Duration(hours: 3));
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }


  Future<void> _confirmRemoveMember(Map<String, dynamic> member) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Удалить участника?"),
      content: Text("${member['user_name']} будет удалён из семьи."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Отмена"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Удалить", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final family = await FamilyStorage.loadFamily();
  final ok = await ApiService.removeMember(
    family["family_id"],
    member["user_name"],
    _deviceId,
  );

  if (ok) {
    _loadData();
  } else {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось удалить участника")),
      );
    }
  }
}

  Future<void> _loadData() async {
    final localFamily = await FamilyStorage.loadFamily();
    final familyId = localFamily['family_id'];

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString("device_id") ?? "";

    try {
      final results = await Future.wait([
        ApiService.getFamilyInfo(familyId),
        ApiService.getMembers(familyId),
        ApiService.getFamilyMemberStatus(familyId),
      ]);

      final familyInfo = results[0];
      final members = results[1];
      final status = results[2];

      final memberStatus = status?['members'] ?? [];
      final membersList = members?['members'] ?? [];

      for (final member in membersList) {
        final match = memberStatus.firstWhere(
          (m) => m['user_name'] == member['user_name'],
          orElse: () => {},
        );

        member['last_sync'] =
            match.isNotEmpty ? match['last_sync'] : null;

        if (member["device_id"] == _deviceId &&
            (member["role"] == "admin" ||
                member["role"] == "admin_parent")) {
          _isAdmin = true;
        }
      }

      setState(() {
        _members = membersList;
        _familyName = familyInfo?['family_name'] ??
            localFamily['family_name'] ??
            'Семья';
        _inviteCode =
            familyInfo?['invite_code'] ?? '';
        _createdAt = familyInfo?['created_at'] ?? '';
        _loading = false;
        _error = null;
      });
    } catch (_) {
      setState(() {
        _familyName = localFamily['family_name'] ?? 'Семья';
        _inviteCode = '';
        _members = [];
        _loading = false;
        _error = "Нет связи с сервером";
      });
    }
  }

  void _shareCode() async {
    final channel = MethodChannel('family_focus/sync_service');
    await channel.invokeMethod('share', {
      'text':
          'Присоединяйся к моей семье в Good Family! Код: $_inviteCode',
    });
  }

  Widget _memberTile(Map<String, dynamic> member) {
    final roleRaw = member['role'];
    final role = (roleRaw == 'admin' || roleRaw == 'admin_parent')
        ? 'Организатор'
        : (roleRaw == 'parent' ? 'Родитель' : 'Участник');

    final isMe = member["device_id"] == _deviceId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [

          // AVATAR
  
CircleAvatar(
  radius: 24,
  backgroundColor: Colors.blue.shade100,
  child: Text(
    (member['avatar'] != null && member['avatar'].toString().isNotEmpty)
        ? member['avatar'].toString()
        : (member['user_name'] ?? '?').toString().substring(0, 1).toUpperCase(),
    style: const TextStyle(fontSize: 22),
  ),
),

          const SizedBox(width: 12),

          // INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['user_name'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Последняя синхронизация: ${_formatDate(member['last_sync'])}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

         // ACTIONS
          if (_isAdmin && !isMe)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              onPressed: () => _confirmRemoveMember(member),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // HEADER (в стиле дашборда)
                    Text(
                      "Моя семья",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Семья "$_familyName"',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // INFO BLOCK
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Код приглашения: $_inviteCode",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text("Создана: ${_formatDate(_createdAt)}",
                              style: TextStyle(
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 12),
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _shareCode,
                                icon: const Icon(Icons.share),
                                label: const Text("Поделиться кодом"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            )
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Участники",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: _error != null
                          ? Center(child: Text(_error!))
                          : ListView.builder(
                              itemCount: _members.length,
                              itemBuilder: (_, i) =>
                                  _memberTile(_members[i]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}