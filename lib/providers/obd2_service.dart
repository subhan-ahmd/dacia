import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:dacia/providers/obd2_data.dart';
import 'package:dacia/providers/selected_device_provider.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/material.dart';

part 'obd2_service.g.dart';

@riverpod
class OBD2Service extends _$OBD2Service {
  BluetoothConnection? _connection;
  StreamSubscription? _subscription;
  bool _isInitialized = false;
  Timer? _dataRequestTimer;
  final _buffer = StringBuffer();

  // Constants from CanZE
  static const int DEFAULT_TIMEOUT = 500;
  static const int MINIMUM_TIMEOUT = 100;
  int _generalTimeout = 500;

  // End of Message characters
  static const String EOM1 = '\r';
  static const String EOM2 = '>';
  static const String EOM3 = '?';

  // CAN IDs (from CanZE)
  static const String EVC_CAN_ID = '7ec';  // Electric Vehicle Controller
  static const String LBC_CAN_ID = '7bb';  // Lithium Battery Controller

  // PIDs (from CanZE)
  static const Map<String, String> PIDS = {
    'batteryVoltage': '229005', // Pack Voltage
    'vehicleSpeed': '222003',   // Vehicle speed
    'batteryTemp': '222001',    // Battery Rack temperature
    'batteryCurrent': '22900D', // Instant Current
  };

  @override
  void build() {}

  // Initialize the ELM327 device (exact sequence from CanZE)
  Future<void> initializeDevice() async {
    if (_isInitialized) return;

    try {
      ref.read(oBD2DataProvider.notifier).setConnectionStatus('Initializing...');

      // Exact same sequence as CanZE
      await _sendCommand('ate0'); // No echo
      await _sendCommand('ats0'); // No spaces
      await _sendCommand('ath0'); // Headers off
      await _sendCommand('atl0'); // Linefeeds off
      await _sendCommand('atal'); // Allow long messages
      await _sendCommand('atcaf0'); // No formatting
      await _sendCommand('atfcsh77b'); // Flow control response ID
      await _sendCommand('atfcsd300000'); // Flow control response data
      await _sendCommand('atfcsm1'); // Flow control mode 1
      await _sendCommand('atsp6'); // CAN 500K 11 bit

      _isInitialized = true;
      ref.read(oBD2DataProvider.notifier).setConnectionStatus('Connected');
      ref.read(oBD2DataProvider.notifier).setError(null);
    } catch (e) {
      _isInitialized = false;
      ref.read(oBD2DataProvider.notifier).setConnectionStatus('Error');
      ref.read(oBD2DataProvider.notifier).setError('Failed to initialize device: $e');
    }
  }

