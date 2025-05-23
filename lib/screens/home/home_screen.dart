import 'package:dacia/providers/connected_devices_provider.dart';
import 'package:dacia/providers/obd2_data.dart';
import 'package:dacia/providers/selected_device_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/available_devices.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(deviceManagerProvider);
    final connectedDevices = ref.watch(connectedDevicesProvider.notifier);
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final obd2Data = ref.watch(oBD2DataProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Dacia'),
        actions: [
          Container(
            height: 12,
            width: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connectedDevices.isDeviceConnected(id: selectedDevice?.id)
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
                if (device != null) {
                  ref.read(selectedDeviceProvider.notifier).select(device);
                  await ref.read(connectedDevicesProvider.notifier).connect();
                }
              },
              dropdownMenuEntries: [
                ...devices.map((device) => DropdownMenuEntry(
                      value: device,
                      label: device.name.isEmpty ? device.id : device.name,
                      enabled: true,
                      style: MenuItemButton.styleFrom(
                          foregroundColor: Colors.black),
                    )),
              ],
            ),
            _buildDataCard(
                'Battery SoC', '${obd2Data['soc']?.toStringAsFixed(1)}%'),
            _buildDataCard('Battery Voltage',
                '${obd2Data['voltage']?.toStringAsFixed(1)}V'),
            _buildDataCard(
                'Speed', '${obd2Data['speed']?.toStringAsFixed(1)} km/h'),
            _buildDataCard('Hex Data', '${obd2Data['full']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(title),
        trailing: Text(value),
      ),
    );
  }
}
