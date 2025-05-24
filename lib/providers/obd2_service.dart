import 'dart:convert';
import 'dart:typed_data';

import 'package:dacia/providers/obd2_data.dart';
import 'package:dacia/providers/selected_device_provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/material.dart';

part 'obd2_service.g.dart';

void printPrettyJson(dynamic jsonData) {
  try {
    final String jsonString =
        jsonData is String ? jsonData : jsonEncode(jsonData);
    final dynamic decodedJson = jsonDecode(jsonString);
    final String prettyJson =
        const JsonEncoder.withIndent('  ').convert(decodedJson);
    debugPrint('┌─────────── JSON ───────────┐');
    prettyJson.split('\n').forEach((line) => debugPrint('│ $line'));
    debugPrint('└─────────────────────────────┘');
  } catch (e) {
    debugPrint('Error formatting JSON: $e');
    debugPrint('Original data: $jsonData');
  }
}

@riverpod
class OBD2Service extends _$OBD2Service {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription? _subscription;
  bool _isInitialized = false;
  Timer? _dataRequestTimer;

  // These UUIDs should be discovered from your device
  late final String serviceUuid = "e7810a71-73ae-499d-8c15-faa9aef0c3f2";
  late final String characteristicUuid = "bef8d6c9-9c21-4c9e-b632-bd58c1009f9f";

  @override
  void build() {}

  // Initialize the ELM327 device
  Future<void> initializeDevice() async {
    if (_isInitialized) return;

    try {
      ref.read(oBD2DataProvider.notifier).setConnectionStatus('Initializing...');

      // Enable notifications
      await _ble.writeCharacteristicWithResponse(
        QualifiedCharacteristic(
          deviceId: ref.read(selectedDeviceProvider)!.id,
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(characteristicUuid),
        ),
        value: Uint8List.fromList([0x01, 0x00]), // Enable notifications
      );

      // Send initialization commands
      await _sendCommand('ATE0'); // No echo
      await _sendCommand('ATS0'); // No spaces
      await _sendCommand('ATSP6'); // CAN 500K 11 bit
      await _sendCommand('ATAT1'); // Auto timing
      await _sendCommand('ATCAF0'); // No formatting
      await _sendCommand('ATFCSh77B'); // Flow control response ID
      await _sendCommand('ATFCSD300010'); // Flow control response data
      await _sendCommand('ATFCSM1'); // Flow control mode 1

      _isInitialized = true;
      ref.read(oBD2DataProvider.notifier).setConnectionStatus('Connected');
      ref.read(oBD2DataProvider.notifier).setError(null);
      print('Device initialized successfully');
    } catch (e) {
      _isInitialized = false;
      ref.read(oBD2DataProvider.notifier).setConnectionStatus('Error');
      ref.read(oBD2DataProvider.notifier).setError('Failed to initialize device: $e');
      print('Error initializing device: $e');
    }
  }

  // Send command to the device
  Future<void> _sendCommand(String command) async {
    try {
      final commandBytes = Uint8List.fromList('$command\r'.codeUnits);
      await _ble.writeCharacteristicWithResponse(
        QualifiedCharacteristic(
          deviceId: ref.read(selectedDeviceProvider)!.id,
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(characteristicUuid),
        ),
        value: commandBytes,
      );
      // Wait for response
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('Error sending command: $e');
      ref.read(oBD2DataProvider.notifier).setError('Failed to send command: $e');
      rethrow;
    }
  }

  // Request specific data from the device
  Future<void> requestData(String pid) async {
    if (!_isInitialized) {
      await initializeDevice();
    }

    try {
      await _sendCommand(pid); // Send the PID directly without mode prefix
    } catch (e) {
      print('Error requesting data: $e');
      ref.read(oBD2DataProvider.notifier).setError('Failed to request data: $e');
    }
  }

  // Subscribe to characteristic updates
  void subscribeToData() async {
    if (!_isInitialized) {
      await initializeDevice();
    }

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
            print('Raw data received: ${data.toList()}');
            final parsedData = parseData(data);
            if (parsedData.isNotEmpty) {
              ref.read(oBD2DataProvider.notifier).updateData(parsedData);
            }
          },
          onError: (dynamic error) {
            print('Error in subscription: $error');
            _isInitialized = false;
            ref.read(oBD2DataProvider.notifier).setError('Subscription error: $error');
            ref.read(oBD2DataProvider.notifier).setConnectionStatus('Error');
          },
          cancelOnError: false,
        );

    // Start periodic data requests
    _dataRequestTimer?.cancel();
    _dataRequestTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isInitialized) return;

      try {
        // Request Spring-specific data points
        await requestData('229002'); // Battery SoC
        await requestData('229005'); // Battery Voltage
        await requestData('222003'); // Vehicle Speed
        await requestData('229012'); // Battery Temperature
        await requestData('22900D'); // Battery Current
      } catch (e) {
        print('Error in periodic data request: $e');
        ref.read(oBD2DataProvider.notifier).setError('Periodic request error: $e');
      }
    });
  }

  // Parse the received data
  Map<String, dynamic> parseData(List<int> data) {
    if (data.isEmpty) return {};

    try {
      // Convert data to hex string
      String hexData = data
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();

      // Get current state to maintain other values
      final currentState = ref.read(oBD2DataProvider);
      Map<String, dynamic> parsedData = Map<String, dynamic>.from(currentState);
      parsedData["raw"] = hexData;

      // Check for error response
      if (hexData.startsWith('7F')) {
        print('Error response received: $hexData');
        ref.read(oBD2DataProvider.notifier).setError('Device error: $hexData');
        return parsedData;
      }

      // Parse based on the PID
      if (hexData.contains('229002')) {
        // Battery SoC
        parsedData['soc'] = _parseSoC(hexData);
      } else if (hexData.contains('229005')) {
        // Battery Voltage
        parsedData['voltage'] = _parseVoltage(hexData);
      } else if (hexData.contains('222003')) {
        // Vehicle Speed
        parsedData['speed'] = _parseSpeed(hexData);
      } else if (hexData.contains('229012')) {
        // Battery Temperature
        parsedData['temperature'] = _parseTemperature(hexData);
      } else if (hexData.contains('22900D')) {
        // Battery Current
        parsedData['current'] = _parseCurrent(hexData);
      }

      return parsedData;
    } catch (e) {
      print('Error parsing data: $e');
      ref.read(oBD2DataProvider.notifier).setError('Data parsing error: $e');
      return {};
    }
  }

  // Helper methods to parse specific data types
  double _parseSoC(String hexData) {
    if (hexData.isEmpty) return 0.0;
    // Extract the value after the PID
    String value = hexData.split('229002')[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 0.01; // Convert to percentage (0-100)
  }

  double _parseVoltage(String hexData) {
    if (hexData.isEmpty) return 0.0;
    String value = hexData.split('229005')[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 0.1; // Convert to volts
  }

  double _parseSpeed(String hexData) {
    if (hexData.isEmpty) return 0.0;
    String value = hexData.split('222003')[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 0.01; // Convert to km/h
  }

  double _parseTemperature(String hexData) {
    if (hexData.isEmpty) return 0.0;
    String value = hexData.split('229012')[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 0.0625; // Convert to °C
  }

  double _parseCurrent(String hexData) {
    if (hexData.isEmpty) return 0.0;
    String value = hexData.split('22900D')[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 0.025; // Convert to amperes
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dataRequestTimer?.cancel();
    ref.read(oBD2DataProvider.notifier).setConnectionStatus('Disconnected');
  }
}