  // Send command to the device (based on CanZE's implementation)
  Future<String> _sendCommand(String command) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('Not connected to device');
    }

    try {
      _buffer.clear();
      final completer = Completer<String>();
      Timer? timeoutTimer;

      // Set up timeout
      timeoutTimer = Timer(Duration(milliseconds: _generalTimeout), () {
        if (!completer.isCompleted) {
          completer.completeError('Command timeout');
        }
      });

      // Flush any existing data
      await _flushWithTimeout(10, EOM2);

      // Send command
      _connection!.output.add(Uint8List.fromList('$command\r'.codeUnits));
      await _connection!.output.allSent;

      // Wait for response
      _subscription = _connection!.input!.listen(
        (data) {
          final response = String.fromCharCodes(data);
          _buffer.write(response);

          if (response.contains(EOM1) || response.contains(EOM2) || response.contains(EOM3)) {
            timeoutTimer?.cancel();
            if (!completer.isCompleted) {
              String finalResponse = _buffer.toString().trim();
              // Remove the command echo and prompt
              finalResponse = finalResponse.replaceAll('$command\r', '');
              finalResponse = finalResponse.replaceAll(EOM2, '');
              completer.complete(finalResponse);
            }
          }
        },
        onError: (error) {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      return await completer.future;
    } catch (e) {
      print('Error sending command: $e');
      ref.read(oBD2DataProvider.notifier).setError('Failed to send command: $e');
      rethrow;
    }
  }

  // Flush buffer with timeout (from CanZE)
  Future<bool> _flushWithTimeout(int timeout, String eom) async {
    if (_connection == null || !_connection!.isConnected) return false;

    try {
      final completer = Completer<bool>();
      Timer? timeoutTimer;

      timeoutTimer = Timer(Duration(milliseconds: timeout), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      _subscription = _connection!.input!.listen(
        (data) {
          final response = String.fromCharCodes(data);
          if (response.contains(eom)) {
            timeoutTimer?.cancel();
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          }
        },
        onError: (error) {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );

      return await completer.future;
    } catch (e) {
      return false;
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

      // First set the CAN ID using AT SH command
      await _sendCommand('AT SH $canId');

      // Then send the actual request and get the response
      String response = await _sendCommand(pid);

      // Parse and update the data
      if (response.isNotEmpty) {
        Map<String, dynamic> parsedData = parseData(response);
        ref.read(oBD2DataProvider.notifier).updateData(parsedData);
      }
    } catch (e) {
      print('Error requesting data: $e');
      ref.read(oBD2DataProvider.notifier).setError('Failed to request data: $e');
    }
  }

  // Subscribe to data updates
  void subscribeToData() async {
    if (!_isInitialized) {
      await initializeDevice();
    }

    // Start periodic data requests
    _dataRequestTimer?.cancel();
    _dataRequestTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isInitialized) return;

      try {
        // Request all PIDs
        for (final pid in PIDS.values) {
          await requestData(pid);
        }
      } catch (e) {
        print('Error in periodic data request: $e');
        ref.read(oBD2DataProvider.notifier).setError('Periodic request error: $e');
      }
    });
  }

  // Parse the received data (based on CanZE's data parsing)
  Map<String, dynamic> parseData(String data) {
    try {
      // Get current state to maintain other values
      final currentState = ref.read(oBD2DataProvider);
      Map<String, dynamic> parsedData = Map<String, dynamic>.from(currentState);
      parsedData["raw"] = data;

      // Check for error response
      if (data.startsWith('7F') || data.contains('ERROR')) {
        print('Error response received: $data');
        ref.read(oBD2DataProvider.notifier).setError('Device error: $data');
        return parsedData;
      }

      // Parse CAN message
      final parts = data.split(' ');
      if (parts.length < 2) return parsedData;

      final canId = parts[0];
      final pid = parts[1];
      final value = parts.length > 2 ? parts[2] : '';

      // Store CAN ID and PID in the data
      parsedData['canId'] = canId;
      parsedData['pid'] = pid;

      // Parse based on PID
      switch (pid) {
        case '9005': // Battery Voltage
          parsedData['voltage'] = _parseVoltage(value);
          break;
        case '2003': // Vehicle Speed
          parsedData['speed'] = _parseSpeed(value);
          break;
        case '2001': // Battery Temperature
          parsedData['temperature'] = _parseTemperature(value);
          break;
        case '900D': // Battery Current
          parsedData['current'] = _parseCurrent(value);
          break;
      }

      // Update timestamp
      parsedData['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      parsedData['lastUpdate'] = DateTime.now();

      return parsedData;
    } catch (e) {
      print('Error parsing data: $e');
      ref.read(oBD2DataProvider.notifier).setError('Data parsing error: $e');
      return {};
    }
  }

  // Helper methods to parse specific data types (from CanZE's implementation)
  double _parseVoltage(String value) {
    if (value.isEmpty) return 0.0;
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 0.1; // Scale: 0.1 V
  }

  double _parseSpeed(String value) {
    if (value.isEmpty) return 0.0;
    int rawValue = int.parse(value, radix: 16);
    return rawValue * 0.01; // Scale: 0.01 km/h
  }

  double _parseTemperature(String value) {
    if (value.isEmpty) return 0.0;
    int rawValue = int.parse(value, radix: 16);
    return rawValue - 40; // Scale: 1 °C, offset: 40
  }

  double _parseCurrent(String value) {
    if (value.isEmpty) return 0.0;
    int rawValue = int.parse(value, radix: 16);
    return (rawValue - 48000) * 0.025; // Scale: 0.025 A, offset: 48000
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dataRequestTimer?.cancel();
    _connection?.close();
    ref.read(oBD2DataProvider.notifier).setConnectionStatus('Disconnected');
  }
}