// lib/providers/obd2_data_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'obd2_data.g.dart';

@riverpod
class OBD2Data extends _$OBD2Data {
  @override
  Map<String, dynamic> build() {
    return {
      'soc': 0.0,
      'voltage': 0.0,
      'speed': 0.0,
      'raw': '',
      'lastUpdate': DateTime.now(),
      'connectionStatus': 'Disconnected',
      'error': null,
    };
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
}