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
      queryParameters: {
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
            onPressed: () {
              Navigator.pop(context);
            },
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
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text("Отмена"),
          ),

          FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text("Покинуть"),
          ),
        ],
      ),
    );

    if (result != true) return;

    await FamilyStorage.saveFamily({});

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(),
      ),
      (route) => false,
    );
  }

  Widget _item({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: color ?? Colors.blue,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(20),

          child: Column(

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              const SizedBox(height: 10),

              const Text(
                "Ещё",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              _item(
                context: context,
                icon: Icons.info_outline,
                title: "Полезная информация",
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

              _item(
                context: context,
                icon: Icons.mail_outline,
                title: "Обратная связь",
                onTap: () {
                  _sendFeedback(context);
                },
              ),

              _item(
                context: context,
                icon: Icons.verified_user_outlined,
                title: "Разрешения",
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

              _item(
                context: context,
                icon: Icons.logout,
                color: Colors.red,
                title: "Выйти из группы",
                onTap: () {
                  _leaveFamily(context);
                },
              ),

            ],
          ),
        ),
      ),
    );
  }
}