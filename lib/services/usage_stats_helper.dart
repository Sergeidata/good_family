import 'dart:async';
import 'package:flutter/services.dart';

class UsageStatsHelper {
  static const MethodChannel _channel = MethodChannel(
    'family_focus/usage_stats',
  );

  static const List<String> excludedPrefixes = [
    "com.android.",
    "com.samsung.",
    "com.sec.",
    "com.sony.",
    "com.oppo.",
    "com.xiaomi.",
    "com.mi.",
    "com.coloros.",
    "com.huawei.",
    "com.bbk."
  ];

  static const List<String> excludedPackages = [
    "com.android.systemui",
    "com.huawei.android.launcher",
    "com.sec.android.app.launcher",
    "com.miui.home",
    "com.oppo.launcher",
  ];


  static const socialPackages = {
  "com.instagram.android",
  "com.facebook.katana",
  "com.facebook.orca",
  "com.vkontakte.android",
  "com.twitter.android",
  "com.ss.android.ugc.trill",
  "com.zhiliaoapp.musically",
  "com.snapchat.android",
  "com.linkedin.android",
  "com.pinterest",
  "com.reddit.frontpage",
};

static int getSocialSeconds(Map<String, int> apps) {
  int total = 0;
  for (final entry in apps.entries) {
    if (socialPackages.contains(entry.key)) {
      total += entry.value;
    }
  }
  return total;
}

  static Future<bool> hasPermission() async {
    try {
      final bool result = await _channel.invokeMethod(
        'hasPermission',
      );

      return result;
    } catch (e) {
      print("HAS_PERMISSION ERROR: $e");
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod(
        'requestPermission',
      );
    } catch (e) {
      print("REQUEST_PERMISSION ERROR: $e");
    }
  }

  static Future<Map<String, int>> getScreenTimeToday() async {
    return await _getUsageStats("today");
  }

  static Future<Map<String, int>> getScreenTimeYesterday() async {
    return await _getUsageStats("yesterday");
  }

  static Future<Map<String, int>> getScreenTimeWeek() async {
    return await _getUsageStats("week");
  }

  static Future<Map<String, int>> _getUsageStats(
    String period,
  ) async {
    try {
      final Map<dynamic, dynamic> result =
          await _channel.invokeMethod(
        'getUsageStats',
        {
          "period": period,
          "excluded_prefixes": excludedPrefixes,
          "excluded_packages": excludedPackages,
        },
      );

      final Map<String, int> parsed = {};

      result.forEach((key, value) {
        parsed[key.toString()] = value as int;
      });

      return parsed;
    } catch (e) {

      return {};
    }
  }
}