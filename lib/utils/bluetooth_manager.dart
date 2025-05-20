import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';

class VehicleDataService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamController<Map<String, dynamic>> _dataController = StreamController.broadcast();

  // Service UUIDs
  static const String BATTERY_SERVICE_UUID = "7bb"; // Battery Control Board service
  static const String EVC_SERVICE_UUID = "7ec"; // Electric Vehicle Control service

  // Characteristic UUIDs for different data points
  // Battery Data
  static const String SOC_CHARACTERISTIC = "42e.0"; // State of Charge
  static const String REAL_SOC_CHARACTERISTIC = "7bb.6103.192"; // Real State of Charge
  static const String BATTERY_VOLTAGE_CHARACTERISTIC = "7ec.623203.24"; // Traction Battery Voltage
  static const String BATTERY_CURRENT_CHARACTERISTIC = "7ec.623204.24"; // Traction Battery Current
  static const String BATTERY_TEMP_CHARACTERISTIC = "7bb.6104.600"; // Average Battery Temperature
  static const String RANGE_CHARACTERISTIC = "654.42"; // Range Estimate

  // GPS/Speed Data
  static const String SPEED_CHARACTERISTIC = "5d7.0"; // Real Speed
  static const String ODOMETER_CHARACTERISTIC = "7ec.622006.24"; // EVC Odometer
  static const String TRIP_METER_CHARACTERISTIC = "7ec.6233de.24"; // Trip Meter B
  static const String TRIP_ENERGY_CHARACTERISTIC = "7ec.6233dd.24"; // Trip Energy B

  Stream<Map<String, dynamic>> get vehicleData => _dataController.stream;

  Future<void> startListening(String deviceId) async {
    // Subscribe to battery characteristics
    await _subscribeToCharacteristic(deviceId, BATTERY_SERVICE_UUID, SOC_CHARACTERISTIC, 'soc');
    await _subscribeToCharacteristic(deviceId, BATTERY_SERVICE_UUID, REAL_SOC_CHARACTERISTIC, 'realSoc');
    await _subscribeToCharacteristic(deviceId, EVC_SERVICE_UUID, BATTERY_VOLTAGE_CHARACTERISTIC, 'voltage');
    await _subscribeToCharacteristic(deviceId, EVC_SERVICE_UUID, BATTERY_CURRENT_CHARACTERISTIC, 'current');
    await _subscribeToCharacteristic(deviceId, BATTERY_SERVICE_UUID, BATTERY_TEMP_CHARACTERISTIC, 'temperature');
    await _subscribeToCharacteristic(deviceId, BATTERY_SERVICE_UUID, RANGE_CHARACTERISTIC, 'range');

    // Subscribe to GPS/Speed characteristics
    await _subscribeToCharacteristic(deviceId, EVC_SERVICE_UUID, SPEED_CHARACTERISTIC, 'speed');
    await _subscribeToCharacteristic(deviceId, EVC_SERVICE_UUID, ODOMETER_CHARACTERISTIC, 'odometer');
    await _subscribeToCharacteristic(deviceId, EVC_SERVICE_UUID, TRIP_METER_CHARACTERISTIC, 'tripMeter');
    await _subscribeToCharacteristic(deviceId, EVC_SERVICE_UUID, TRIP_ENERGY_CHARACTERISTIC, 'tripEnergy');
  }

  Future<void> _subscribeToCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    String dataKey,
  ) async {
    await _ble.subscribeToCharacteristic(
      QualifiedCharacteristic(
        characteristicId: Uuid.parse(characteristicUuid),
        serviceId: Uuid.parse(serviceUuid),
        deviceId: deviceId,
      ),
    ).listen((data) {
      // Parse the data based on the characteristic
      double value = _parseData(data, dataKey);

      // Update the data controller with the new value
      _dataController.add({dataKey: value});
    });
  }

  double _parseData(List<int> data, String dataKey) {
    // Parse data based on the characteristic type
    switch (dataKey) {
      case 'soc':
      case 'realSoc':
        // SOC is typically a percentage (0-100)
        return data[0].toDouble();

      case 'voltage':
        // Voltage is typically in volts
        return (data[0] << 8 | data[1]) / 10.0;

      case 'current':
        // Current is typically in amperes
        return (data[0] << 8 | data[1]) / 10.0;

      case 'temperature':
        // Temperature is typically in Celsius
        return data[0].toDouble();

      case 'range':
        // Range is typically in kilometers
        return (data[0] << 8 | data[1]).toDouble();

      case 'speed':
        // Speed is typically in km/h
        return data[0].toDouble();

      case 'odometer':
      case 'tripMeter':
        // Distance is typically in kilometers
        return (data[0] << 8 | data[1]) / 1000.0;

      case 'tripEnergy':
        // Energy is typically in kWh
        return (data[0] << 8 | data[1]) / 1000.0;

      default:
        return 0.0;
    }
  }

  void dispose() {
    _dataController.close();
  }
}