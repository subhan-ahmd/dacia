import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_device_provider.g.dart';

@riverpod
class SelectedDevice extends _$SelectedDevice {
  @override
  BluetoothDevice? build() => null;

  void select(BluetoothDevice device) {
    state = device;
  }

  void clear() {
    state = null;
  }
}