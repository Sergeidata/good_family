import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FamilyInfoScreen extends StatefulWidget {
  const FamilyInfoScreen({
    super.key,
  });

  @override
  State<FamilyInfoScreen> createState() =>
      _FamilyInfoScreenState();
}

class _FamilyInfoScreenState
    extends State<FamilyInfoScreen> {
  bool _loading = true;

  Map<String, dynamic>? _familyInfo;

  List<dynamic> _members = [];

  String _familyName = '';

  bool _isAdmin = false;

  String _deviceId = "";

  String _inviteCode = '';

  String _createdAt = '';

  String? _error;

  String _formatDate(dynamic value) {
    if (value == null) return "-";

    try {
      

      final dt = DateTime.parse(value.toString()).add(const Duration(hours: 3));
      return "${DateFormat('dd.MM.yyyy HH:mm').format(dt)} ";

    } catch (_) {
      return value.toString();
    }
  }

  @override
  void initState() {
    super.initState();

    _loadData();
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
      member['last_sync'] = match.isNotEmpty ? match['last_sync'] : null;

      if (member["device_id"] == _deviceId && member["role"] == "admin") {
        _isAdmin = true;
      }
    }

    setState(() {
      _familyInfo = familyInfo;
      _members = membersList;
      _familyName = familyInfo?['family_name'] ?? localFamily['family_name'] ?? 'Семья';
      _inviteCode = familyInfo?['invite_code'] ?? localFamily['invite_code'] ?? '';
      _createdAt = familyInfo?['created_at'] ?? '';
      _loading = false;
      _error = null;
    });
  } catch (e) {
    setState(() {
      _familyName = localFamily['family_name'] ?? 'Семья';
      _inviteCode = localFamily['invite_code'] ?? '';
      _members = [];
      _loading = false;
      _error = "Нет связи с сервером";
    });
  }
}

  Widget _buildMemberCard(
    Map<String, dynamic> member,
  ) 
  
  {

     print("MEMBER: ${member["user_name"]}, device_id=${member["device_id"]}");
    final role =
    member['role'] == 'admin'
        ? 'Организатор'
        : 'Участник';


    return Card(
      elevation: 2,
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          12,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(member['user_name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (member["device_id"] == _deviceId)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditNameDialog(member),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(role),
            Text('Присоединился: ${_formatDate(member['joined_at'])}'),
            Text('Последняя синхронизация: ${_formatDate(member['last_sync'])}'),
            
            // Кнопка удаления — только для организатора, не для себя
            
            if (_isAdmin && member['role'] != 'admin')
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Color.fromARGB(255, 107, 104, 103)),
                  onPressed: () => _confirmDelete(member['user_name']),
                ),
              ),
          ],
        ),
      ),
    );
  }

 void _shareCode() async {
  final channel = MethodChannel('family_focus/sync_service');
  await channel.invokeMethod('share', {
    'text': 'Присоединяйся к моей семье в Good Family! Код приглашения: $_inviteCode',
  });
}

Future<void> _showEditNameDialog(Map<String, dynamic> member) async {

  final controller = TextEditingController(text: member["user_name"]);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Изменить имя"),
      content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Новое имя")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
        ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("Сохранить")),
      ],
    ),
  );
  if (result == null || result.isEmpty) return;
  print("EDIT RESULT: $result");

  final family = await FamilyStorage.loadFamily();
  final success = await ApiService.updateMember(family["family_id"], member["user_name"], result, _deviceId);
  
  if (!success) return;

  await FamilyStorage.saveFamily({...family, "user_name": result});
  await _loadData();
  if (mounted) setState(() {});
}

Future<void>
    _confirmDelete(
  String userName,
) async {

  final result =
      await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text(
          "Удалить участника?",
        ),
        content: Text(
          userName,
        ),
        actions: [

          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                false,
              );
            },
            child:
                const Text(
              "Отмена",
            ),
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                true,
              );
            },
            child:
                const Text(
              "Удалить",
            ),
          ),
        ],
      );
    },
  );

  if (result != true) {
    return;
  }

  final family =
      await FamilyStorage
          .loadFamily();

  final success =
      await ApiService
          .removeMember(
    family["family_id"],
    userName,
    _deviceId,
  );

  if (!success) {
    return;
  }

  _loadData();
}

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Моя семья'),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child: Column(
                children: [
                  Card(
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(
                        20,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Семья "$_familyName"',
                            style:
                                const TextStyle(
                              fontSize:
                                  24,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                          const SizedBox(
                            height:
                                12,
                          ),
                          Text(
                            'Создана: ${_formatDate(_createdAt)}',
                          ),
                          const SizedBox(
                            height:
                                8,
                          ),
                          SelectableText(
                            'Код приглашения: $_inviteCode',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          const SizedBox(
                            height:
                                12,
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _shareCode();
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Поделиться кодом'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Align(
                    alignment:
                        Alignment
                            .centerLeft,
                    child: Text(
                      'Участники',
                      style:
                          TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  if (_error != null)
                    Expanded(child: Center(child: Text(_error!, style: const TextStyle(fontSize: 18, color: Colors.red))))
                  else if (_members.isEmpty)
                    const Expanded(child: Center(child: Text("Нет связи с сервером", style: TextStyle(fontSize: 18))))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _members.length,
                        itemBuilder: (context, index) => _buildMemberCard(_members[index]),
                      ),
                    ),
                  
                ],
              ),
            ),
    );
  }
}