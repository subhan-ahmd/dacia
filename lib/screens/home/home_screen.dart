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
              ref.read(oBD2DataProvider.notifier).reset();
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
            if (obd2Data['error'] != null)
              Card(
                margin: const EdgeInsets.all(8.0),
                color: Colors.red.shade100,
                child: ListTile(
                  title: Text('Error: ${obd2Data['error']}'),
                ),
              ),
            _buildDataCard('Connection Status', '${obd2Data['connectionStatus']}'),
            _buildDataCard('Initialization Status',
                obd2Data['isInitialized'] ? 'Initialized' : 'Not Initialized'),
            _buildDataCard('CAN Mode', '${obd2Data['canMode']}'),
            _buildDataCard('Current CAN ID', '${obd2Data['currentCanId']}'),
            _buildDataCard('Battery Voltage',
                '${obd2Data['voltage']?.toStringAsFixed(1)}V'),
            _buildDataCard(
                'Speed', '${obd2Data['speed']?.toStringAsFixed(1)} km/h'),
            _buildDataCard('Battery Temperature',
                '${obd2Data['temperature']?.toStringAsFixed(1)}°C'),
            _buildDataCard('Battery Current',
                '${obd2Data['current']?.toStringAsFixed(1)}A'),
            _buildDataCard('Last Command', '${obd2Data['lastCommand']}'),
            _buildDataCard('Last Response', '${obd2Data['lastResponse']}'),
            _buildDataCard('Raw Hex Data', '${obd2Data['raw']}'),
            _buildHexDataCard('Decoded Data', obd2Data['raw']),
            if (obd2Data['lastUpdate'] != null)
              Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text('Last Update: ${obd2Data['lastUpdate']}'),
                ),
              ),
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
        trailing: Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildHexDataCard(String title, String? hexData) {
    if (hexData == null || hexData.isEmpty) {
      return _buildDataCard(title, 'No data');
    }

    String decodedValue = '';
    try {
      // Convert hex to bytes
      List<int> bytes = [];
      for (int i = 0; i < hexData.length; i += 2) {
        if (i + 1 < hexData.length) {
          bytes.add(int.parse(hexData.substring(i, i + 2), radix: 16));
        }
      }

      // Try to decode as ASCII string
      String asciiString = String.fromCharCodes(bytes);
      if (asciiString.contains(RegExp(r'[A-Za-z0-9\s]'))) {
        decodedValue = asciiString;
      } else {
        // If not readable ASCII, show as decimal values
        decodedValue = bytes.map((b) => b.toString()).join(', ');
      }
    } catch (e) {
      decodedValue = 'Error decoding: $e';
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          'Decoded: $decodedValue',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
        trailing: Text(
          'Hex: $hexData',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}