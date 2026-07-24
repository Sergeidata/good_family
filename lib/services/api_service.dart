import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';

class ApiService {
  static const String baseUrl =
      "http://159.194.219.146:8000";

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
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/create_family"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "family_name": familyName,
          "user_name": userName,
          "device_id": deviceId,
          "role": role,
          "avatar": avatar,
        }),
      ).timeout(
        const Duration(seconds: 5),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print("CREATE FAMILY ERROR: $e");
      return null;
    }
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
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/join_family"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
  "invite_code": inviteCode,
  "user_name": userName,
  "device_id": deviceId,
  "role": role,
  "avatar": avatar,
}),
      ).timeout(
        const Duration(seconds: 5),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print("JOIN FAMILY ERROR: $e");
      return null;
    }
  }
  // удаление членов
  static Future<bool> removeMember(
    String familyId,
    String userName,
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
          'user_name': userName,
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
      print("SYNC ERROR: $e");
      return null;
    }
  }

  // ---------------------------------
  // GET FAMILY MEMBERS
  // ---------------------------------
  static Future<Map<String, dynamic>?> getMembers(
    String familyId,
  ) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/family_members",
      ).replace(
        queryParameters: {
          "family_id": familyId,
        },
      );

      final response = await http.get(
        uri,
      ).timeout(
        const Duration(seconds: 5),
      );

      final data = jsonDecode(response.body);

      print("GET MEMBERS RAW: $data");

      return data;
    } catch (e) {
      print("GET MEMBERS ERROR: $e");
      return null;
    }
  }

  // ---------------------------------
  // GET USER STATS
  // ---------------------------------
  static Future<Map<String, dynamic>?> getStats(String userId, String period) async {
  final url = Uri.parse("$baseUrl/stats?user_id=${Uri.encodeComponent(userId)}&period=$period");
  
  for (int i = 0; i < 3; i++) {
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (i == 2) return null;
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

static Future<List<dynamic>> getAchievements(
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
    return [];
  } catch (e) {
    return [];
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
  print("FAMILY_DAILY_STATS ERROR: $e");
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

static Future<Map<String, dynamic>?> getDashboard(
  String familyId,
  String userName,
) async {
  try {
    final response = await http.get(
      Uri.parse("$baseUrl/dashboard?family_id=$familyId&user_name=$userName"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  } catch (e) {
    return null;
  }
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

static Future<List<dynamic>> getTasks(
  String familyId,
  String? userName,
) async {

  String url =
      "$baseUrl/tasks?family_id=$familyId";

  if (userName != null) {
    url += "&user_name=${Uri.encodeComponent(userName)}";
  }

  final response =
      await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body)["tasks"] ?? [];
  }

  return [];
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
  final response = await http.get(
    Uri.parse(
      "$baseUrl/child_balance"
      "?family_id=$familyId"
      "&user_name=${Uri.encodeComponent(userName)}",
    ),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }

  return {"balances": [], "pending_payouts": []};
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


static Future<List<dynamic>> getPayouts(String familyId, String childName) async {
  try {
    final response = await http.get(
      Uri.parse("$baseUrl/payouts?family_id=$familyId&child_name=${Uri.encodeComponent(childName)}"),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["payouts"] ?? [];
    }
  } catch (e) {
    print("GET PAYOUTS ERROR: $e");
  }
  return [];
}

static Future<bool> createPayout(
  String familyId,
  String childName, {
  List<int>? rewardTypeIds,
}) async {
  try {
    final response = await http.post(
      Uri.parse("$baseUrl/payouts/create"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "family_id": familyId,
        "child_name": childName,
        if (rewardTypeIds != null)
          "reward_type_ids": rewardTypeIds,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["status"] == "ok";
    }
  } catch (e) {
    print(e);
  }

  return false;
}

static Future<bool> confirmPayout(
  int payoutId,
  String userName,
) async {
  try {
    final response = await http.post(
      Uri.parse("$baseUrl/payouts/confirm"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "payout_id": payoutId,
        "user_name": userName,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["status"] == "ok";
    }
  } catch (e) {
    print(e);
  }

  return false;
}


static Future<bool> cancelPayout(
  int payoutId,
) async {
  try {
    final response = await http.post(
      Uri.parse("$baseUrl/payouts/cancel"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "payout_id": payoutId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["status"] == "ok";
    }
  } catch (e) {
    print(e);
  }

  return false;
}

static Future<List<dynamic>> getRewardTypes(
    String familyId,
) async {

  final response = await http.get(

    Uri.parse(
      "$baseUrl/reward_types?family_id=$familyId",
    ),

  );

  if (response.statusCode != 200) {
    return [];
  }

  return jsonDecode(
    response.body,
  )["types"];
}

static Future<int?> createRewardType(

    String familyId,
    String name,

) async {

  final response=await http.post(

    Uri.parse(
      "$baseUrl/reward_types/create",
    ),

    headers:{
      "Content-Type":"application/json",
    },

    body:jsonEncode({

      "family_id":familyId,
      "name":name,

    }),

  );

  if(response.statusCode!=200){
    return null;
  }

  return jsonDecode(response.body)["reward_type_id"];
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