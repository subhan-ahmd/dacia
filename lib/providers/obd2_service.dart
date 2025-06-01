import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/obd2_data.dart';
import '../providers/selected_device_provider.dart';

part 'obd2_service.g.dart';

// CAN ID formatter class
class CanIdFormatter {
  final String canId;
  final bool isExtended;

  CanIdFormatter(this.canId, {this.isExtended = false});

  // Get ID in LSB format for sending (atsh)
  String getToIdHexLSB() {
    if (isExtended) {
      // For 29-bit IDs, format as 6 bytes with bit masking (like Java's & 0xffffff)
      int id = int.parse(canId, radix: 16);
      return (id & 0xffffff).toRadixString(16).padLeft(6, '0');
    } else {
      // For 11-bit IDs, format as 3 bytes (like Java's %03x)
      return canId.padLeft(3, '0');
    }
  }

  // Get ID in standard format for receiving (atcra)
  String getFromIdHex() {
    if (isExtended) {
      // For 29-bit IDs, format as 8 bytes (like Java's %08x)
      return canId.padLeft(8, '0');
    } else {
      // For 11-bit IDs, format as 3 bytes (like Java's %03x)
      return canId.padLeft(3, '0');
    }
  }

  // Get ID in standard format for flow control (atfcsh)
  String getToIdHex() {
    if (isExtended) {
      // For 29-bit IDs, format as 8 bytes (like Java's %08x)
      return canId.padLeft(8, '0');
    } else {
      // For 11-bit IDs, format as 3 bytes (like Java's %03x)
      return canId.padLeft(3, '0');
    }
  }

  // Get MSB for priority (like Java's getToIdHexMSB)
  String getToIdHexMSB() {
    if (isExtended) {
      int id = int.parse(canId, radix: 16);
      return ((id & 0x1f000000) >> 24).toRadixString(16).padLeft(2, '0');
    }
    return '00';
  }
}

@riverpod
class OBD2Service extends _$OBD2Service {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription? _subscription;
  bool _isInitialized = false;
  Timer? _dataRequestTimer;
  String? _lastError;
  int _lastId = 0;

  // These UUIDs should be discovered from your device
  late final String serviceUuid = "e7810a71-73ae-499d-8c15-faa9aef0c3f2";
  late final String characteristicUuid = "bef8d6c9-9c21-4c9e-b632-bd58c1009f9f";

  // CAN IDs for different controllers
  static const String EVC_CAN_ID = '7ec'; // Electric Vehicle Controller
  static const String LBC_CAN_ID = '7bb'; // Lithium Battery Controller

  // Request PIDs
  static const String PID_BATTERY_VOLTAGE =
      '229005'; // Pack Voltage CAN value (scale: 0.1 V)
  static const String PID_VEHICLE_SPEED =
      '222003'; // Vehicle speed (scale: 0.01 km/h)
  static const String PID_BATTERY_TEMP =
      '222001'; // Battery Rack temperature (scale: 1 °C, offset: 40)
  static const String PID_BATTERY_CURRENT =
      '22900D'; // Instant Current of Battery (scale: 0.025 A, offset: 48000)

  // Response PIDs
  static const String RESP_BATTERY_VOLTAGE =
      '629005'; // Response for battery voltage
  static const String RESP_VEHICLE_SPEED =
      '622003'; // Response for vehicle speed
  static const String RESP_BATTERY_TEMP =
      '622001'; // Response for battery temperature
  static const String RESP_BATTERY_CURRENT =
      '62900D'; // Response for battery current

  @override
  void build() {}

