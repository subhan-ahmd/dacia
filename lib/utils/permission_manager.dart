import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionManager {
  static Future<bool> check() async {
    Map<Permission, PermissionStatus> statuses;

    if (Platform.isAndroid) {
      if (await _getAndroidVersion() >= 31) {
        statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
      } else {
        statuses = await [
          Permission.bluetooth,
          Permission.location,
        ].request();
      }
    } else if (Platform.isIOS) {
      statuses = await [Permission.bluetooth].request();
    } else {
      return false;
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
    if (!Platform.isAndroid) return 0;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt;
  }
}