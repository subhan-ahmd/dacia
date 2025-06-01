import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/obd2_data.dart';
import '../providers/selected_device_provider.dart';

part 'obd2_service.g.dart';

@riverpod
class OBD2Service extends _$OBD2Service {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription? _subscription;
  bool _isInitialized = false;
  Timer? _dataRequestTimer;

  // These UUIDs should be discovered from your device
  late final String serviceUuid = "e7810a71-73ae-499d-8c15-faa9aef0c3f2";
  late final String characteristicUuid = "bef8d6c9-9c21-4c9e-b632-bd58c1009f9f";

  // CAN IDs for different controllers
  static const String EVC_CAN_ID = '7ec';  // Electric Vehicle Controller
  static const String LBC_CAN_ID = '7bb';  // Lithium Battery Controller

  // Request PIDs
  static const String PID_BATTERY_VOLTAGE = '229005'; // Pack Voltage CAN value (scale: 0.1 V)
  static const String PID_VEHICLE_SPEED = '222003';   // Vehicle speed (scale: 0.01 km/h)
  static const String PID_BATTERY_TEMP = '222001';    // Battery Rack temperature (scale: 1 °C, offset: 40)
  static const String PID_BATTERY_CURRENT = '22900D'; // Instant Current of Battery (scale: 0.025 A, offset: 48000)

  // Response PIDs
  static const String RESP_BATTERY_VOLTAGE = '629005'; // Response for battery voltage
  static const String RESP_VEHICLE_SPEED = '622003';   // Response for vehicle speed
  static const String RESP_BATTERY_TEMP = '622001';    // Response for battery temperature
  static const String RESP_BATTERY_CURRENT = '62900D'; // Response for battery current

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

      // Send initialization commands with proper delays
      await _sendCommandAndWait('ATZ', 2000); // Reset all - longer delay for reset
      await Future.delayed(Duration(seconds: 1)); // Wait for device to stabilize

      // Basic setup
      await _sendCommandAndWait('ATE0', 200); // No echo
      await _sendCommandAndWait('ATS0', 200); // No spaces
      await _sendCommandAndWait('ATH0', 200); // No headers
      await _sendCommandAndWait('ATL0', 200); // No linefeeds

      // CAN setup
      await _sendCommandAndWait('ATSP6', 200); // CAN 500K 11 bit
      await _sendCommandAndWait('ATAT1', 200); // Auto timing
      await _sendCommandAndWait('ATCAF0', 200); // No formatting

      // Flow control setup
      await _sendCommandAndWait('ATFCSh77B', 200); // Flow control response ID
      await _sendCommandAndWait('ATFCSD300010', 200); // Flow control response data
      await _sendCommandAndWait('ATFCSM1', 200); // Flow control mode 1

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

  // Send command and wait for response
  Future<String> _sendCommandAndWait(String command, int delayMs) async {
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
      await Future.delayed(Duration(milliseconds: delayMs));

      // Get the response
      String response = await _getResponse();
      print('Command: $command, Response: $response');

      // Clean up response - remove CR, LF, > and spaces
      response = response.replaceAll(RegExp(r'[\r\n>]'), '').trim();

      // Log the status but don't throw
      if (response.contains('NO DATA')) {
        print('Warning: No data available for command: $command');
      } else if (response.contains('STOPD')) {
        print('Warning: Device stopped for command: $command');
      } else if (response.contains('?')) {
        print('Warning: Unknown command: $command');
      } else if (!response.contains('OK')) {
        print('Warning: Command did not return OK: $command');
      }

      return response;
    } catch (e) {
      print('Error sending command: $e');
      ref.read(oBD2DataProvider.notifier).setError('Failed to send command: $e');
      return ''; // Return empty string instead of throwing
    }
  }

  // Get response from the device
  Future<String> _getResponse() async {
    // This is a placeholder - you'll need to implement actual response handling
    // based on your BLE communication setup
    return "OK";
  }

  // Request specific data from the device
  Future<void> requestData(String pid, String canId) async {
    if (!_isInitialized) {
      await initializeDevice();
    }

    try {
      // Set the CAN ID using AT SH command
      await _sendCommandAndWait('AT SH $canId', 200);

      // Then send the actual request with proper ISO-TP format
      String request = '0222${pid}'; // Mode 22, PID
      String response = await _sendCommandAndWait(request, 500); // Longer delay for data request

      // Only update data if we got a valid response
      if (response.isNotEmpty && !response.contains('NO DATA') && !response.contains('STOPD')) {
        // Process the response
        // ... rest of your data processing code ...
      }
    } catch (e) {
      print('Error requesting data: $e');
      // Don't set error state, just log it
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
        await requestData(PID_BATTERY_VOLTAGE, LBC_CAN_ID); // Battery Voltage
        await requestData(PID_VEHICLE_SPEED, EVC_CAN_ID);   // Vehicle Speed
        await requestData(PID_BATTERY_TEMP, EVC_CAN_ID);    // Battery Temperature
        await requestData(PID_BATTERY_CURRENT, LBC_CAN_ID); // Battery Current
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
      // Convert data to ASCII string first
      String asciiData = String.fromCharCodes(data);
      print('Received ASCII data: $asciiData');

      // Convert data to hex string
      String hexData = data
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();

      // Get current state to maintain other values
      final currentState = ref.read(oBD2DataProvider);
      Map<String, dynamic> parsedData = Map<String, dynamic>.from(currentState);
      parsedData["raw"] = hexData;

      // Check for error responses
      if (asciiData.contains('NO DATA') || asciiData.contains('STOPD') || asciiData.contains('?')) {
        print('Error response received: $asciiData');
        return parsedData;
      }

      // Parse based on the response PID
      if (hexData.contains(RESP_BATTERY_VOLTAGE)) {
        // Battery Voltage
        parsedData['voltage'] = _parseVoltage(hexData);
      } else if (hexData.contains(RESP_VEHICLE_SPEED)) {
        // Vehicle Speed
        parsedData['speed'] = _parseSpeed(hexData);
      } else if (hexData.contains(RESP_BATTERY_TEMP)) {
        // Battery Temperature
        parsedData['temperature'] = _parseTemperature(hexData);
      } else if (hexData.contains(RESP_BATTERY_CURRENT)) {
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
  double _parseVoltage(String hexData) {
    if (hexData.isEmpty) return 0.0;
    // Extract the value after the response PID
    String value = hexData.split(RESP_BATTERY_VOLTAGE)[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 0.1; // Scale: 0.1 V
  }

  double _parseSpeed(String hexData) {
    if (hexData.isEmpty) return 0.0;
    String value = hexData.split(RESP_VEHICLE_SPEED)[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 0.01; // Scale: 0.01 km/h
  }

  double _parseTemperature(String hexData) {
    if (hexData.isEmpty) return 0.0;
    String value = hexData.split(RESP_BATTERY_TEMP)[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return rawValue - 40; // Scale: 1 °C, offset: 40
  }

  double _parseCurrent(String hexData) {
    if (hexData.isEmpty) return 0.0;
    String value = hexData.split(RESP_BATTERY_CURRENT)[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return (rawValue - 48000) * 0.025; // Scale: 0.025 A, offset: 48000
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dataRequestTimer?.cancel();
    ref.read(oBD2DataProvider.notifier).setConnectionStatus('Disconnected');
  }
}