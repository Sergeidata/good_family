import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Полезная информация'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '🔄 Синхронизация с сервером',
              'При открытии экранов приложения выполняется запрос на сервер для обновления данных. Если доступа в интернет нет, то выводится последняя обновленная информация.\n\n'
              'В фоновом режиме попытки синхронизации с сервером происходят каждые 15 минут. Для корректного подсчета времени семьи постарайтесь обеспечить, чтобы все устройсва периодически имели доступ к интернету'
              ,
            ),
            _buildSection(
              '📱 Подсчёт экранного времени',
              'Приложение запрашивает у Android статистику использования — это точный способ узнать экранное время.\n\n'
              'При открытии счётчик может показывать приблизительное значение. Нажмите «Обновить» — он уточнится.'
              ,
            ),
            _buildSection(
              '📋 Статистика приложений',
              'Названия приложений могут отображаться некорректно. Системные приложения мы стараемся не считать.\n\n'
              'В текущей версии считаются все приложения кроме системных\n\n'
              'Если заметили ошибку — напишите нам.',
            ),
            _buildSection(
              '👨‍👩‍👧‍👦 Семья',
              'Подключение к семье происходит по коду приглашения. Организатор может удалять участников в экране «Моя семья».\n\n'
              'Имеется возможность отредактировать имя участника'
            ),
            _buildSection(
              '🏆 Достижения и сад',
              'Две игровые механики:\n'
              '• Личные и групповые ачивки — зарабатываются за прошлую календарную неделю и месяц.\n'
              '• Семейный сад — растёт, когда семья зарабатывает ачивки. В текущей версии визуализация есть у ограниченного числа уровней.',
            ),
            _buildSection(
              '⚙️ Разрешения',
              'Для полноценной работы важно выдать все разрешения:\n'
              '• Фоновая работа — чтобы приложение синхронизировалось, даже когда вы в него не заходите.\n'
              '• Уведомления — чтобы знать о новых достижениях и не превышать лимит времени.\n\n'
              'Проверить разрешения можно на главном экране.',
            ),
            const SizedBox(height: 20),
            Center(
              child: InkWell(
                onTap: () => _openTelegram(),
                child: const Text(
                  'По вопросам и предложениям:\nTelegram @Shape999',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }

  void _openTelegram() async {
    final uri = Uri.parse('tg://resolve?domain=Shape999');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Если Telegram не установлен — открыть браузер
      final fallback = Uri.parse('https://t.me/Shape999');
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }
}