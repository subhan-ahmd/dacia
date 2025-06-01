import 'dart:async';
import 'package:dacia/providers/loading_provider.dart';
import 'package:dacia/providers/obd2_service.dart';
import 'package:dacia/providers/selected_device_provider.dart';
import 'package:dacia/utils/toast_manager.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connected_devices_provider.g.dart';

@riverpod
class ConnectedDevices extends _$ConnectedDevices {
  final Set<String> _connectedDeviceIds = {};
  BluetoothConnection? _connection;
  bool isConnecting = false;

  @override
  FutureOr<Set<String>> build() {
    return _connectedDeviceIds;
  }

  bool isDeviceConnected({String? id}) {
    final deviceId = id ?? ref.read(selectedDeviceProvider)?.address ?? "";
    return _connection?.isConnected ?? false && _connectedDeviceIds.contains(deviceId);
  }

  Set<String> get connectedDevices => _connectedDeviceIds;

  Future<void> checkAndConnect() async {
    if (ref.read(selectedDeviceProvider) != null) {
      if (!isDeviceConnected()) {
        if (!isConnecting) {
          isConnecting = true;
          await connect();
          isConnecting = false;
        }
      }
    }
  }

  Future<void> connect() async {
    final deviceAddress = ref.read(selectedDeviceProvider)?.address ?? "";
    ref.read(loadingProvider(deviceAddress).notifier).toggle(true);
    ToastManager.show("Connecting to $deviceAddress");

    try {
      if (!isDeviceConnected()) {
        _connection = await BluetoothConnection.toAddress(deviceAddress);

        // Listen for disconnection
        _connection!.input!.listen((data) {
          // Handle incoming data if needed
        }).onDone(() {
          _connectedDeviceIds.remove(deviceAddress);
          state = AsyncData(Set<String>.from(_connectedDeviceIds));
          _connection = null;
        });

        _connectedDeviceIds.add(deviceAddress);
        state = AsyncData(Set<String>.from(_connectedDeviceIds));

        if (isDeviceConnected()) {
          ref.read(oBD2ServiceProvider.notifier).subscribeToData();
        }
      } else {
        throw "Already Connected";
      }
    } catch (e) {
      ToastManager.show("Error: $e");
      _connection = null;
    }

    if (isDeviceConnected()) {
      ToastManager.show("Connected to $deviceAddress");
    }
    ref.read(loadingProvider(deviceAddress).notifier).toggle(false);
  }

  Future<void> disconnect() async {
    if (ref.read(selectedDeviceProvider) != null) {
      final deviceAddress = ref.read(selectedDeviceProvider)?.address ?? "";

      await _connection?.close();
      _connection = null;

      if (_connectedDeviceIds.contains(deviceAddress)) {
        _connectedDeviceIds.remove(deviceAddress);
        state = AsyncData(Set<String>.from(_connectedDeviceIds));
      }

      ToastManager.show("Disconnected from $deviceAddress");
      ref.read(selectedDeviceProvider.notifier).clear();
    }
  }
}