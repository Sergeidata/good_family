import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      "avatar": _selectedAvatar,
    });

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Группа создана"),
        content: Text("Код приглашения:\n\n${result["invite_code"]}\n\nОтправьте его членам семьи!"),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
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
      "avatar": _selectedAvatar,
    });

    

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Успешно"),
        content: Text("Вы присоединились\nк семье ${result["family_name"]}"),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
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
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: "Кто вы?",
                            prefixIcon: const Icon(Icons.people_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                            filled: true, fillColor: Colors.grey.shade50,
                          ),
                          items: const [
                            DropdownMenuItem(value: "parent", child: Text("👨‍👩‍👧 Родитель")),
                            DropdownMenuItem(value: "child", child: Text("👦 Ребёнок")),
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