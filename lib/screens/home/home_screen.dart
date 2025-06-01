import 'package:dacia/providers/connected_devices_provider.dart';
import 'package:dacia/providers/obd2_data.dart';
import 'package:dacia/providers/selected_device_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../providers/available_devices.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final devicesProvider = ref.watch(deviceManagerProvider);
    final connectedDevices = ref.watch(connectedDevicesProvider.notifier);
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final obd2Data = ref.watch(oBD2DataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dacia Spring'),
        actions: [
          Container(
            height: 12,
            width: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connectedDevices.isDeviceConnected(id: selectedDevice?.address)
                  ? Colors.green
                  : Colors.red,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref.read(connectedDevicesProvider.notifier).disconnect();
              ref.read(oBD2DataProvider.notifier).reset();
              ref.invalidate(deviceManagerProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeletonizer(
              enabled: devicesProvider.isLoading || devicesProvider.hasError,
              child: DropdownMenu<BluetoothDevice>(
                width: double.maxFinite,
                menuHeight: 150,
                requestFocusOnTap: true,
                label: const Text('Bluetooth Devices'),
                onSelected: (BluetoothDevice? device) async {
                  if (device != null) {
                    ref.read(selectedDeviceProvider.notifier).select(device);
                    await ref.read(connectedDevicesProvider.notifier).connect();
                  }
                },
                dropdownMenuEntries: devicesProvider.when(
                  error: (error, stackTrace) {
                    print("$error\n$stackTrace");
                    return [];
                  },
                  loading: () => [],
                  data: (devices) => [
                    ...devices.map((device) => DropdownMenuEntry(
                          value: device,
                          label: device.name!=null
                              ? (device.name??"")
                              : device.address,
                          enabled: true,
                          style: MenuItemButton.styleFrom(
                              foregroundColor: Colors.black),
                        )),
                  ],
                ),
              ),
            ),
            if (obd2Data['error'] != null)
              _buildErrorCard(obd2Data['error']),
            _buildConnectionStatusCard(obd2Data),
            _buildVehicleDataCard(obd2Data),
            _buildRawDataCard(obd2Data),
            _buildMetadataCard(obd2Data),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String? error) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: Colors.red.shade100,
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: Text('Error: $error'),
      ),
    );
  }

  Widget _buildConnectionStatusCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: Icon(
          data['connectionStatus'] == 'Connected'
              ? Icons.bluetooth_connected
              : Icons.bluetooth_disabled,
          color: data['connectionStatus'] == 'Connected'
              ? Colors.green
              : Colors.grey,
        ),
        title: const Text('Connection Status'),
        trailing: Text(data['connectionStatus']),
      ),
    );
  }

  Widget _buildVehicleDataCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const ListTile(
            title: Text('Vehicle Data', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          _buildDataRow('Battery Voltage', '${data['voltage']?.toStringAsFixed(1)} V'),
          _buildDataRow('Speed', '${data['speed']?.toStringAsFixed(1)} km/h'),
          _buildDataRow('Battery Temperature', '${data['temperature']?.toStringAsFixed(1)} °C'),
          _buildDataRow('Battery Current', '${data['current']?.toStringAsFixed(1)} A'),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRawDataCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const ListTile(
            title: Text('Raw Data', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (data['canId']?.isNotEmpty ?? false)
            _buildDataRow('CAN ID', data['canId']),
          if (data['pid']?.isNotEmpty ?? false)
            _buildDataRow('PID', data['pid']),
          if (data['raw']?.isNotEmpty ?? false)
            _buildHexDataRow(data['raw']),
        ],
      ),
    );
  }

  Widget _buildHexDataRow(String? hexData) {
    if (hexData == null || hexData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No data'),
      );
    }

    String decodedValue = '';
    try {
      List<int> bytes = [];
      for (int i = 0; i < hexData.length; i += 2) {
        if (i + 1 < hexData.length) {
          bytes.add(int.parse(hexData.substring(i, i + 2), radix: 16));
        }
      }

      String asciiString = String.fromCharCodes(bytes);
      if (asciiString.contains(RegExp(r'[A-Za-z0-9\s]'))) {
        decodedValue = asciiString;
      } else {
        decodedValue = bytes.map((b) => b.toString()).join(', ');
      }
    } catch (e) {
      decodedValue = 'Error decoding: $e';
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hex: $hexData'),
          const SizedBox(height: 4),
          Text('Decoded: $decodedValue', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const ListTile(
            title: Text('Metadata', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (data['lastUpdate'] != null)
            _buildDataRow('Last Update', _formatDateTime(data['lastUpdate'])),
          if (data['timestamp'] != null)
            _buildDataRow('Timestamp', '${data['timestamp']} ms'),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}:'
           '${dateTime.second.toString().padLeft(2, '0')}';
  }
}