import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'available_devices.g.dart';

@Riverpod(keepAlive: true)
class DeviceManager extends _$DeviceManager {
  StreamSubscription? _scanSubscription;
  final Map<String, DiscoveredDevice> _discoveredDevices = {};

  // Replace stream controllers with simple lists

  @override
  List<DiscoveredDevice> build() {
    print("DeviceManager build");

    final List<DiscoveredDevice> bleDevices = [];
    _startScan();
    ref.onDispose(() {
      print("DeviceManager dispose");
      _scanSubscription?.cancel();
    });

    return bleDevices;
  }

  void _startScan() {
    try {
      print("Starting scan");
      state = [];
      _scanSubscription = FlutterReactiveBle().scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen((device) {
        if (_discoveredDevices[device.id] == null) {
          print("Device found: $device");
          _discoveredDevices[device.id] = device;
          state = _discoveredDevices.values.toList();
        }
      });
    } catch (e, s) {
      print("Scan error: $e\n$s");
    }
  }

  void refreshScan() {
    print("Refreshing scan");
    _scanSubscription?.cancel();
    _startScan();
  }
}
