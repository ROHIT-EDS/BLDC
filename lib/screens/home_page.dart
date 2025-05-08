import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controller_screen.dart';
import 'scanning.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  final String title;
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Map<String, String> _deviceRooms = {};
  final Map<String, String> _deviceNames = {};
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    _prefs = await SharedPreferences.getInstance();
    _deviceRooms.clear(); // Clear existing devices
    _deviceNames.clear();
    final keys = _prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('device_') && !key.startsWith('device_name_')) {
        final deviceId = key.replaceFirst('device_', '');
        _deviceRooms[deviceId] = _prefs.getString(key) ?? 'Default';
        _deviceNames[deviceId] =
            _prefs.getString('device_name_$deviceId') ?? 'Unknown Device';
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text(
          'BLDC Fan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _deviceRooms.isEmpty
                      ? Center(
                        child: Text(
                          'No devices added yet',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      )
                      : GridView.builder(
                        padding: const EdgeInsets.all(16.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16.0,
                              mainAxisSpacing: 16.0,
                              childAspectRatio: 0.8,
                            ),
                        itemCount: _deviceRooms.length,
                        itemBuilder: (context, index) {
                          final deviceId = _deviceRooms.keys.elementAt(index);
                          final deviceName =
                              _deviceNames[deviceId] ?? 'Unknown Device';
                          final roomName = _deviceRooms[deviceId] ?? 'Default';

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ControllerScreen(
                                        deviceId: deviceId,
                                        deviceName: deviceName,
                                        roomName: roomName,
                                      ),
                                ),
                              );
                            },
                            onLongPress: () {
                              _showDeviceOptionsDialog(
                                deviceId,
                                deviceName,
                                roomName,
                              );
                            },
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.air,
                                      size: 48,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      deviceName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Room: $roomName',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Device ID: $deviceId',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              BLEScanScreen(isDarkMode: widget.isDarkMode),
                    ),
                  );
                  _loadDevices(); // Reload devices after returning from scan screen
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Device',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceOptionsDialog(
    String deviceId,
    String deviceName,
    String roomName,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Device Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Device Name'),
                onTap: () {
                  Navigator.pop(context);
                  _editDeviceName(deviceId, deviceName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.room),
                title: const Text('Edit Room Name'),
                onTap: () {
                  Navigator.pop(context);
                  _editRoomName(deviceId, roomName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Device'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteDevice(deviceId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editDeviceName(String deviceId, String currentName) async {
    final newName = await _showInputDialog('Edit Device Name', currentName);
    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _deviceNames[deviceId] = newName;
        _prefs.setString('device_name_$deviceId', newName);
      });
    }
  }

  void _editRoomName(String deviceId, String currentRoom) async {
    final newRoom = await _showInputDialog('Edit Room Name', currentRoom);
    if (newRoom != null && newRoom.isNotEmpty) {
      setState(() {
        _deviceRooms[deviceId] = newRoom;
        _prefs.setString('device_$deviceId', newRoom);
      });
    }
  }

  void _deleteDevice(String deviceId) {
    setState(() {
      _deviceRooms.remove(deviceId);
      _deviceNames.remove(deviceId);
      _prefs.remove('device_$deviceId');
      _prefs.remove('device_name_$deviceId');
    });
  }

  Future<String?> _showInputDialog(String title, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
