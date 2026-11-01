import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class SessionStorage {
  static const String _fileName =
      'screen_sessions.json';

  static Future<String> getFilePath() async {
    final directory =
        await getApplicationDocumentsDirectory();

    return '${directory.path}/$_fileName';
  }

  static Future<List<Map<String, dynamic>>>
      loadSessions() async {
    try {
      final path = await getFilePath();

      final file = File(path);

      if (!await file.exists()) {
        return [];
      }

      final content =
          await file.readAsString();

      if (content.trim().isEmpty) {
        return [];
      }

      final List<dynamic> decoded =
          jsonDecode(content);

      return decoded
          .map(
            (item) =>
                Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      debugPrint("LOAD_SESSIONS ERROR: $e");

      return [];
    }
  }

  static Future<void> saveSessions(
    List<Map<String, dynamic>> sessions,
  ) async {
    try {
      final path = await getFilePath();

      final file = File(path);

      final jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(sessions);

      await file.writeAsString(
        jsonString,
      );
    } catch (e) {
      debugPrint("SAVE_SESSIONS ERROR: $e");
    }
  }

  static Future<void> addSession(
    Map<String, dynamic> session,
  ) async {
    try {
      final sessions =
          await loadSessions();

      sessions.add(session);

      await saveSessions(sessions);
    } catch (e) {
      debugPrint("ADD_SESSION ERROR: $e");
    }
  }

  static Future<int> getTodayTotal() async {
  final sessions = await loadSessions();

  final today =
      DateTime.now()
          .toIso8601String()
          .split("T")
          .first;

  int total = 0;

  for (final session in sessions) {
    if (session["date"] == today) {
      total +=
          session["duration_seconds"]
              as int;
    }
  }

  return total;
}

  static Future<void> saveTodayTotal(
  int totalSeconds,
  Map<String, dynamic> data,
) async {
  final sessions = await loadSessions();

  final today =
      DateTime.now()
          .toIso8601String()
          .split("T")
          .first;

  sessions.removeWhere(
    (session) =>
        session["date"] == today,
  );

   sessions.add({
    "date": today,
    "start": "00:00",
    "end": "23:59",
    "duration_seconds": totalSeconds,
    "social_seconds": data["social_seconds"] ?? 0,
    "apps": data["apps"] ?? {},
  });


  await saveSessions(sessions);
}

}

  