import 'package:flutter/material.dart';
import 'info_screen.dart';
import 'package:lottie/lottie.dart';
import 'profile_setup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _familyController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _inviteController = TextEditingController();

  bool _joinMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Good Family"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen())),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F8FF), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                SizedBox(height: 220, child: Lottie.asset('assets/animations/family.json', repeat: true)),
                const Text("Добро пожаловать\nв Good Family", textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2)),
                const SizedBox(height: 10),
                Text(
                  _joinMode ? "Присоединяйтесь к семье\nи достигайте целей вместе" : "Создайте семейное пространство\nдля здоровых цифровых привычек",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 8, shadowColor: Colors.black12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: "Ваше имя",
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                            filled: true, fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: _joinMode
                              ? Column(key: const ValueKey("join"), children: [
                                  TextField(
                                    controller: _inviteController,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      labelText: "Код приглашения",
                                      prefixIcon: const Icon(Icons.group_add_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                                      filled: true, fillColor: Colors.grey.shade50,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ])
                              : Column(key: const ValueKey("create"), children: [
                                  TextField(
                                    controller: _familyController,
                                    decoration: InputDecoration(
                                      labelText: "Название семьи",
                                      prefixIcon: const Icon(Icons.family_restroom),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                                      filled: true, fillColor: Colors.grey.shade50,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ]),
                        ),
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                            onPressed: () {
                              final name = _nameController.text.trim();
                              if (name.isEmpty) return;
                              final isCreator = !_joinMode;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen(
                                isCreator: isCreator,
                                name: name,
                                familyName: _joinMode ? null : _familyController.text.trim(),
                                inviteCode: _joinMode ? _inviteController.text.trim() : null,
                              )));
                            },
                            child: Text(_joinMode ? "🙋 Далее" : "🌱 Далее", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() { _joinMode = !_joinMode; }),
                          icon: Icon(_joinMode ? Icons.add_circle_outline : Icons.group_add),
                          label: Text(_joinMode ? "Создать новую семью" : "У меня есть код приглашения"),
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