import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CacheStorage {

  static Future<File> _getFile(
    String key,
  ) async {

    final dir =
        await getApplicationDocumentsDirectory();

    return File(
      '${dir.path}/cache_$key.json',
    );
  }

  static Future<void> save(
    String key,
    Map<String, dynamic> data,
  ) async {

    final file =
        await _getFile(key);

    final payload = {
      "updated_at":
          DateTime.now().toIso8601String(),
      "data": data,
    };

    await file.writeAsString(
      jsonEncode(payload),
    );
  }

  static Future<Map<String, dynamic>?> load(
    String key,
  ) async {

    try {

      final file =
          await _getFile(key);

      if (!await file.exists()) {
        return null;
      }

      final content =
          await file.readAsString();

      return jsonDecode(content);

    } catch (_) {

      return null;
    }
  }
}