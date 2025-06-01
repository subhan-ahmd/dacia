import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'available_devices.g.dart';

@Riverpod(keepAlive: true)
class DeviceManager extends _$DeviceManager {
  @override
  Future<List<BluetoothDevice>> build() {
    return FlutterBluetoothSerial.instance.getBondedDevices();
  }
}