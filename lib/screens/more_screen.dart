import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/family_storage.dart';
import 'welcome_screen.dart';
import 'permissions_screen.dart';
import 'info_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _email = "serz9oodjob@gmail.com";

  Future<void> _sendFeedback(BuildContext context) async {
    final uri = Uri(
      scheme: "mailto",
      path: _email,
      queryParameters: const {
        "subject": "Обратная связь Good Family",
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Не удалось открыть почту"),
        content: const Text(
          "Отправить обратную связь можно по адресу:\n\n"
          "serz9oodjob@gmail.com",
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _email),
              );

              if (context.mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Почта скопирована"),
                  ),
                );
              }
            },
            child: const Text("Скопировать"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Закрыть"),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveFamily(BuildContext context) async {
    final family = await FamilyStorage.loadFamily();

    final familyName =
        family["family_name"] ?? "семьи";

    if (!context.mounted) return;

    final result = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Покинуть семью?"),
            content: Text(
              "Вы действительно хотите покинуть семейную группу «$familyName»?",
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text("Отмена"),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, true),
                child: const Text("Покинуть"),
              ),
            ],
          ),
        ) ??
        false;

    if (!result) return;

    await FamilyStorage.saveFamily({});

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(),
      ),
      (_) => false,
    );
  }

  Widget _menuCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [

              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF5F7FA),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            24,
          ),
          children: [

            const Text(
              "Ещё",
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "Настройки и дополнительная информация",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 28),

            _menuCard(
              context: context,
              icon: Icons.menu_book_rounded,
              color: Colors.blue,
              title: "Полезная информация",
              subtitle:
                  "Советы по использованию приложения",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const InfoScreen(),
                  ),
                );
              },
            ),

            _menuCard(
              context: context,
              icon: Icons.mail_outline_rounded,
              color: Colors.orange,
              title: "Обратная связь",
              subtitle:
                  "Сообщить об ошибке или предложить идею",
              onTap: () {
                _sendFeedback(context);
              },
            ),

            _menuCard(
              context: context,
              icon: Icons.verified_user_rounded,
              color: Colors.green,
              title: "Разрешения",
              subtitle:
                  "Проверить необходимые разрешения",
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

            const SizedBox(height: 14),

            

            _menuCard(
              context: context,
              icon: Icons.logout_rounded,
              color: Colors.red,
              title: "Покинуть группу",
              subtitle:
                  "Выйти из текущей семейной группы",
              onTap: () {
                _leaveFamily(context);
              },
            ),

            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [

                  Text(
                    "Good Family",
                    style: TextStyle(
                      color:
                          Colors.grey.shade700,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Версия 1.1.1",
                    style: TextStyle(
                      color:
                          Colors.grey.shade500,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    "© 2026",
                    style: TextStyle(
                      color:
                          Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}