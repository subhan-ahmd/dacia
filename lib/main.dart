import 'package:dacia/providers/connected_devices_provider.dart';
import 'package:dacia/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(connectedDevicesProvider);
    // Future.microtask(
    //     () => ref.read(connectedDevicesProvider.notifier).checkAndConnect());
    return MaterialApp(
      title: 'Dacia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: VehicleDataScreen(),
    );
  }
}
