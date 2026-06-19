import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import 'home_screen.dart';
import 'info_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _familyController =
      TextEditingController();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _inviteController =
      TextEditingController();

  bool _joinMode = false;

  bool _loading = false;

  Future<void> _createGroup() async {
    final familyName =
        _familyController.text.trim();

    final userName =
        _nameController.text.trim();

    final prefs =
    await SharedPreferences.getInstance();

    final deviceId =
        prefs.getString(
          "device_id",
        );

    if (familyName.isEmpty ||
        userName.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final result =
        await ApiService.createFamily(
      familyName,
      userName,
      deviceId ?? "",
    );

    setState(() {
      _loading = false;
    });

    if (result == null) {
      _showError("Нет связи с сервером");
      return;
    }

    await FamilyStorage.saveFamily({
      "family_id": result["family_id"],
      "invite_code": result["invite_code"],
      "family_name": familyName,
      "user_name": userName,
    });

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Группа создана"),
          content: Text(
            "Код приглашения:\n\n"
            "${result["invite_code"]}\n\n"
            "Отправьте его членам семьи!",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  Future<void> _joinGroup() async {
    final inviteCode =
        _inviteController.text.trim();

    final userName =
        _nameController.text.trim();

    final prefs =
    await SharedPreferences.getInstance();

    final deviceId =
        prefs.getString(
          "device_id",
        );

    if (inviteCode.isEmpty ||
        userName.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final result =
        await ApiService.joinFamily(
      inviteCode,
      userName,
      deviceId ?? "",
    );

    setState(() {
      _loading = false;
    });

    if (result == null) {
      _showError("Нет связи с сервером");
      return;
    }

    if (result["status"] != "ok") {
      _showError("Неверный код");
      return;
    }

    await FamilyStorage.saveFamily({
      "family_id": result["family_id"],
      "family_name": result["family_name"],
      "user_name": userName,
    });

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Успешно"),
          content: Text(
            "Вы присоединились\n"
            "к семье ${result["family_name"]}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Good Family"),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InfoScreen(),
              ),
            );
          },
        ),
      ],
    ),

    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF4F8FF),
            Colors.white,
          ],
        ),
      ),

      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),

          child: Column(
            children: [

              /// АНИМАЦИЯ
              SizedBox(
                height: 220,
                child: Lottie.asset(
                  'assets/animations/family.json',
                  repeat: true,
                ),
              ),


              /// ЗАГОЛОВОК
              const Text(
                "Добро пожаловать\nв Good Family",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _joinMode
                    ? "Присоединяйтесь к семье\nи достигайте целей вместе"
                    : "Создайте семейное пространство\nдля здоровых цифровых привычек",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 20),

              /// ФОРМА
              Card(
                elevation: 8,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(24),

                  child: Column(
                    children: [

                      /// ИМЯ
                      TextField(
                        controller: _nameController,

                        decoration: InputDecoration(
                          labelText: "Ваше имя",

                          prefixIcon: const Icon(
                            Icons.person_outline,
                          ),

                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(18),
                          ),

                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// РЕЖИМ ПРИСОЕДИНЕНИЯ
                      AnimatedSwitcher(
                        duration: const Duration(
                          milliseconds: 350,
                        ),

                        child: _joinMode
                            ? Column(
                                key: const ValueKey(
                                  "join",
                                ),

                                children: [

                                  TextField(
                                    controller:
                                        _inviteController,

                                    textCapitalization:
                                        TextCapitalization
                                            .characters,

                                    decoration:
                                        InputDecoration(
                                      labelText:
                                          "Код приглашения",

                                      prefixIcon:
                                          const Icon(
                                        Icons
                                            .group_add_outlined,
                                      ),

                                      border:
                                          OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                          18,
                                        ),
                                      ),

                                      filled: true,

                                      fillColor:
                                          Colors.grey
                                              .shade50,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 20,
                                  ),
                                ],
                              )

                            : Column(
                                key: const ValueKey(
                                  "create",
                                ),

                                children: [

                                  TextField(
                                    controller:
                                        _familyController,

                                    decoration:
                                        InputDecoration(
                                      labelText:
                                          "Название семьи",

                                      prefixIcon:
                                          const Icon(
                                        Icons
                                            .family_restroom,
                                      ),

                                      border:
                                          OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                          18,
                                        ),
                                      ),

                                      filled: true,

                                      fillColor:
                                          Colors.grey
                                              .shade50,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 20,
                                  ),
                                ],
                              ),
                      ),

                      /// КНОПКА
                      SizedBox(
                        width: double.infinity,
                        height: 56,

                        child: ElevatedButton(
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.green,

                            foregroundColor:
                                Colors.white,

                            elevation: 4,

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                18,
                              ),
                            ),
                          ),

                          onPressed: _loading
                              ? null
                              : () {
                                  if (_joinMode) {
                                    _joinGroup();
                                  } else {
                                    _createGroup();
                                  }
                                },

                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,

                                  child:
                                      CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )

                              : Text(
                                  _joinMode
                                      ? "👨‍👩‍👧‍👦 Присоединиться"
                                      : "🌱 Создать семью",

                                  style:
                                      const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// ПЕРЕКЛЮЧАТЕЛЬ
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _joinMode = !_joinMode;
                          });
                        },

                        icon: Icon(
                          _joinMode
                              ? Icons.add_circle_outline
                              : Icons.group_add,
                        ),

                        label: Text(
                          _joinMode
                              ? "Создать новую семью"
                              : "У меня есть код приглашения",
                              
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