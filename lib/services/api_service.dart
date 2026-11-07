import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      "http://89.108.66.36";

  /// Ключ токена в SharedPreferences (совпадает с AuthService).
  static const String _tokenKey = 'session_token';

  // ---------------------------------
  // Заголовки с опциональным Bearer
  // ---------------------------------
  static Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      "Content-Type": "application/json",
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }
    } catch (_) {
      // нет токена — работаем без авторизации
    }

    return headers;
  }

  // ---------------------------------
  // JSON GET с опциональным Bearer
  // ---------------------------------
  static Future<Map<String, dynamic>?> getJson(
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl$path"),
            headers: await _authHeaders(),
          )
          .timeout(timeout);

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);

      return null;
    } catch (e) {
      debugPrint('GET $path ERROR: $e');
      return null;
    }
  }

  // ---------------------------------
  // JSON POST с опциональным Bearer
  // ---------------------------------
  /// POST JSON. Если в SharedPreferences есть session_token —
  /// добавляет заголовок Authorization: Bearer <token>.
  ///
  /// Токен читается напрямую из prefs, чтобы не было циклической
  /// зависимости с AuthService.
  static Future<Map<String, dynamic>?> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl$path"),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(timeout);

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);

      return null;
    } catch (e) {
      debugPrint('POST $path ERROR: $e');
      return null;
    }
  }

  // ---------------------------------
  // CREATE FAMILY
  // ---------------------------------
  static Future<Map<String, dynamic>?> createFamily(
  String familyName,
  String userName,
  String deviceId,
  String role,
  String avatar,
)async {
    // postJson добавляет Authorization: Bearer, если пользователь вошёл.
    return postJson(
      '/create_family',
      {
        "family_name": familyName,
        "user_name": userName,
        "device_id": deviceId,
        "role": role,
        "avatar": avatar,
      },
      timeout: const Duration(seconds: 5),
    );
  }

  // ---------------------------------
  // JOIN FAMILY
  // ---------------------------------
  static Future<Map<String, dynamic>?> joinFamily(
  String inviteCode,
  String userName,
  String deviceId,
  String role,
  String avatar,
)async {
    // postJson добавляет Authorization: Bearer, если пользователь вошёл.
    return postJson(
      '/join_family',
      {
        "invite_code": inviteCode,
        "user_name": userName,
        "device_id": deviceId,
        "role": role,
        "avatar": avatar,
      },
      timeout: const Duration(seconds: 5),
    );
  }

  // ---------------------------------
  // LEAVE FAMILY
  // ---------------------------------
  static Future<Map<String, dynamic>?> leaveFamily(
    String familyId,
    String userName,
    String deviceId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/leave_family"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "family_id": familyId,
          "user_name": userName,
          "requester_device_id": deviceId,
        }),
      ).timeout(
        const Duration(seconds: 10),
      );

      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }
  // удаление членов
  static Future<bool> removeMember(
    String familyId,
    int memberId,
    String deviceId,
  ) async {
    try {
      final response =
          await http.post(
        Uri.parse(
          '$baseUrl/remove_member',
        ),
        headers: {
          'Content-Type':
              'application/json',
        },
        body: jsonEncode({
          'family_id': familyId,
          'member_id': memberId,
          'requester_device_id':
              deviceId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
  // ---------------------------------
  // SYNC SCREEN TIME
  // ---------------------------------
  static Future<Map<String, dynamic>?> syncData(
    String userId,
    int totalSeconds,
    List<Map<String, dynamic>> topApps,
    String date,
    {int socialSeconds = 0}
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/upload"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "date": date,
          "total_seconds": totalSeconds,
          "social_seconds": socialSeconds,
          "top_apps": topApps,
        }),
      ).timeout(const Duration(seconds: 5));
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("SYNC ERROR: $e");
      return null;
    }
  }

  // ---------------------------------
  // GET FAMILY MEMBERS
  // ---------------------------------
  static Future<Map<String, dynamic>?> getMembers(
    String familyId, [
    String deviceId = "",
  ]) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/family_members",
      ).replace(
        queryParameters: {
          "family_id": familyId,
          "requester_device_id": deviceId,
        },
      );

      final response = await http.get(
        uri,
      ).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        return null;
      }

      return data;
    } catch (e) {
      debugPrint("GET MEMBERS ERROR: $e");
      return null;
    }
  }

  // ---------------------------------
  // GET USER STATS
  // ---------------------------------
  static Future<Map<String, dynamic>?> getStats(String userId, String period) async {
  final url = Uri.parse("$baseUrl/stats?user_id=${Uri.encodeComponent(userId)}&period=$period");
  
  for (int i = 0; i < 2; i++) {
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (i == 1) return null;
      await Future.delayed(const Duration(seconds: 2));
    }
  }
  return null;
}
  
  // ---------------------------------
  // ACHIVMENTS
  // ---------------------------------


  static Future<int> checkAchievement(
  String familyId,
  String userName,
  String achievementKey,
  String period,
) async {
  try {
    final response = await http.post(
      Uri.parse(
        "$baseUrl/achievements/check",
      ),
      headers: {
        "Content-Type":
            "application/json",
      },
      body: jsonEncode({
        "family_id": familyId,
        "user_name": userName,
        "achievement_key":
            achievementKey,
        "period": period,
        "earned_date":
            DateFormat(
              "yyyy-MM-dd",
            ).format(DateTime.now()),
      }),
    );

    final data =
        jsonDecode(response.body);

    return data["count"] ?? 1;
  } catch (_) {
    return 1;
  }
}

