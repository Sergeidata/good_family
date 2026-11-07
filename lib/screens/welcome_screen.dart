import 'package:flutter/material.dart';
import 'info_screen.dart';
import 'package:lottie/lottie.dart';
import 'profile_setup_screen.dart';
import 'auth/auth_gate_screen.dart';

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
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Good Family"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InfoScreen()),
            ),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // Прокрутка отключается, когда клавиатура закрыта
                physics: keyboardOpen
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: keyboardOpen
                      ? MediaQuery.of(context).viewInsets.bottom + 20
                      : 0,
                ),
                child: ConstrainedBox(
                  // Минимальная высота = высота экрана (без клавиатуры)
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Анимация
                         SizedBox(
                          height: 220,
                          child: Lottie.asset(
                            'assets/animations/family.json',
                            repeat: true,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Заголовок
                        Text(
                          _joinMode ? "Присоединиться" : "Создать семью",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Подзаголовок
                        Text(
                          _joinMode
                              ? "Введите код приглашения"
                              : "Начните заботиться о привычках вместе",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Поля ввода
                        TextField(
                          controller: _nameController,
                          decoration: _inputDecoration(
                            label: "Ваше имя",
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 10),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _joinMode
                              ? Column(
                                  key: const ValueKey("join"),
                                  children: [
                                    TextField(
                                      controller: _inviteController,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      decoration: _inputDecoration(
                                        label: "Код приглашения",
                                        icon: Icons.group_add_outlined,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  key: const ValueKey("create"),
                                  children: [
                                    TextField(
                                      controller: _familyController,
                                      decoration: _inputDecoration(
                                        label: "Название семьи",
                                        icon: Icons.family_restroom,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
const SizedBox(height: 12),
                        const Spacer(),

                        // Кнопка
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              final name = _nameController.text.trim();
                              if (name.isEmpty) return;
                              final isCreator = !_joinMode;

                              // Предлагаем создать аккаунт; можно продолжить
                              // и без него — старые версии работают без почты.
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuthGateScreen(),
                                ),
                              );

                              if (!context.mounted) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileSetupScreen(
                                    isCreator: isCreator,
                                    name: name,
                                    familyName: _joinMode
                                        ? null
                                        : _familyController.text.trim(),
                                    inviteCode: _joinMode
                                        ? _inviteController.text.trim()
                                        : null,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "Далее",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Переключатель режима
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _joinMode = !_joinMode),
                          icon: Icon(
                            _joinMode
                                ? Icons.add_circle_outline
                                : Icons.group_add,
                            size: 16,
                          ),
                          label: Text(
                            _joinMode
                                ? "Создать новую семью"
                                : "У меня есть код приглашения",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}