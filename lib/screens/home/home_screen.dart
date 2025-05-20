import 'dart:collection';

// import 'package:dacia/providers/available_devices.dart';
import 'package:dacia/providers/connected_devices_provider.dart';
import 'package:dacia/providers/selected_device_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/available_devices.dart';

// import '../../providers/vehicle_data_provider.dart';
// import '../../utils/bluetooth_manager.dart';

class VehicleDataScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<VehicleDataScreen> createState() => _VehicleDataScreenState();
}

class _VehicleDataScreenState extends ConsumerState<VehicleDataScreen> {
  // late VehicleDataService _vehicleDataService;
  DiscoveredDevice? selectedDevice;

  @override
  void initState() {
    super.initState();
    // _vehicleDataService = VehicleDataService();
    // _startListening();
  }

  // Future<void> _startListening() async {
  //   String deviceId = ConnectedDevices.deviceId;
  //
  //   // await _vehicleDataService.startListening(deviceId);
  //   //
  //   // _vehicleDataService.vehicleData.listen((data) {
  //   //   ref.read(vehicleDataProvider.notifier).updateData(data);
  //   // });
  // }

  @override
  void dispose() {
    // _vehicleDataService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final vehicleData = ref.watch(vehicleDataProvider);
    final devices = ref.watch(deviceManagerProvider);
    final connectedDevices= ref.watch(connectedDevicesProvider.notifier);
    final selectedDevice = ref.watch(selectedDeviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Dacia'),
        actions: [
          Container(
            height: 12,
            width: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connectedDevices
                      .isDeviceConnected(id: selectedDevice?.id)
                  ? Colors.green
                  : Colors.red,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              await ref.read(connectedDevicesProvider.notifier).disconnect();
              ref.read(deviceManagerProvider.notifier).refreshScan();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownMenu(
              width: double.maxFinite,
              menuHeight: 150,
              requestFocusOnTap: true,
              label: const Text('BLE Devices'),
              onSelected: (DiscoveredDevice? device) async {
                await ref.read(connectedDevicesProvider.notifier).disconnect();
               if(device!=null) {
                  ref.read(selectedDeviceProvider.notifier).select(device);
                  await ref.read(connectedDevicesProvider.notifier).connect();
                }
                // setState(() {
                //   selectedDevice = device;
                // });
              },
              dropdownMenuEntries: [
                ...devices.map((device) => DropdownMenuEntry(
                      value: device,
                      label: device.name.isEmpty?device.id:device.name,
                      enabled: true,
                      style: MenuItemButton.styleFrom(
                          foregroundColor: Colors.black),
                    )),
              ],
            ),
            // SizedBox(height: 16),
            // _buildBatterySection(vehicleData),
            // SizedBox(height: 16),
            // _buildSpeedSection(vehicleData),
            // SizedBox(height: 16),
            // _buildTripSection(vehicleData),
          ],
        ),
      ),
    );
  }

  // Widget _buildBatterySection(VehicleDataState data) {
  //   return Card(
  //     child: Padding(
  //       padding: EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             'Battery Information',
  //             style: TextStyle(
  //               fontSize: 20,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //           SizedBox(height: 16),
  //           _buildDataRow('State of Charge', '${data.soc.toStringAsFixed(1)}%'),
  //           _buildDataRow('Real SoC', '${data.realSoc.toStringAsFixed(1)}%'),
  //           _buildDataRow('Battery Voltage', '${data.voltage.toStringAsFixed(1)}V'),
  //           _buildDataRow('Battery Current', '${data.current.toStringAsFixed(1)}A'),
  //           _buildDataRow('Battery Temperature', '${data.temperature.toStringAsFixed(1)}°C'),
  //           _buildDataRow('Range Estimate', '${data.range.toStringAsFixed(1)}km'),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildSpeedSection(VehicleDataState data) {
  //   return Card(
  //     child: Padding(
  //       padding: EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             'Speed Information',
  //             style: TextStyle(
  //               fontSize: 20,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //           SizedBox(height: 16),
  //           _buildDataRow('Current Speed', '${data.speed.toStringAsFixed(1)} km/h'),
  //           _buildDataRow('Odometer', '${data.odometer.toStringAsFixed(1)} km'),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildTripSection(VehicleDataState data) {
  //   return Card(
  //     child: Padding(
  //       padding: EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             'Trip Information',
  //             style: TextStyle(
  //               fontSize: 20,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //           SizedBox(height: 16),
  //           _buildDataRow('Trip Distance', '${data.tripMeter.toStringAsFixed(1)} km'),
  //           _buildDataRow('Trip Energy', '${data.tripEnergy.toStringAsFixed(1)} kWh'),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

typedef ColorEntry = DropdownMenuEntry<ColorLabel>;

// DropdownMenuEntry labels and values for the first dropdown menu.
enum ColorLabel {
  blue('Blue', Colors.blue),
  pink('Pink', Colors.pink),
  green('Green', Colors.green),
  yellow('Orange', Colors.orange),
  grey('Grey', Colors.grey);

  const ColorLabel(this.label, this.color);
  final String label;
  final Color color;

  static final List<ColorEntry> entries = UnmodifiableListView<ColorEntry>(
    values.map<ColorEntry>(
      (ColorLabel color) => ColorEntry(
        value: color,
        label: color.label,
        enabled: color.label != 'Grey',
        style: MenuItemButton.styleFrom(foregroundColor: color.color),
      ),
    ),
  );
}
