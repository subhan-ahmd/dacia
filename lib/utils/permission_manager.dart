import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionManager {
  static Future<bool> check() async {
    Map<Permission, PermissionStatus> statuses;

    if (await _getAndroidVersion() >= 31) {
      // Android 12 (API level 31) and above
      statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();
    } else {
      // Android 11 (API level 30) and below
      statuses = await [
        Permission.bluetooth,
        Permission.location,
      ].request();
    }

    bool allGranted = !statuses.values.any(
      (status) => status != PermissionStatus.granted,
    );

    if (!allGranted) {
      debugPrint('Some permissions were denied: $statuses');
    }

    return allGranted;
  }

  static Future<int> _getAndroidVersion() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt;
  }

  // Helper method to check if all required permissions are granted
  static Future<bool> arePermissionsGranted() async {
    if (await _getAndroidVersion() >= 31) {
      return await Permission.bluetoothScan.isGranted &&
             await Permission.bluetoothConnect.isGranted &&
             await Permission.bluetoothAdvertise.isGranted &&
             await Permission.location.isGranted;
    } else {
      return await Permission.bluetooth.isGranted &&
             await Permission.location.isGranted;
    }
  }
}