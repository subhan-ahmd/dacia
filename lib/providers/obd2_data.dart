import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'obd2_data.g.dart';

@riverpod
class OBD2Data extends _$OBD2Data {
  @override
  Map<String, dynamic> build() {
    return emptyData();
  }

  Map<String, dynamic> emptyData() => {
        'voltage': 0.0,
        'speed': 0.0,
        'temperature': 0.0,
        'current': 0.0,
        'raw': '',
        'lastUpdate': DateTime.now(),
        'connectionStatus': 'Disconnected',
        'error': null,
        'isInitialized': false,
        'lastCommand': '',
        'lastResponse': '',
        'canMode': '11bit', // '11bit' or '29bit'
        'currentCanId': '',
      };

  void reset() {
    state = emptyData();
  }

  void updateData(Map<String, dynamic> newData) {
    state = {
      ...state,
      ...newData,
      'lastUpdate': DateTime.now(),
    };
  }

  void setError(String? error) {
    state = {
      ...state,
      'error': error,
      'lastUpdate': DateTime.now(),
    };
  }

  void setConnectionStatus(String status) {
    state = {
      ...state,
      'connectionStatus': status,
      'lastUpdate': DateTime.now(),
    };
  }

  void setInitialized(bool initialized) {
    state = {
      ...state,
      'isInitialized': initialized,
      'lastUpdate': DateTime.now(),
    };
  }

  void setLastCommand(String command) {
    state = {
      ...state,
      'lastCommand': command,
      'lastUpdate': DateTime.now(),
    };
  }

  void setLastResponse(String response) {
    state = {
      ...state,
      'lastResponse': response,
      'lastUpdate': DateTime.now(),
    };
  }

  void setCanMode(String mode) {
    state = {
      ...state,
      'canMode': mode,
      'lastUpdate': DateTime.now(),
    };
  }

  void setCurrentCanId(String canId) {
    state = {
      ...state,
      'currentCanId': canId,
      'lastUpdate': DateTime.now(),
    };
  }
}