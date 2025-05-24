import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'selected_device_provider.g.dart';

@riverpod
class SelectedDevice extends _$SelectedDevice {
  @override
  DiscoveredDevice? build() => null;

  void select(DiscoveredDevice device) {
    state = device;
  }

  void clear() {
    state = null;
  }
}
