import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'available_devices.g.dart';

@Riverpod(keepAlive: true)
class DeviceManager extends _$DeviceManager {
  StreamSubscription? _scanSubscription;
  final Map<String, DiscoveredDevice> _discoveredDevices = {};

  @override
  List<DiscoveredDevice> build() {
    final List<DiscoveredDevice> bleDevices = [];
    _startScan();
    ref.onDispose(() {
      _scanSubscription?.cancel();
    });

    return bleDevices;
  }

  void _startScan() {
    try {
      state = [];
      _scanSubscription = FlutterReactiveBle().scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen((device) {
        if (_discoveredDevices[device.id] == null) {
          _discoveredDevices[device.id] = device;
          state = _discoveredDevices.values.toList();
        }
      });
    } catch (e, s) {
      debugPrint("$e\n$s");
    }
  }

  void refreshScan() {
    _scanSubscription?.cancel();
    _startScan();
  }
}
