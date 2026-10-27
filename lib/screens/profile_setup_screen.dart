import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation_screen.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'crop_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isCreator;
  final String name;
  final String? familyName;
  final String? inviteCode;

  const ProfileSetupScreen({
    super.key,
    required this.isCreator,
    required this.name,
    this.familyName,
    this.inviteCode,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String _selectedRole = "child";
  String _selectedAvatar = "🐶";
  bool _loading = false;
  File? _photoFile;

  final List<String> _avatars = [
    "🐶","🐱","🐭","🐹","🐰",
    "🦊","🐻","🐼","🐨","🐯",
    "🦁","🐮","🐷","🐸","🐵",
    "🐔","🐧","🐦","🐤","🦄",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isCreator) {
      _selectedRole = "parent";
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    if (!mounted) return;

    final croppedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => CropScreen(imageBytes: bytes)),
    );
    if (croppedBytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/profile_avatar.jpg');
    await file.writeAsBytes(croppedBytes);
    if (!mounted) return;

    setState(() => _photoFile = file);
  }

  Future<void> _createGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString("device_id");

    setState(() { _loading = true; });

    final result = await ApiService.createFamily(
      widget.familyName!,
      widget.name,
      deviceId ?? "",
      _selectedRole,
      _selectedAvatar,
    );

    setState(() { _loading = false; });

    if (result == null) {
      _showError("Нет связи с сервером");
      return;
    }

    await FamilyStorage.saveFamily({
      "family_id": result["family_id"],
      "invite_code": result["invite_code"],
      "family_name": widget.familyName,
      "user_name": widget.name,
      "role": "admin_parent",
      "avatar": _photoFile != null ? "" : _selectedAvatar,
    });

    if (_photoFile != null) {
      final ok = await ApiService.uploadAvatar(
        familyId: result["family_id"] as String,
        userName: widget.name,
        filePath: _photoFile!.path,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Не удалось загрузить фото, но профиль создан")),
        );
      }
    }

    if (!mounted) return;

   await showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
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
            Icons.family_restroom_rounded,
            color: Colors.green.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Группа создана",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Код приглашения:\n\n"
      "${result["invite_code"]}\n\n"
      "Отправьте его членам семьи!",
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
          onPressed: () => Navigator.pop(ctx),
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

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MainNavigationScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _joinGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString("device_id");
  

    setState(() { _loading = true; });

    final result = await ApiService.joinFamily(
      widget.inviteCode!,
      widget.name,
      deviceId ?? "",
      _selectedRole,
      _selectedAvatar,
    );

    setState(() { _loading = false; });

    if (result == null) {
      _showError("Нет связи с сервером");
      return;
    }

    if (result["status"] != "ok") {
      _showError("Неверный код");
      return;
    }

    // Взять существующую роль с сервера
    final membersResponse = await ApiService.getMembers(result["family_id"]);
    final membersList = membersResponse?["members"] ?? [];
    final myMember = membersList.firstWhere(
      (m) => m["user_name"] == widget.name,
      orElse: () => {"role": _selectedRole},
    );

    
    final existingRole = myMember["role"] ?? _selectedRole;
    


    await FamilyStorage.saveFamily({
      "family_id": result["family_id"],
      "family_name": result["family_name"],
      "user_name": widget.name,
      "role": existingRole,
      "avatar": _photoFile != null ? "" : _selectedAvatar,
    });

    if (_photoFile != null) {
      final ok = await ApiService.uploadAvatar(
        familyId: result["family_id"] as String,
        userName: widget.name,
        filePath: _photoFile!.path,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Не удалось загрузить фото, но профиль создан")),
        );
      }
    }

    

    if (!mounted) return;

    await showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
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
            Icons.check_circle_outline_rounded,
            color: Colors.blue.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Успешно",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Вы присоединились\nк семье ${result["family_name"]}",
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
          onPressed: () => Navigator.pop(ctx),
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

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MainNavigationScreen(),
      ),
      (route) => false,
    );
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ваш профиль")),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4F8FF), Colors.white]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const Text("Ваш профиль", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Настройте свой профиль перед входом", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                const SizedBox(height: 30),
                Card(
                  elevation: 8, shadowColor: Colors.black12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text("Имя: ${widget.name}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          decoration: InputDecoration(
                            labelText: "Кто вы?",
                            prefixIcon: const Icon(Icons.people_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                            filled: true, fillColor: Colors.grey.shade50,
                          ),
                          items: const [
                            DropdownMenuItem(value: "parent", child: Text("🙋 Родитель")),
                            DropdownMenuItem(value: "child", child: Text("🧒 Ребёнок")),
                          ],
                          onChanged: widget.isCreator ? null : (value) {
                            if (value == null) return;
                            setState(() { _selectedRole = value; });
                          },
                        ),
                        if (widget.isCreator)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text("Администратором семьи может быть только родитель", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Выберите аватар", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                        ),
                        const SizedBox(height: 12),
                        // ---- Фото-аватар ----
                        if (_photoFile == null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _pickPhoto,
                              icon: Icon(Icons.photo_camera),
                              label: Text("Загрузить фото"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: BorderSide(color: Colors.green),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: FileImage(_photoFile!),
                              ),
                              SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _pickPhoto,
                                    icon: Icon(Icons.refresh, size: 18),
                                    label: Text("Заменить"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: () => setState(() => _photoFile = null),
                                    icon: Icon(Icons.delete_outline, size: 18),
                                    label: Text("Убрать"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _avatars.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10),
                          itemBuilder: (ctx, index) {
                            final avatar = _avatars[index];
                            final selected = avatar == _selectedAvatar;
                            return InkWell(
                              onTap: () => setState(() { _selectedAvatar = avatar; }),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: selected ? Colors.blue : Colors.grey.shade300, width: selected ? 3 : 1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(child: Text(avatar, style: const TextStyle(fontSize: 30))),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                            onPressed: _loading ? null : () {
                              if (widget.isCreator) {
                                _createGroup();
                              } else {
                                _joinGroup();
                              }
                            },
                            child: _loading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text("Продолжить", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}