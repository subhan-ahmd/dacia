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
      'full':""
    };
  }

  void updateData(Map<String, dynamic> newData) {
    // Replace the entire state with new data
    state = newData;
  }
}