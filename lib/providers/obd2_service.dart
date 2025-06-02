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

  static const String EVC_CAN_ID = '7ec';
  static const String PID_EXTERNAL_TEMP = '2233B1';
  static const String RESP_EXTERNAL_TEMP = '6233B1';

  @override
  void build() {}

  // Initialize the ELM327 device
  Future<void> initializeDevice() async {
    // If already initialized, don't try to initialize again
    if (_isInitialized) {
      print('Device already initialized, skipping initialization');
      return;
    }

    // Set initializing state
    ref.read(oBD2DataProvider.notifier).setConnectionStatus('Initializing...');

    try {
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

      // Only set initialized if all commands succeeded
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
      // Re-throw the error to be handled by the caller
      throw e;
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
            ref.read(oBD2DataProvider.notifier).setBufferFlushData(response);
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
      // Add proper line ending
      final commandBytes = Uint8List.fromList('$command\r'.codeUnits);

      // Create a completer to handle the async response
      final completer = Completer<String>();
      StreamSubscription? subscription;
      String response = '';
      bool responseReceived = false;

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

          // Set up subscription before sending command
          subscription = _ble
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
              print("Command: $command");
              print('Response received: ${response}');
              print('Raw data received: ${data.toList()}');
              if (response.isNotEmpty) {
                responseReceived = true;
                ref.read(oBD2DataProvider.notifier).setLastResponse(response);
                ref
                    .read(oBD2DataProvider.notifier)
                    .setLastResponseTimestamp(DateTime.now());

                // Complete with response if we haven't already
                if (!completer.isCompleted) {
                  completer.complete(response);
                }
              }
            },
            onError: (error) {
              print('Error receiving response: $error');
              if (!completer.isCompleted) {
                completer.completeError(error);
              }
            },
          );

          // Send the command
          await _ble.writeCharacteristicWithResponse(
            QualifiedCharacteristic(
              deviceId: ref.read(selectedDeviceProvider)!.id,
              serviceId: Uuid.parse(serviceUuid),
              characteristicId: Uuid.parse(characteristicUuid),
            ),
            value: commandBytes,
          );

          // For initialization commands (AT commands), just wait and return OK
          if (command.startsWith('AT')) {
            await Future.delayed(Duration(milliseconds: timeout));
            await subscription?.cancel();
            return 'OK';
          }

          // For data requests, wait for response with timeout
          try {
            response = await completer.future.timeout(
              Duration(
                  milliseconds:
                      timeout * 2), // Double the timeout for more patience
              onTimeout: () {
                throw TimeoutException('Command timed out: $command');
              },
            );

            // Check for OK response
            if (response.toUpperCase().contains('OK')) {
              // Add appropriate delay based on command type
              if (command.startsWith('ATSP')) {
                await Future.delayed(const Duration(milliseconds: 500));
              } else if (command.startsWith('22') || command.startsWith('23')) {
                await Future.delayed(const Duration(milliseconds: 1000));
              } else {
                await Future.delayed(const Duration(milliseconds: 200));
              }
              await subscription?.cancel();
              return response;
            }
          } catch (e) {
            print('Timeout or error waiting for response: $e');
            if (i == 1) {
              // Last attempt - wait a bit longer before giving up
              await Future.delayed(const Duration(milliseconds: 500));
              await subscription?.cancel();
              return response; // Return whatever response we got, even if empty
            }
          }

          // Wait before retry
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('Error in command attempt $i: $e');
          if (i == 1) {
            // Last attempt - just return empty response
            await subscription?.cancel();
            return '';
          }
          // Wait before retry
          await Future.delayed(const Duration(milliseconds: 200));
        } finally {
          // Ensure subscription is cancelled
          await subscription?.cancel();
        }
      }

      return ''; // Return empty string if all attempts failed
    } catch (e) {
      print('Error sending command: $e');
      ref
          .read(oBD2DataProvider.notifier)
          .setError('Failed to send command: $e');
      return ''; // Return empty string instead of throwing
    }
  }

  // Request specific data from the device
  Future<void> requestData(String pid, String canId) async {
    // If not initialized, don't try to request data
    if (!_isInitialized) {
      print('Device not initialized, skipping data request');
      return;
    }

    try {
      final formatter = CanIdFormatter(canId);

      // Get current state
      final currentState = ref.read(oBD2DataProvider);
      final currentCanMode = currentState['canMode'] as String? ?? '11bit';
      final currentCanId = currentState['currentCanId'] as String? ?? '';

      // Only send CAN mode commands if we need to switch modes
      bool needModeSwitch = false;
      if (formatter.isExtended && currentCanMode != '29bit') {
        needModeSwitch = true;
      } else if (!formatter.isExtended && currentCanMode != '11bit') {
        needModeSwitch = true;
      }

      if (needModeSwitch) {
        if (formatter.isExtended) {
          await _sendCommandAndWait('atsp7', 200);
          ref.read(oBD2DataProvider.notifier).setCanMode('29bit');
          await _sendCommandAndWait('atcp${formatter.getToIdHexMSB()}', 200);
        } else {
          await _sendCommandAndWait('atsp6', 200);
          ref.read(oBD2DataProvider.notifier).setCanMode('11bit');
        }
      }

      // Only set header and filter if CAN ID has changed
      if (currentCanId != canId) {
        // Set header (where to send) - using LSB format
        await _sendCommandAndWait('atsh${formatter.getToIdHexLSB()}', 200);
        // Set filter (what to receive) - using standard format
        await _sendCommandAndWait('atcra${formatter.getFromIdHex()}', 200);
        // Set flow control response ID - using standard format
        await _sendCommandAndWait('atfcsh${formatter.getToIdHex()}', 200);
        // Update current CAN ID
        ref.read(oBD2DataProvider.notifier).setCurrentCanId(canId);
      }

      // Handle ISO-TP request
      final outgoingLength = pid.length;
      String elmResponse = '';

      if (outgoingLength <= 14) {
        // Single frame (≤ 7 bytes)
        final elmCommand = '0${(outgoingLength / 2).floor()}${pid}';
        elmResponse = await _sendCommandAndWait(elmCommand, 500);
      } else {
        // Multi-frame
        int startIndex = 0;
        int endIndex = 12;
        final elmCommand =
            '1${(outgoingLength / 2).floor().toRadixString(16).padLeft(3, '0')}${pid.substring(startIndex, endIndex)}';
        String elmFlowResponse = await _sendCommandAndWait(elmCommand, 500);

        startIndex = endIndex;
        if (startIndex > outgoingLength) startIndex = outgoingLength;
        endIndex += 14;
        if (endIndex > outgoingLength) endIndex = outgoingLength;

        int next = 1;
        while (startIndex < outgoingLength) {
          final elmCommand =
              '2${next.toRadixString(16)}${pid.substring(startIndex, endIndex)}';

          if (elmFlowResponse.startsWith('3000')) {
            // Send all data without further flow control
            elmResponse = await _sendCommandAndWait(elmCommand, 500);
          } else if (elmFlowResponse.startsWith('30')) {
            // Wait for flow control response
            elmFlowResponse = await _sendCommandAndWait(elmCommand, 500);
            elmResponse = elmFlowResponse;
          } else {
            print('ISOTP tx flow Error: $elmFlowResponse');
            ref
                .read(oBD2DataProvider.notifier)
                .setError('ISOTP tx flow Error: $elmFlowResponse');
            return;
          }

          startIndex = endIndex;
          if (startIndex > outgoingLength) startIndex = outgoingLength;
          endIndex += 14;
          if (endIndex > outgoingLength) endIndex = outgoingLength;
          if (next == 15)
            next = 0;
          else
            next++;
        }
      }

      // Process response
      elmResponse = elmResponse.trim();
      if (elmResponse.startsWith('>')) elmResponse = elmResponse.substring(1);

      if (elmResponse == 'CAN ERROR') {
        ref.read(oBD2DataProvider.notifier).setError('Can Error');
      } else if (elmResponse == '?') {
        ref.read(oBD2DataProvider.notifier).setError('Unknown command');
      } else if (elmResponse.isEmpty) {
        ref.read(oBD2DataProvider.notifier).setError('Empty result');
      }
    } catch (e) {
      print('Error requesting data: $e');
      ref
          .read(oBD2DataProvider.notifier)
          .setError('Failed to request data: $e');
    }
  }

  // Subscribe to characteristic updates
  void subscribeToData() async {
    print(" subscribeToData()");
    // Cancel any existing subscription and timer
    _subscription?.cancel();
    _dataRequestTimer?.cancel();

    // Only initialize if not already initialized
    if (!_isInitialized) {
      try {
        await initializeDevice();
        if (!_isInitialized) {
          // If initialization failed, don't proceed with subscription
          return;
        }
      } catch (e) {
        print('Failed to initialize device: $e');
        return;
      }
    }

    // Set up the subscription for receiving data
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
        print("Subscription");
        print('Response received: ${response}');
        print('Raw data received: ${data.toList()}');
        final parsedData = parseData(data);
        if (parsedData.isNotEmpty) {
          ref.read(oBD2DataProvider.notifier).updateData(parsedData);
        }
      },
      onError: (dynamic error) {
        print('Error in subscription: $error');
        _isInitialized = false;
        _dataRequestTimer?.cancel(); // Cancel timer on error
        ref
            .read(oBD2DataProvider.notifier)
            .setError('Subscription error: $error');
        ref.read(oBD2DataProvider.notifier).setConnectionStatus('Error');
      },
      cancelOnError: false,
    );

    // Start periodic data requests only if initialized
    if (_isInitialized) {
      _dataRequestTimer?.cancel(); // Ensure any existing timer is cancelled
      _dataRequestTimer =
          Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!_isInitialized) {
          timer.cancel();
          return;
        }

        try {
          await requestData(PID_EXTERNAL_TEMP, EVC_CAN_ID);
        } catch (e) {
          print('Error in periodic data request: $e');
          _isInitialized = false; // Mark as uninitialized on error
          timer.cancel(); // Cancel timer on error
          ref
              .read(oBD2DataProvider.notifier)
              .setError('Periodic request error: $e');
        }
      });
    }
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

      // Parse based on the response PID
      if (hexData.contains(RESP_EXTERNAL_TEMP)) {
        // External Temperature
        parsedData['externalTemperature'] = _parseExternalTemperature(hexData);
      }

      return parsedData;
    } catch (e) {
      print('Error parsing data: $e');
      ref.read(oBD2DataProvider.notifier).setError('Data parsing error: $e');
      return {};
    }
  }

  // Helper method to parse external temperature
  double _parseExternalTemperature(String hexData) {
    if (hexData.isEmpty) return 0.0;
    String value = hexData.split(RESP_EXTERNAL_TEMP)[1].trim();
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 1.0; // Scale: 1 °C
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dataRequestTimer?.cancel();
    _isInitialized = false; // Reset initialization state
    ref.read(oBD2DataProvider.notifier).setConnectionStatus('Disconnected');
  }
}
