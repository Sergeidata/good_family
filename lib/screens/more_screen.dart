import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../services/auth_service.dart';
import '../services/sync_service_helper.dart';
import 'welcome_screen.dart';
import 'permissions_screen.dart';
import 'info_screen.dart';

import 'dart:io';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _email = "serz9oodjob@gmail.com";

  Future<void> _sendFeedback(BuildContext context) async {
  final family = await FamilyStorage.loadFamily();
  final familyId = family["family_id"] ?? "неизвестно";
  final userName = family["user_name"] ?? "неизвестно";

  // Модель устройства
 final deviceModel = "${Platform.operatingSystem} ${Platform.operatingSystemVersion}";

  final body = """
[Опишите вашу проблему или предложение здесь]


---
family_id: $familyId
участник: $userName
устройство: $deviceModel
""";



 final uri = Uri.parse(
  "mailto:$_email?subject=${Uri.encodeComponent('Обратная связь Good Family')}&body=${Uri.encodeComponent(body)}",
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
            Icons.mail_outline_rounded,
            color: Colors.blue.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Не удалось открыть почту",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Отправить обратную связь можно по адресу:\n\n"
      "serz9oodjob@gmail.com",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(
                      text: _email,
                    ),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade600,
                  side: BorderSide(
                    color: Colors.blue.shade200,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Скопировать",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Закрыть",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
);
}

  /// Блок аккаунта: почта + выход (или предложение создать аккаунт).
  Widget _accountCard(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService.loadEmail(),
      builder: (context, snapshot) {
        final email = snapshot.data ?? "";
        final hasAccount = email.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasAccount
                          ? Colors.blue.shade50
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      hasAccount
                          ? Icons.verified_user_rounded
                          : Icons.person_outline_rounded,
                      color: hasAccount
                          ? Colors.blue
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasAccount ? "Аккаунт: $email" : "Аккаунта нет",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasAccount
                              ? "Семья привязана к почте"
                              : "Создайте, чтобы не потерять данные",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasAccount) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text("Выйти из аккаунта"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text("Выйти из аккаунта?"),
        content: const Text(
          "Вы выйдете из семьи на этом устройстве.\n\n"
          "Семья и данные останутся на сервере — вернуться можно, "
          "войдя снова по почте и паролю.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Выйти",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.logout();

    // Полный выход: нативный сервис не должен синкать со старым family_id.
    await SyncServiceHelper.stop();

    // Чистим локальные данные семьи (family_id, user_name, role, avatar).
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

  Future<void> _leaveFamily(BuildContext context) async {
    final family = await FamilyStorage.loadFamily();

    final familyName =
        family["family_name"] ?? "семьи";

    if (!context.mounted) return;

    final result = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
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
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.exit_to_app_rounded,
            color: Colors.red.shade500,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Выйти из группы?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Вы действительно хотите покинуть семейную группу «$familyName»?",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Отмена",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade500,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Да",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
) ??
        false;

    if (!result) return;

    // Выход только через сервер: без подтверждения сервера семью не чистим.
    final familyId = (family["family_id"] ?? "").toString();
    final userName = (family["user_name"] ?? "").toString();

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString("device_id") ?? "";

    final res = await ApiService.leaveFamily(
      familyId,
      userName,
      deviceId,
    );

    if (!context.mounted) return;

    // Нет связи с сервером — остаёмся в семье, локальные данные не трогаем.
    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Нет связи с сервером"),
        ),
      );
      return;
    }

    if (res["status"]?.toString() != "ok") {
      if (res["message"]?.toString() == "cannot leave as last admin") {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            title: const Text(
              "Нельзя выйти",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "Вы последний администратор, сначала назначьте другого или удалите семью",
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
                  onPressed: () => Navigator.pop(context),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res["message"]?.toString() ?? "Не удалось выйти из семьи",
          ),
        ),
      );
      return;
    }

    // Нативный сервис не должен продолжать синк со старым family_id.
    await SyncServiceHelper.stop();

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

            _accountCard(context),

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
                    "Версия 1.3.0",
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