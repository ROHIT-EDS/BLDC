import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BLEScanScreen extends StatefulWidget {
  final bool isDarkMode;
  const BLEScanScreen({super.key, required this.isDarkMode});

  @override
  State<BLEScanScreen> createState() => _BLEScanScreenState();
}

class _BLEScanScreenState extends State<BLEScanScreen> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  final Map<String, String> deviceRooms = {};
  List<String> predefinedRooms = [
    'Default',
    'Living Room',
    'Bedroom',
    'Kitchen',
    'Bathroom',
    'Office',
  ];
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences().then((_) async {
      await _requestPermissions(); // Request permissions before initializing Bluetooth
      _initBluetooth();
    });
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final keys = _prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('device_')) {
        deviceRooms[key.replaceFirst('device_', '')] =
            _prefs.getString(key) ?? 'Default';
      }
    }
  }

  Future<void> _saveDeviceRoom(String deviceId, String room) async {
    setState(() {
      deviceRooms[deviceId] = room;
    });
    await _prefs.setString('device_$deviceId', room);

    // Save the device name for display on the home page
    final deviceName =
        scanResults
            .firstWhere(
              (result) => result.device.remoteId.toString() == deviceId,
            )
            .device
            .platformName;
    await _prefs.setString('device_name_$deviceId', deviceName);
  }

  Future<void> _initBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      await _requestPermissions();
    }

    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _startScan();
      } else {
        setState(() => isScanning = false);
      }
    });

    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on) {
      _startScan();
    } else if (!kIsWeb && Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Check and request Bluetooth Scan permission
      if (await Permission.bluetoothScan.isDenied) {
        await Permission.bluetoothScan.request();
      }

      // Check and request Bluetooth Connect permission
      if (await Permission.bluetoothConnect.isDenied) {
        await Permission.bluetoothConnect.request();
      }

      // Check and request Location permission (required for BLE scanning on Android)
      if (await Permission.locationWhenInUse.isDenied) {
        await Permission.locationWhenInUse.request();
      }
    }
  }

  void _startScan() {
    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        setState(() {
          for (var result in results) {
            if (!scanResults.any(
              (r) => r.device.remoteId == result.device.remoteId,
            )) {
              scanResults.add(result);
            }
          }
        });
      }
    });

    FlutterBluePlus.cancelWhenScanComplete(subscription);
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    FlutterBluePlus.isScanning.where((val) => val == false).first.then((_) {
      if (mounted) setState(() => isScanning = false);
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: CircularProgressIndicator(
            color: widget.isDarkMode ? Colors.orange : Colors.blue,
          ),
        );
      },
    );

    try {
      // Connect to device
      await device.connect(autoConnect: false);

      // Discover services
      // ignore: unused_local_variable
      List<BluetoothService> services = await device.discoverServices();

      // Show room assignment dialog
      await _showRoomAssignmentDialog(device);

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.platformName}')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: ${e.toString()}')),
      );
    } finally {
      // Dismiss the loading animation
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }
  }

  Future<void> _showRoomAssignmentDialog(BluetoothDevice device) async {
    String? selectedRoom = deviceRooms[device.remoteId.toString()] ?? 'Default';
    final TextEditingController roomController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Assign ${device.platformName} to Room'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedRoom,
                    items:
                        predefinedRooms.map((room) {
                          return DropdownMenuItem(
                            value: room,
                            child: Text(room),
                          );
                        }).toList(),
                    onChanged: (value) => setState(() => selectedRoom = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Or enter new room name',
                    ),
                    onChanged: (value) => selectedRoom = value,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedRoom != null && selectedRoom!.isNotEmpty) {
                      await _saveDeviceRoom(
                        device.remoteId.toString(),
                        selectedRoom!,
                      );
                      // ignore: use_build_context_synchronously
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
        backgroundColor: theme.colorScheme.primary,
        actions: [
          if (isScanning)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan),
        ],
      ),
      body: ListView.builder(
        itemCount: scanResults.length,
        itemBuilder: (context, index) {
          final result = scanResults[index];
          final deviceName =
              result.device.platformName.isEmpty
                  ? 'Unknown Device'
                  : result.device.platformName;
          final roomName = deviceRooms[result.device.remoteId.toString()];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Device Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deviceName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.device.remoteId.toString(),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (roomName != null)
                          Text(
                            'Room: $roomName',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Connect Button
                  ElevatedButton(
                    onPressed: () => _connectToDevice(result.device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    child: const Text(
                      'Connect',
                      style: TextStyle(
                        color: Colors.white, // Set text color to white
                        fontWeight: FontWeight.bold, // Make text bold
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? null : _startScan,
        backgroundColor: theme.colorScheme.secondary,
        child: const Icon(Icons.search, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    if (isScanning) FlutterBluePlus.stopScan();
    super.dispose();
  }
}
