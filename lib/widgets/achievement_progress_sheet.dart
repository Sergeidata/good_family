import 'package:flutter/material.dart';

Widget buildProgressSheet(Map<String, dynamic> data, String title) {
  final current = data["current"] ?? {};
  final previous = data["previous"] ?? {};
  final target = data["target"] ?? 3;
  final threshold = data["threshold_seconds"] ?? 7200;
  final periodType = data["period_type"] ?? "weekly";
  final type = data["type"] ?? "group";
  final isGroup = type == "group";

  final periodLabelPrev = periodType == "weekly" ? "Прошлая неделя" : "Прошлый месяц";
  final periodLabelCur = periodType == "weekly" ? "Текущая неделя" : "Текущий месяц";

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            "Норма: меньше ${formatDuration(threshold)} в день",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),

          const SizedBox(height: 24),

          buildPeriodBlock(
            label: periodLabelCur,
            data: current,
            target: target,
            threshold: threshold,
            isGroup: isGroup,
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          buildPeriodBlock(
            label: periodLabelPrev,
            data: previous,
            target: target,
            threshold: threshold,
            isGroup: isGroup,
          ),

          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

Widget buildPeriodBlock({
  required String label,
  required Map<String, dynamic> data,
  required int target,
  required int threshold,
  required bool isGroup,
}) {
  final daysCount = data["days_count"] ?? 0;
  final avgSeconds = data["avg_seconds"] ?? 0;
  final members = data["members"] ?? [];
  final hasData = (data["days_total"] ?? 0) > 0;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),

      if (!hasData)
        Text("Пока нет данных за этот период", style: TextStyle(color: Colors.grey.shade500))
      else ...[
        buildProgressBar(daysCount, target),
        const SizedBox(height: 10),

        Row(
          children: [
            Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              isGroup ? "Среднее по семье: " : "Твоё среднее: ",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            Text(
              avgSeconds > 0 ? formatDuration(avgSeconds) : "—",
              style: TextStyle(
                color: avgSeconds < threshold ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),

        if (isGroup && members.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            "По членам семьи:",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...members.map<Widget>((m) => buildMemberRow(m, threshold)),
        ],
      ],
    ],
  );
}

Widget buildProgressBar(int days, int target) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$days из $target дней", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("${(days / target * 100).round()}%", style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: (days / target).clamp(0.0, 1.0),
          minHeight: 10,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(
            days >= target ? Colors.green : Colors.blue,
          ),
        ),
      ),
    ],
  );
}

Widget buildMemberRow(Map<String, dynamic> member, int threshold) {
  final name = member["name"] ?? "";
  final days = member["days"] ?? 0;
  final avg = member["avg_seconds"] ?? 0;
  final daysTotal = member["days_total"] ?? 0;

  Color dotColor;
  if (daysTotal == 0) {
    dotColor = Colors.grey.shade300;
  } else if (days > 0 && avg < threshold) {
    dotColor = Colors.green;
  } else if (avg > 0 && avg >= threshold) {
    dotColor = Colors.orange;
  } else {
    dotColor = Colors.grey.shade300;
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$days ${pluralDays(days)}",
              style: TextStyle(
                color: days > 0 ? Colors.green : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (avg > 0)
              Text(
                "среднее ${formatDuration(avg)}",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
      ],
    ),
  );
}

String pluralDays(int count) {
  if (count % 10 == 1 && count % 100 != 11) return "день";
  if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return "дня";
  return "дней";
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return "${h}ч ${m}м";
  return "${m}м";
}