  // Initialize the ELM327 device
  Future<void> initializeDevice() async {
    if (_isInitialized) return;

    try {
      ref
          .read(oBD2DataProvider.notifier)
          .setConnectionStatus('Initializing...');

      // Enable notifications
      await _ble.writeCharacteristicWithResponse(
        QualifiedCharacteristic(
          deviceId: ref.read(selectedDeviceProvider)!.id,
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(characteristicUuid),
        ),
        value: Uint8List.fromList([0x01, 0x00]), // Enable notifications
      );

      // First, try to reset the device
      await _resetDevice();

      // Send initialization commands with appropriate delays
      // Using uppercase commands as in Java implementation
      await _sendCommandAndWait('ATE0', 2000); // No echo
      await _sendCommandAndWait('ATS0', 200); // No spaces
      await _sendCommandAndWait('ATSP6', 200); // CAN 500K 11 bit
      await _sendCommandAndWait('ATAT1', 200); // Auto timing
      await _sendCommandAndWait('ATCAF0', 200); // No formatting
      await _sendCommandAndWait('ATFCSH77B', 200); // Flow control response ID
      await _sendCommandAndWait(
        'ATFCSD300010',
        200,
      ); // Flow control response data
      await _sendCommandAndWait('ATFCSM1', 200); // Flow control mode 1

      _isInitialized = true;
      ref.read(oBD2DataProvider.notifier).setConnectionStatus('Connected');
      ref.read(oBD2DataProvider.notifier).setError(null);
      ref.read(oBD2DataProvider.notifier).setInitialized(true);
      print('Device initialized successfully');
    } catch (e) {
      _isInitialized = false;
      ref.read(oBD2DataProvider.notifier).setConnectionStatus('Error');
      ref
          .read(oBD2DataProvider.notifier)
          .setError('Failed to initialize device: $e');
      ref.read(oBD2DataProvider.notifier).setInitialized(false);
      print('Error initializing device: $e');
    }
  }

  // Reset the device before initialization
  Future<void> _resetDevice() async {
    try {
      // Send ATZ to reset the device
      await _ble.writeCharacteristicWithResponse(
        QualifiedCharacteristic(
          deviceId: ref.read(selectedDeviceProvider)!.id,
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(characteristicUuid),
        ),
        value: Uint8List.fromList('ATZ\r'.codeUnits),
      );

      // Wait for device to reset
      await Future.delayed(const Duration(seconds: 2));

      // Clear any pending responses
      await _flushResponseBuffer();

      // Send ATD to get device info
      await _ble.writeCharacteristicWithResponse(
        QualifiedCharacteristic(
          deviceId: ref.read(selectedDeviceProvider)!.id,
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(characteristicUuid),
        ),
        value: Uint8List.fromList('ATD\r'.codeUnits),
      );

      // Wait for device info
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Error resetting device: $e');
      // Continue with initialization even if reset fails
    }
  }

  // Flush the response buffer
  Future<void> _flushResponseBuffer() async {
    try {
      _subscription?.cancel();
      StringBuffer buffer = StringBuffer();
      bool dataReceived = false;

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
              String response = String.fromCharCodes(data).trim();
              if (response.isNotEmpty) {
                buffer.write(response);
                dataReceived = true;
                print('Flushing buffer data: $response');
                ref
                    .read(oBD2DataProvider.notifier)
                    .setBufferFlushData(response);
              }
            },
            onError: (error) {
              print('Error flushing buffer: $error');
            },
          );

      // Wait a bit to clear any pending responses
      await Future.delayed(const Duration(milliseconds: 200));

      if (dataReceived) {
        print('Buffer flush complete. Data received: ${buffer.toString()}');
        ref.read(oBD2DataProvider.notifier).setLastBufferFlush(DateTime.now());
      }