static Future<List<dynamic>?> getAchievements(
  String familyId,
  String period,
  String? minDate,
) async {
  try {
    String urlString = "$baseUrl/achievements?family_id=$familyId&period=$period";
    if (minDate != null) {
      urlString += "&min_date=$minDate";
    }
    
    final response = await http.get(Uri.parse(urlString));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["achievements"] ?? [];
    }
    return null;
  } catch (e) {
    return null;
  }
}
    

static Future<Map<String, dynamic>?>
    getFamilyInfo(
  String familyId,
) async {
  try {
    final response =
        await http.get(
      Uri.parse(
        "$baseUrl/family_info"
        "?family_id=$familyId",
      ),
    );

    return jsonDecode(
      response.body,
    );
  } catch (_) {
    return null;
  }
}

static Future<Map<String, dynamic>?> getGarden(
  String familyId,
) async {
  try {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/garden?family_id=$familyId',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  } catch (_) {}

  return null;
}

static Future<bool> levelUpGarden(
  String familyId,
  int newLevel,
) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/garden/levelup'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'family_id': familyId,
        'new_level': newLevel,
      }),
    );

    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}
// для даты последней синхронизации члена
static Future<Map<String, dynamic>?> getFamilyMemberStatus(
  String familyId,
) async {
  try {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/family_member_status?family_id=$familyId',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  } catch (_) {}

  return null;
}


static Future<Map<String, dynamic>?> getFamilyDailyStats(String familyId, String date) async {
  try {
    final response = await http.get(
      Uri.parse("$baseUrl/family_daily_stats?family_id=$familyId&date=$date"),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  } catch (e) {
  debugPrint("FAMILY_DAILY_STATS ERROR: $e");
  }
  return null;
}


static Future<Map<String, dynamic>?> getPersonalAchievements(
  String familyId,
) async {
  final response = await http.get(
    Uri.parse(
      "$baseUrl/personal_achievements?family_id=$familyId",
    ),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }

  return null;
}



static Future<Map<String, dynamic>?> getLatestVersion() async {

  try {

    final response =
        await http.get(
      Uri.parse(
        "$baseUrl/latest_version",
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        response.body,
      );
    }

  } catch (_) {}

  return null;
}


static Future<bool> createTask({
  required String familyId,
  required String title,
  required int stars,
  required String createdBy,
  required String assignedTo,
  required String repeatMode,
}) async {
  final response = await http.post(
    Uri.parse("$baseUrl/tasks/create"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "family_id": familyId,
      "title": title,
      "stars": stars,
      "created_by": createdBy,
      "assigned_to": assignedTo,
      "repeat_mode": repeatMode,
    }),
  );
  return response.statusCode == 200;
}

static Future<List<dynamic>?> getTasks(
  String familyId,
  String? userName,
) async {
  try {
    String url = "$baseUrl/tasks?family_id=$familyId";
    if (userName != null) {
      url += "&user_name=${Uri.encodeComponent(userName)}";
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["tasks"] ?? [];
    }
    return null;
  } catch (_) {
    return null;
  }
}

static Future<bool> markTaskDone(
  int taskId,
  String userName,
) async {

  final response = await http.post(
    Uri.parse("$baseUrl/tasks/done"),
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "task_id": taskId,
      "user_name": userName,
    }),
  );

  return response.statusCode == 200;
}


static Future<Map<String, dynamic>> getChildBalance(
  String familyId,
  String userName,
) async {
  try {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/child_balance"
        "?family_id=$familyId"
        "&user_name=${Uri.encodeComponent(userName)}",
      ),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return {"stars": 0};
  } catch (_) {
    return {"stars": 0};
  }
}

static Future<bool> approveTask(
  int taskId,
  String userName,
) async {

  final response = await http.post(
    Uri.parse("$baseUrl/tasks/approve"),
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "task_id": taskId,
      "user_name": userName,
    }),
  );

  return response.statusCode == 200;
}


static Future<bool> retryTask(
  int taskId,
  String userName,
) async {

  final response = await http.post(
    Uri.parse(
      "$baseUrl/tasks/retry",
    ),
    headers: {
      "Content-Type":
          "application/json",
    },
    body: jsonEncode({
      "task_id": taskId,
      "user_name": userName,
    }),
  );

  return response.statusCode == 200;
}


static Future<bool> deleteTask(
  int taskId,
  String userName,
) async {

  final response = await http.post(
    Uri.parse(
      "$baseUrl/tasks/delete",
    ),
    headers: {
      "Content-Type":
          "application/json",
    },
    body: jsonEncode({
      "task_id": taskId,
      "user_name": userName,
    }),
  );

  return response.statusCode == 200;
}

