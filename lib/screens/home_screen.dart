import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_chat_app/screens/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> devicesList = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _checkBluetoothPermissionsAndScan();
  }

  Future<void> _checkBluetoothPermissionsAndScan() async {
    // Request necessary permissions
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();

    // Check if Bluetooth is available and turned on
    if (!await flutterBlue.isOn) {
      _showBluetoothDialog(); // Show dialog if Bluetooth is off
      return;
    }

    _startScan();
  }

  void _startScan() async {
    if (!isScanning) {
      setState(() {
        isScanning = true;
      });

      try {
        // Check for permissions before starting the scan
        final bluetoothScanStatus = await Permission.bluetoothScan.isGranted;
        final bluetoothConnectStatus =
            await Permission.bluetoothConnect.isGranted;

        if (!bluetoothScanStatus || !bluetoothConnectStatus) {
          log("Bluetooth scan or connect permission not granted.");
          // Optionally, request permissions here
          return;
        }

        // Start scanning for devices
        await flutterBlue.startScan(timeout: const Duration(seconds: 4));

        // Listen for scan results
        flutterBlue.scanResults.listen((scanResults) {
          for (var scanResult in scanResults) {
            final device = scanResult.device;

            // Check if the device is already in the list to avoid duplicates
            if (!devicesList.contains(device)) {
              setState(() {
                devicesList.add(device);
              });
            }
          }
        });

        // Also check for already connected devices
        List<BluetoothDevice> bondedDevices =
            await flutterBlue.connectedDevices;
        for (var device in bondedDevices) {
          // Add bonded devices to the list if not already added
          if (!devicesList.contains(device)) {
            setState(() {
              devicesList.add(device);
            });
          }
        }
      } catch (e) {
        log("Error starting scan: $e");
      } finally {
        // Stop scanning after the scan duration or on error
        await flutterBlue.stopScan();
        setState(() {
          isScanning = false;
        });
      }
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    // Listen to the state stream
    device.state.listen((state) async {
      if (state == BluetoothDeviceState.connected) {
        log("Device is already connected.");
        // Navigate to ChatScreen directly if already connected
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(device: device),
          ),
        );
      } else if (state == BluetoothDeviceState.disconnected) {
        log("Attempting to connect to device: ${device.name}");
        try {
          await device.connect();
          log("Connected to device: ${device.name}");

          // Navigate to ChatScreen after a successful connection
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(device: device),
            ),
          );
        } catch (e) {
          log("Error connecting to device: $e");
        }
      } else {
        log("Device is in a state other than disconnected: $state");
      }
    });
  }

  void _showBluetoothDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Bluetooth is Off"),
          content: const Text(
              "Please turn on Bluetooth to continue. Go to Settings > Bluetooth to enable it."),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bluetooth Chat"),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.refresh),
            onPressed: _checkBluetoothPermissionsAndScan,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(devicesList[index].name),
                  subtitle: Text(devicesList[index].id.toString()),
                  onTap: () => _connectToDevice(devicesList[index]),
                );
              },
            ),
          ),
          if (isScanning) const CircularProgressIndicator(),
        ],
      ),
    );
  }
}