      _subscription?.cancel();
    } catch (e) {
      print('Error flushing buffer: $e');
    }
  }

  // Send command to the device with timeout
  Future<String> _sendCommandAndWait(String command, int timeout) async {
    try {
      // Add proper line ending as in Java implementation
      final commandBytes = Uint8List.fromList('$command\r'.codeUnits);

      // Check if device is still connected before sending
      if (!_isInitialized && command == 'ATE0') {
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Give device time to stabilize
      }

      // Try the command up to 2 times
      for (int i = 0; i < 2; i++) {
        try {
          // Clear any pending responses before sending new command
          await _flushResponseBuffer();

          // Update command tracking
          ref.read(oBD2DataProvider.notifier).setLastCommand(command);
          ref
              .read(oBD2DataProvider.notifier)
              .setLastCommandTimestamp(DateTime.now());
          ref.read(oBD2DataProvider.notifier).incrementCommandRetry();

          await _ble.writeCharacteristicWithResponse(
            QualifiedCharacteristic(
              deviceId: ref.read(selectedDeviceProvider)!.id,
              serviceId: Uuid.parse(serviceUuid),
              characteristicId: Uuid.parse(characteristicUuid),
            ),
            value: commandBytes,
          );

          // Wait for response with simple delay
          String response = '';
          bool responseReceived = false;

          _subscription?.cancel();
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
                  response = String.fromCharCodes(data).trim();
                  if (response.isNotEmpty) {
                    // Only consider non-empty responses
                    responseReceived = true;
                    ref
                        .read(oBD2DataProvider.notifier)
                        .setLastResponse(response);
                    ref
                        .read(oBD2DataProvider.notifier)
                        .setLastResponseTimestamp(DateTime.now());
                  }
                },
                onError: (error) {
                  print('Error receiving response: $error');
                },
              );

          // Wait for response with timeout
          int waitTime = 0;
          while (!responseReceived && waitTime < timeout) {
            await Future.delayed(const Duration(milliseconds: 50));
            waitTime += 50;
          }

          if (!responseReceived) {
            throw TimeoutException('Command timed out: $command');
          }

          // Check for OK response as in Java implementation
          if (response.toUpperCase().contains('OK')) {
            // Add appropriate delay based on command type
            if (command.startsWith('ATSP')) {
              await Future.delayed(const Duration(milliseconds: 500));
            } else if (command.startsWith('22') || command.startsWith('23')) {
              await Future.delayed(const Duration(milliseconds: 1000));
            } else {
              await Future.delayed(const Duration(milliseconds: 200));
            }
            return response;
          }

          // If we get here, the response didn't contain OK
          if (i == 1) {
            // Last attempt
            throw Exception('Device error: No OK response for $command');
          }

          // Wait before retry
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          if (i == 1) {
            // Last attempt
            rethrow;
          }
          // Wait before retry
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      throw Exception('Failed to get valid response after retries');
    } catch (e) {
      print('Error sending command: $e');
      ref
          .read(oBD2DataProvider.notifier)
          .setError('Failed to send command: $e');
      rethrow;
    }
  }

  // Request specific data from the device
  Future<void> requestData(String pid) async {
    if (!_isInitialized) {
      await initializeDevice();
    }

    try {
      // Determine which CAN ID to use based on the PID
      String canId = pid.startsWith('22') ? EVC_CAN_ID : LBC_CAN_ID;
      final formatter = CanIdFormatter(canId);

      // Check if we need to switch CAN mode
      if (formatter.isExtended) {
        await _sendCommandAndWait('atsp7', 200); // Switch to 29-bit mode
        ref.read(oBD2DataProvider.notifier).setCanMode('29bit');
        // Set priority using AT CP
        await _sendCommandAndWait('atcp${formatter.getToIdHexMSB()}', 200);
      } else {
        await _sendCommandAndWait('atsp6', 200); // Switch to 11-bit mode
        ref.read(oBD2DataProvider.notifier).setCanMode('11bit');
      }

      // Set header (where to send) - using LSB format
      await _sendCommandAndWait('atsh${formatter.getToIdHexLSB()}', 200);

      // Set filter (what to receive) - using standard format
      await _sendCommandAndWait('atcra${formatter.getFromIdHex()}', 200);

      // Set flow control response ID - using standard format
      await _sendCommandAndWait('atfcsh${formatter.getToIdHex()}', 200);

      // Update current CAN ID
      ref.read(oBD2DataProvider.notifier).setCurrentCanId(canId);

      // Then send the actual request (pid already includes the '22' service ID)
      await _sendCommandAndWait(pid, 500); // Longer timeout for data request
    } catch (e) {
      print('Error requesting data: $e');
      ref
          .read(oBD2DataProvider.notifier)
          .setError('Failed to request data: $e');
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
            ref
                .read(oBD2DataProvider.notifier)
                .setError('Subscription error: $error');
            ref.read(oBD2DataProvider.notifier).setConnectionStatus('Error');
          },
          cancelOnError: false,
        );

    // Start periodic data requests
    _dataRequestTimer?.cancel();
    _dataRequestTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!_isInitialized) return;

      try {
        // Request Spring-specific data points
        await requestData(PID_BATTERY_VOLTAGE); // Battery Voltage
        await requestData(PID_VEHICLE_SPEED); // Vehicle Speed
        await requestData(PID_BATTERY_TEMP); // Battery Temperature
        await requestData(PID_BATTERY_CURRENT); // Battery Current
      } catch (e) {
        print('Error in periodic data request: $e');
        ref
            .read(oBD2DataProvider.notifier)
            .setError('Periodic request error: $e');
      }
    });
  }

  // Parse the received data
  Map<String, dynamic> parseData(List<int> data) {
    if (data.isEmpty) return {};

    try {
      // Convert data to hex string
      String hexData =
          data
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
    // Extract the value after the PID
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