static Future<bool> rejectTask(
  int taskId,
  String userName,
) async {

  final response = await http.post(
    Uri.parse("$baseUrl/tasks/reject"),
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "task_id": taskId,
      "user_name": userName,
    }),
  );

  return response.statusCode == 200;
}



static Future<Map<String, dynamic>?> getAchievementProgress(
  String familyId,
  String achievementKey, {
  String? userName,
}) async {
  try {
    String url = "$baseUrl/achievement_progress?family_id=$familyId&achievement_key=$achievementKey";
    if (userName != null) {
      url += "&user_name=${Uri.encodeComponent(userName)}";
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  } catch (e) {
    debugPrint("ACHIEVEMENT PROGRESS ERROR: $e");
  }
  return null;
}

static Future<List<dynamic>?> getAchievementProgressAll(
  String familyId,
  String userName,
) async {
  try {
    final uri = Uri.parse("$baseUrl/achievement_progress_all").replace(
      queryParameters: {
        "family_id": familyId,
        "user_name": userName,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;

    final list = decoded["achievements"];
    if (list is! List) return null;

    return list;
  } catch (_) {
    return null;
  }
}

static Future<List<dynamic>?> getRewardShop(String familyId) async {
  try {
    final response = await http.get(Uri.parse("$baseUrl/reward_shop?family_id=$familyId")).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["items"] ?? [];
    }
    return null;
  } catch (_) {
    return null;
  }
}

static Future<bool> createReward(String familyId, String title, String emoji, int costStars, {String colorHex = "#FFF4E5", String description = ""}) async {
  final response = await http.post(
    Uri.parse("$baseUrl/reward_shop/create"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "family_id": familyId, "title": title, "emoji": emoji,
      "cost_stars": costStars, "color_hex": colorHex, "description": description,
    }),
  );
  return response.statusCode == 200;
}

static Future<bool> updateReward(int id, String title, String emoji, int costStars, {String colorHex = "#FFF4E5", String description = ""}) async {
  final response = await http.post(
    Uri.parse("$baseUrl/reward_shop/update"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "id": id, "title": title, "emoji": emoji,
      "cost_stars": costStars, "color_hex": colorHex, "description": description,
    }),
  );
  return response.statusCode == 200;
}

static Future<bool> deleteReward(int rewardId) async {
  final response = await http.post(
    Uri.parse("$baseUrl/reward_shop/delete"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"reward_id": rewardId}),
  );
  return response.statusCode == 200;
}

static Future<bool> buyReward(
  String familyId,
  String childName,
  int rewardId,
) async {
  try {
    final response = await http.post(
      Uri.parse("$baseUrl/reward_shop/buy"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "family_id": familyId,
        "child_name": childName,
        "reward_id": rewardId,
      }),
    );

    if (response.statusCode != 200) return false;

final data = jsonDecode(response.body);

if (data["status"] == "ok") {
  return true;
}

return false;
  } catch (e) {
    return false;
  }
}




static Future<List<dynamic>?> getRewardRequests(
  String familyId,
) async {
  try {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/reward_requests?family_id=$familyId",
      ),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return null;
    }

    final list = decoded["requests"];
    if (list is! List) {
      return null;
    }

    return list;
  } catch (_) {
    return null;
  }
}

static Future<bool> approveReward(
  int requestId,
) async {

  final response = await http.post(
    Uri.parse("$baseUrl/reward_requests/approve"),
    headers:{
      "Content-Type":"application/json",
    },
    body: jsonEncode({
      "request_id":requestId,
    }),
  );

  return response.statusCode==200;
}


static Future<bool> confirmReward(
  int requestId,
) async {

  final response = await http.post(
    Uri.parse("$baseUrl/reward_requests/confirm"),
    headers:{
      "Content-Type":"application/json",
    },
    body: jsonEncode({
      "request_id":requestId,
    }),
  );

  return response.statusCode==200;
}

static Future<bool> rejectReward(int requestId) async {
  final response = await http.post(
    Uri.parse("$baseUrl/reward_requests/reject"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"request_id": requestId}),
  );
  return response.statusCode == 200;
}


static Future<bool> uploadAvatar({
  required String familyId,
  required String userName,
  required String filePath,
}) async {
  try {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload_avatar'),
    );
    request.fields['family_id'] = familyId;
    request.fields['user_name'] = userName;
    request.files.add(await http.MultipartFile.fromPath('avatar', filePath));

    final response = await request.send();
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}


static Future<bool> updateMember(
  String familyId,
  String oldName,
  String newName,
  String deviceId,
) async {

  final response =
      await http.post(
    Uri.parse(
      "$baseUrl/update_member",
    ),
    headers: {
      "Content-Type":
          "application/json",
    },
    body: jsonEncode({
      "family_id": familyId,
      "old_name": oldName,
      "new_name": newName,
      "device_id": deviceId,
    }),
  );

  if (response.statusCode != 200) {
    return false;
  }

  final data =
      jsonDecode(response.body);

  return data["status"] == "ok";
}
  
}