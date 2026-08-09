import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main_navigation_screen.dart';
import '../widgets/main_bottom_bar.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text("Полезная информация"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [

          _buildInfoBanner(),

          const SizedBox(height: 26),

          _section(
            icon: Icons.sync_rounded,
            color: Colors.blue,
            title: "Синхронизация",
            text:
                "При открытии экранов приложение обновляет данные с сервера.\n\n"
                "Если интернет недоступен, отображается последняя сохранённая информация.\n\n"
                "В фоновом режиме синхронизация выполняется примерно каждые 15 минут.",
          ),

          _divider(),

          _section(
            icon: Icons.phone_android_rounded,
            color: Colors.green,
            title: "Экранное время",
            text:
                "Good Family использует официальную статистику Android.\n\n"
                "После открытия приложения экранное время может отличаться на несколько секунд. Для обновления достаточно нажать кнопку обновления.",
          ),

          _divider(),

          _section(
            icon: Icons.apps_rounded,
            color: Colors.orange,
            title: "Статистика приложений",
            text:
                "Мы стараемся автоматически исключать системные приложения.\n\n"
                "Если какое-либо приложение определяется неправильно — сообщите нам.",
          ),

          _divider(),

          _section(
            icon: Icons.groups_rounded,
            color: Colors.purple,
            title: "Семья",
            text:
                "Подключение участников происходит по коду приглашения.\n\n"
                "Родитель может изменять имена участников и управлять составом семьи.",
          ),

          _divider(),

          _section(
            icon: Icons.park_rounded,
            color: Colors.green,
            title: "Сад и достижения",
            text:
                "Каждую неделю семья получает достижения.\n\n"
                "Благодаря им растёт семейный сад, а также определяются чемпионы недели и месяца.",
          ),

          _divider(),

          _section(
            icon: Icons.security_rounded,
            color: Colors.redAccent,
            title: "Разрешения",
            text:
                "Для корректной работы рекомендуется выдать все необходимые разрешения.\n\n"
                "Это позволит приложению считать экранное время и выполнять синхронизацию даже в фоне.",
          ),

          const SizedBox(height: 30),

          Center(
            child: Column(
              children: [

                const Text(
                  "Есть идеи или нашли ошибку?",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),

                const SizedBox(height: 10),

                TextButton.icon(
                  onPressed: _openTelegram,
                  icon: const Icon(Icons.telegram),
                  label: const Text(
                    "@Shape999",
                    style: TextStyle(fontSize: 17),
                  ),
                ),

              ],
            ),
          ),

        ],
      ),

bottomNavigationBar: MainBottomBar(
  currentIndex: null,
  onTap: (index) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(
          initialIndex: index,
        ),
      ),
      (_) => false,
    );
  },
),
      
    );
  }

  static Widget _buildInfoBanner() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.blue.shade50,
          Colors.lightBlue.shade100,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.blue.shade100,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Center(
            child: Text(
              "💡",
              style: TextStyle(fontSize: 25),
            ),
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Good Family развивается",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                "Мы постепенно добавляем новые возможности. "
                "Если у вас есть идеи или предложения — расскажите нам.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  static Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Divider(
        color: Colors.grey.shade300,
        height: 1,
      ),
    );
  }

  static Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          children: [

            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          ],
        ),

        const SizedBox(height: 14),

        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.grey.shade800,
          ),
        ),

      ],
    );
  }

  static Future<void> _openTelegram() async {
    final uri = Uri.parse("tg://resolve?domain=Shape999");

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final fallback = Uri.parse("https://t.me/Shape999");
      if (await canLaunchUrl(fallback)) {
        await launchUrl(
          fallback,
          mode: LaunchMode.externalApplication,
        );
      }
    }
  }
}