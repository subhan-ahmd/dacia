import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'obd2_data.g.dart';

@riverpod
class OBD2Data extends _$OBD2Data {
  @override
  Map<String, dynamic> build() {
    return emptyData();
  }

  Map<String, dynamic> emptyData() => {
    // Basic vehicle data
    'voltage': 0.0,        // Battery voltage in V
    'speed': 0.0,         // Vehicle speed in km/h
    'temperature': 0.0,   // Battery temperature in °C
    'current': 0.0,       // Battery current in A

    // Raw data and metadata
    'raw': '',           // Raw CAN message
    'lastUpdate': DateTime.now(),

    // Connection state
    'connectionStatus': 'Disconnected', // Can be: Disconnected, Initializing, Connected, Error
    'error': null,       // Last error message if any

    // Additional metadata from CanZE
    'canId': '',         // Current CAN ID (7ec or 7bb)
    'pid': '',          // Current PID being processed
    'timestamp': 0,     // Message timestamp
  };

  void reset() {
    state = emptyData();
  }

  void updateData(Map<String, dynamic> newData) {
    state = {
      ...state,
      ...newData,
      'lastUpdate': DateTime.now(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void setError(String? error) {
    state = {
      ...state,
      'error': error,
      'lastUpdate': DateTime.now(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void setConnectionStatus(String status) {
    state = {
      ...state,
      'connectionStatus': status,
      'lastUpdate': DateTime.now(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Helper method to check if we have valid data
  bool hasValidData() {
    return state['error'] == null &&
           state['connectionStatus'] == 'Connected' &&
           state['lastUpdate'].difference(DateTime.now()).inSeconds < 5;
  }

  // Helper method to get formatted data for display
  Map<String, String> getFormattedData() {
    return {
      'Voltage': '${state['voltage'].toStringAsFixed(1)} V',
      'Speed': '${state['speed'].toStringAsFixed(1)} km/h',
      'Temperature': '${state['temperature'].toStringAsFixed(1)} °C',
      'Current': '${state['current'].toStringAsFixed(1)} A',
    };
  }
}