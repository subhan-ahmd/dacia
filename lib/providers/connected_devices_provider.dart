import 'dart:async';
import 'package:dacia/providers/loading_provider.dart';
import 'package:dacia/providers/obd2_service.dart';
import 'package:dacia/providers/selected_device_provider.dart';
import 'package:dacia/utils/toast_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connected_devices_provider.g.dart';

@riverpod
class ConnectedDevices extends _$ConnectedDevices {
  // static String deviceId =
  //     // "DC:0D:30:DA:D9:C9"; // MARIO'S
  //     "08:A6:F7:47:56:72"; //ESP32
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

  bool isDeviceConnected({String? id}) => _connectedDeviceIds.contains(id??(ref.read(selectedDeviceProvider)?.id??""));

  Set<String> get connectedDevices => _connectedDeviceIds;

  void storeConnectionSubscription(
    String deviceId,
    StreamSubscription subscription,
  ) {
    _deviceConnections[deviceId]?.cancel();
    _deviceConnections[deviceId] = subscription;
  }

  Future<void> checkAndConnect() async {
    if(ref.read(selectedDeviceProvider)!=null){
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
    ref.read(loadingProvider(ref.read(selectedDeviceProvider)?.id??"").notifier).toggle(true);
    ToastManager.show("Connecting to ${ref.read(selectedDeviceProvider)?.id??""}");
    try {
      final completer = Completer<void>();
      if (!ref.read(connectedDevicesProvider.notifier).isDeviceConnected()) {
        final subscription = FlutterReactiveBle()
            .connectToDevice(
          id: ref.read(selectedDeviceProvider)?.id??"",
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
            .storeConnectionSubscription(ref.read(selectedDeviceProvider)?.id??"", subscription);
      } else {
        if (!completer.isCompleted) {
          completer.completeError("Already Connected");
        }
        throw "Already Connected";
      }
      await completer.future;
      print("connect");
      if(isDeviceConnected()){
        print("success");
        ref.read(oBD2ServiceProvider.notifier).subscribeToData();
      }
    } catch (e, s) {
      debugPrint("$e\n$s");
      ToastManager.show("Error: $e");
    }
    if (ref.read(connectedDevicesProvider.notifier).isDeviceConnected()) {
      ToastManager.show("Connected to ${ref.read(selectedDeviceProvider)?.id??""}");
    }
    ref.read(loadingProvider(ref.read(selectedDeviceProvider)?.id??"").notifier).toggle(false);
  }

  Future<void> disconnect() async {
    if(ref.read(selectedDeviceProvider)!=null){
      _deviceConnections[ref.read(selectedDeviceProvider)?.id ?? ""]?.cancel();
      _deviceConnections.remove(ref.read(selectedDeviceProvider)?.id ?? "");

      if (_connectedDeviceIds
          .contains(ref.read(selectedDeviceProvider)?.id ?? "")) {
        _connectedDeviceIds.remove(ref.read(selectedDeviceProvider)?.id ?? "");
        state = AsyncData(Set<String>.from(_connectedDeviceIds));
      }
      ToastManager.show(
          "Disconnected from ${ref.read(selectedDeviceProvider)?.id ?? ""}");
      ref.read(selectedDeviceProvider.notifier).clear();
    }
  }
}
