import 'package:flutter/material.dart';

String extractAppName(String packageName) {
  if (packageName.isEmpty) {
    return "Unknown";
  }

  final parts = packageName.split(".");

  if (parts.isEmpty) {
    return packageName;
  }

  String name = parts.last;

  name = name.replaceAll("_", " ");

  if (name.isEmpty) {
    return packageName;
  }

  return name[0].toUpperCase() +
      name.substring(1);
}

String formatHoursMinutes(int seconds) {
  final hours = seconds ~/ 3600;

  final minutes =
      (seconds % 3600) ~/ 60;

  return "$hours ч $minutes мин";
}




void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
      elevation: 6,
    ),
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
      elevation: 6,
    ),
  );
}

void showInfoSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.blue.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
      elevation: 6,
    ),
  );
}

// Глобальная метка версии аватаров
int avatarVersion = 0;

void bumpAvatarVersion() {
  avatarVersion = DateTime.now().millisecondsSinceEpoch;
}

String avatarUrl(String path) {
  final base = 'http://159.194.219.146:8000$path';
  return avatarVersion > 0 ? '$base?t=$avatarVersion' : base;
}

/// Серверные TIMESTAMP приходят без зоны (UTC). Парсим как UTC и переводим в локальное время.
DateTime parseServerDate(String raw) {
  final s = raw.trim();
  final hasTz = s.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
  return DateTime.parse(hasTz ? normalized : '${normalized}Z').toLocal();
}

/// Как parseServerDate, но только для строк со временем.
/// Если пришла чистая дата (YYYY-MM-DD) — вернёт null, чтобы вызывающий
/// разобрал её обычным DateTime.parse.
DateTime? parseServerDateSafe(String raw) {
  final s = raw.trim();
  if (!s.contains(':') && !s.contains('T')) return null;
  return parseServerDate(s);
}