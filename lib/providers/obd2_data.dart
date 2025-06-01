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
    'lastCommandTimestamp': null,
    'lastResponseTimestamp': null,
    'canMode': '11bit', // '11bit' or '29bit'
    'currentCanId': '',
    'bufferFlushData': '',
    'lastBufferFlush': null,
    'commandRetryCount': 0,
    'commandTimeout': 0,
  };

  void reset() {
    state = emptyData();
  }

  void updateData(Map<String, dynamic> newData) {
    state = {...state, ...newData, 'lastUpdate': DateTime.now()};
  }

  void setError(String? error) {
    state = {...state, 'error': error, 'lastUpdate': DateTime.now()};
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
    state = {...state, 'lastCommand': command, 'lastUpdate': DateTime.now()};
  }

  void setLastResponse(String response) {
    state = {...state, 'lastResponse': response, 'lastUpdate': DateTime.now()};
  }

  void setLastCommandTimestamp(DateTime timestamp) {
    state = {...state, 'lastCommandTimestamp': timestamp, 'lastUpdate': DateTime.now()};
  }

  void setLastResponseTimestamp(DateTime timestamp) {
    state = {...state, 'lastResponseTimestamp': timestamp, 'lastUpdate': DateTime.now()};
  }

  void setCanMode(String mode) {
    state = {...state, 'canMode': mode, 'lastUpdate': DateTime.now()};
  }

  void setCurrentCanId(String canId) {
    state = {...state, 'currentCanId': canId, 'lastUpdate': DateTime.now()};
  }

  void setBufferFlushData(String data) {
    state = {...state, 'bufferFlushData': data, 'lastUpdate': DateTime.now()};
  }

  void setLastBufferFlush(DateTime timestamp) {
    state = {...state, 'lastBufferFlush': timestamp, 'lastUpdate': DateTime.now()};
  }

  void incrementCommandRetry() {
    state = {
      ...state,
      'commandRetryCount': (state['commandRetryCount'] as int) + 1,
      'lastUpdate': DateTime.now(),
    };
  }

  void setCommandTimeout(int timeout) {
    state = {...state, 'commandTimeout': timeout, 'lastUpdate': DateTime.now()};
  }
}