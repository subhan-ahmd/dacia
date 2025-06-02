import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'obd2_data.g.dart';

@riverpod
class OBD2Data extends _$OBD2Data {
  @override
  Map<String, dynamic> build() => emptyData();

  Map<String, dynamic> emptyData() => {
        'error': null,
    'connectionStatus': 'Disconnected',
        'isInitialized': false,
        'canMode': '11bit',
        'currentCanId': '',
        'externalTemperature': 0.0,
        'commandRetry': 0,
        'lastCommand': '',
        'lastResponse': '',
        'lastCommandTimestamp': null,
        'lastResponseTimestamp': null,
        'lastBufferFlush': null,
        'bufferFlushData': '',
        'raw': '',
        'lastUpdate': DateTime.now(),
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

  void setCanMode(String mode) {
    state = {...state, 'canMode': mode, 'lastUpdate': DateTime.now()};
  }

  void setCurrentCanId(String canId) {
    state = {...state, 'currentCanId': canId, 'lastUpdate': DateTime.now()};
  }

  void setLastCommand(String command) {
    state = {...state, 'lastCommand': command, 'lastUpdate': DateTime.now()};
  }

  void setLastResponse(String response) {
    state = {...state, 'lastResponse': response, 'lastUpdate': DateTime.now()};
  }

  void setLastCommandTimestamp(DateTime timestamp) {
    state = {
      ...state,
      'lastCommandTimestamp': timestamp,
      'lastUpdate': DateTime.now(),
    };
  }

  void setLastResponseTimestamp(DateTime timestamp) {
    state = {
      ...state,
      'lastResponseTimestamp': timestamp,
      'lastUpdate': DateTime.now(),
    };
  }

  void setLastBufferFlush(DateTime timestamp) {
    state = {
      ...state,
      'lastBufferFlush': timestamp,
      'lastUpdate': DateTime.now(),
    };
  }

  void setBufferFlushData(String data) {
    state = {...state, 'bufferFlushData': data, 'lastUpdate': DateTime.now()};
  }

  void incrementCommandRetry() {
    state = {
      ...state,
      'commandRetry': (state['commandRetry'] as int) + 1,
      'lastUpdate': DateTime.now(),
    };
  }
}
