import 'dart:async';
import 'package:dacia/providers/loading_provider.dart';
import 'package:dacia/utils/toast_manager.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connected_devices_provider.g.dart';

@riverpod
class ConnectedDevices extends _$ConnectedDevices {
  static String deviceId =
      "DC:0D:30:DA:D9:C9"; // MARIO'S
      // "08:A6:F7:47:56:72"; //ESP32
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final Set<String> _connectedDeviceIds = {};
  StreamSubscription? _connectionSubscription;
  final Map<String, StreamSubscription> _deviceConnections = {};
  bool isConnecting = false;

  @override
  FutureOr<Set<String>> build() {
    _initialize();

    ref.onDispose(() {
      _connectionSubscription?.cancel();
      for (final subscription in _deviceConnections.values) {
        subscription.cancel();
      }
    });

    return _connectedDeviceIds;
  }

  Future<void> _initialize() async {
    _connectionSubscription =
        _ble.connectedDeviceStream.listen((connectionStateUpdate) {
      if (connectionStateUpdate.connectionState ==
          DeviceConnectionState.connected) {
        _connectedDeviceIds.add(connectionStateUpdate.deviceId);
      } else if (connectionStateUpdate.connectionState ==
          DeviceConnectionState.disconnected) {
        _connectedDeviceIds.remove(connectionStateUpdate.deviceId);
      }
      state = AsyncData(Set<String>.from(_connectedDeviceIds));
    });
  }

  bool isDeviceConnected() => _connectedDeviceIds.contains(deviceId);

  Set<String> get connectedDevices => _connectedDeviceIds;

  void storeConnectionSubscription(
    String deviceId,
    StreamSubscription subscription,
  ) {
    _deviceConnections[deviceId]?.cancel();
    _deviceConnections[deviceId] = subscription;
  }

  Future<void> checkAndConnect() async {
    if (!isDeviceConnected()) {
      if(!isConnecting){
        isConnecting = true;
        await connect();
        isConnecting = false;
      }
    }
  }

  Future<void> connect() async {
    ref.read(loadingProvider(deviceId).notifier).toggle(true);
    ToastManager.show("Connecting to $deviceId");
    try {
      final completer = Completer<void>();
      if (!ref.read(connectedDevicesProvider.notifier).isDeviceConnected()) {
        final subscription = FlutterReactiveBle()
            .connectToDevice(
          id: deviceId,
          connectionTimeout: const Duration(seconds: 35),
        )
            .listen(
          (connectionState) async {
            if (connectionState.connectionState ==
                DeviceConnectionState.connected) {
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          },
          onError: (error, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error);
              throw error;
            }
          },
        );
        ref
            .read(connectedDevicesProvider.notifier)
            .storeConnectionSubscription(deviceId, subscription);
      } else {
        if (!completer.isCompleted) {
          completer.completeError("Already Connected");
        }
        throw "Already Connected";
      }
      await completer.future;
      //check device info
    } catch (e) {
      ToastManager.show("Error: $e");
    }
    if (ref.read(connectedDevicesProvider.notifier).isDeviceConnected()) {
      ToastManager.show("Connected to $deviceId");
    }
    ref.read(loadingProvider(deviceId).notifier).toggle(false);
  }

  Future<void> disconnect() async {
    _deviceConnections[deviceId]?.cancel();
    _deviceConnections.remove(deviceId);

    if (_connectedDeviceIds.contains(deviceId)) {
      _connectedDeviceIds.remove(deviceId);
      state = AsyncData(Set<String>.from(_connectedDeviceIds));
    }
      ToastManager.show("Disconnected from $deviceId");
  }
}
