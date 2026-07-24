import 'package:flutter/services.dart';

class SyncServiceHelper {

  static const MethodChannel _channel =
      MethodChannel(
    'family_focus/sync_service',
  );

  static Future<void> start(String userId, String familyId, {String role = ""}) async {
  try {
    await _channel.invokeMethod('startSyncService', {
      'userId': userId,
      'familyId': familyId,
      'role': role,
    });
  } catch (e) {
    print('START SYNC SERVICE ERROR: $e');
  }
}

  

  static Future<void> stop() async {

    try {

      await _channel.invokeMethod(
        'stopSyncService',
      );

    } catch (e) {

      print(
        'STOP SYNC SERVICE ERROR: $e',
      );
    }
  }

  static Future<String?> getDeviceId() async {
    try {
      return await _channel.invokeMethod('getDeviceId');
    } catch (e) {
      return null;
    }
  }

}