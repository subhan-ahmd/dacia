// lib/providers/obd2_service_provider.dart
import 'package:dacia/providers/obd2_data.dart';
import 'package:dacia/providers/selected_device_provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'obd2_service.g.dart';

@riverpod
class OBD2Service extends _$OBD2Service {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription? _subscription;

  late final String serviceUuid = "e7810a71-73ae-499d-8c15-faa9aef0c3f2";
  late final String characteristicUuid = "bef8d6c9-9c21-4c9e-b632-bd58c1009f9f";

  @override
  void build() {}

  // Read data from the device
  Future<void> readData() async {
    try {
      await _ble.readCharacteristic(
        QualifiedCharacteristic(
          deviceId: ref.read(selectedDeviceProvider)!.id,
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(characteristicUuid),
        ),
      );
    } catch (e) {
      print('Error reading data: $e');
    }
  }

  // Send command to the device
  Future<void> sendCommand(String command) async {
    try {
      // Convert command to bytes
      List<int> commandBytes = command.codeUnits;

      await _ble.writeCharacteristicWithResponse(
        QualifiedCharacteristic(
          deviceId: ref.read(selectedDeviceProvider)!.id,
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(characteristicUuid),
        ),
        value: commandBytes,
      );
    } catch (e) {
      print('Error sending command: $e');
    }
  }

  // Subscribe to characteristic updates
  void subscribeToData() {
    _subscription = _ble
        .subscribeToCharacteristic(
          QualifiedCharacteristic(
            deviceId: ref.read(selectedDeviceProvider)!.id,
            serviceId: Uuid.parse(serviceUuid),
            characteristicId: Uuid.parse(characteristicUuid),
          ),
        )
        .listen(
          (data) {
            final parsedData = parseData(data);
            if (parsedData.isNotEmpty) {
              ref.read(oBD2DataProvider.notifier).updateData(parsedData);
            }
          },
          onError: (dynamic error) {
            print('Error: $error');
          },
          cancelOnError: false,
        );
  }

  // Parse the received data
  Map<String, dynamic> parseData(List<int> data) {
    if (data.length < 4) return {}; // Minimum length for a CAN message

    // Extract SID from the first bytes
    String sid = data
        .sublist(0, 3)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    // Extract the data payload
    String hexData = data
        .sublist(3)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    // Get current state to maintain other values
    final currentState = ref.read(oBD2DataProvider);
    Map<String, dynamic> parsedData = Map<String, dynamic>.from(currentState);

    switch (sid) {
      case '42e0': // SoC
        parsedData['soc'] = _parseSoC(hexData);
        break;
      case '7ec62320324': // Battery voltage
        parsedData['voltage'] = _parseVoltage(hexData);
        break;
      case '5d70': // Speed
        parsedData['speed'] = _parseSpeed(hexData);
        break;
    }

    return parsedData;
  }

  // Helper methods to parse specific data types
  double _parseSoC(String hexData) {
    if (hexData.isEmpty) return 0.0;
    int value = int.parse(hexData, radix: 16);
    return value / 100.0; // Convert to percentage
  }

  double _parseVoltage(String hexData) {
    if (hexData.isEmpty) return 0.0;
    int value = int.parse(hexData, radix: 16);
    return value.toDouble(); // Voltage in volts
  }

  double _parseSpeed(String hexData) {
    if (hexData.isEmpty) return 0.0;
    int value = int.parse(hexData, radix: 16);
    return value.toDouble(); // Speed in km/h
  }
}