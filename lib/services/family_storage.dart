import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class FamilyStorage {
  static const String _fileName = "family.json";

  // ---------------------------------
  // FILE PATH
  // ---------------------------------
  static Future<String> getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();

    return "${dir.path}/$_fileName";
  }

  // ---------------------------------
  // LOAD FAMILY
  // ---------------------------------
  static Future<Map<String, dynamic>> loadFamily() async {
    try {
      final path = await getFilePath();

      final file = File(path);

      if (!await file.exists()) {
        return {};
      }

      final content = await file.readAsString();

      return jsonDecode(content);
    } catch (e) {
      debugPrint("LOAD FAMILY ERROR: $e");
      return {};
    }
  }

  // ---------------------------------
  // SAVE FAMILY
  // ---------------------------------
  static Future<void> saveFamily(
    Map<String, dynamic> data,
  ) async {
    try {
      final path = await getFilePath();

      final file = File(path);

      await file.writeAsString(
        jsonEncode(data),
      );
    } catch (e) {
      debugPrint("SAVE FAMILY ERROR: $e");
    }
  }

  // ---------------------------------
  // CLEAR FAMILY
  // ---------------------------------
  static Future<void> clearFamily() async {
    try {
      final path = await getFilePath();

      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("CLEAR FAMILY ERROR: $e");
    }
  }
}