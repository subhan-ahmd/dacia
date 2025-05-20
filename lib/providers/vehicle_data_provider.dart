import 'package:flutter_riverpod/flutter_riverpod.dart';

// State class to hold all vehicle data
class VehicleDataState {
  final double soc;
  final double realSoc;
  final double voltage;
  final double current;
  final double temperature;
  final double range;
  final double speed;
  final double odometer;
  final double tripMeter;
  final double tripEnergy;

  VehicleDataState({
    this.soc = 0.0,
    this.realSoc = 0.0,
    this.voltage = 0.0,
    this.current = 0.0,
    this.temperature = 0.0,
    this.range = 0.0,
    this.speed = 0.0,
    this.odometer = 0.0,
    this.tripMeter = 0.0,
    this.tripEnergy = 0.0,
  });

  VehicleDataState copyWith({
    double? soc,
    double? realSoc,
    double? voltage,
    double? current,
    double? temperature,
    double? range,
    double? speed,
    double? odometer,
    double? tripMeter,
    double? tripEnergy,
  }) {
    return VehicleDataState(
      soc: soc ?? this.soc,
      realSoc: realSoc ?? this.realSoc,
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      temperature: temperature ?? this.temperature,
      range: range ?? this.range,
      speed: speed ?? this.speed,
      odometer: odometer ?? this.odometer,
      tripMeter: tripMeter ?? this.tripMeter,
      tripEnergy: tripEnergy ?? this.tripEnergy,
    );
  }
}

// Notifier class to manage the state
class VehicleDataNotifier extends StateNotifier<VehicleDataState> {
  VehicleDataNotifier() : super(VehicleDataState());

  void updateData(Map<String, dynamic> data) {
    state = state.copyWith(
      soc: data['soc'],
      realSoc: data['realSoc'],
      voltage: data['voltage'],
      current: data['current'],
      temperature: data['temperature'],
      range: data['range'],
      speed: data['speed'],
      odometer: data['odometer'],
      tripMeter: data['tripMeter'],
      tripEnergy: data['tripEnergy'],
    );
  }
}

// Provider definition
final vehicleDataProvider = StateNotifierProvider<VehicleDataNotifier, VehicleDataState>((ref) {
  return VehicleDataNotifier();
});