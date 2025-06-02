import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ControllerScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final String roomName;

  const ControllerScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.roomName,
  });

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  late BluetoothCharacteristic characteristic;
  bool _isPowerOn = false;
  double _fanSpeed = 0.0;
  bool _isOscillationOn = false;
  int _timerValue = 0;
  String _fanMode = "Sleep";

  @override
  void initState() {
    super.initState();
    _initializeCharacteristic();
  }

  Future<void> _initializeCharacteristic() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        BluetoothDevice device = BluetoothDevice.fromId(widget.deviceId);

        // Ensure the device is connected
        if (await device.connectionState.first !=
            BluetoothConnectionState.connected) {
          await device.connect();
        }

        // Discover services
        List<BluetoothService> services = await device.discoverServices();

        // Debug: Print all services and characteristics
        for (var service in services) {
          print('Service: ${service.uuid}');
          for (var char in service.characteristics) {
            print('Characteristic: ${char.uuid}');
          }
        }

        // Find the desired characteristic
        for (var service in services) {
          for (var char in service.characteristics) {
            if (char.uuid.toString() ==
                '00002a37-0000-1000-8000-00805f9b34fb') {
              characteristic = char;
              print('Characteristic initialized: ${char.uuid}');
              return;
            }
          }
        }

        throw 'Characteristic not found';
      } catch (e) {
        print('Attempt ${attempt + 1} failed: $e');
        if (attempt == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to initialize characteristic: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendBluetoothCommand(String command) async {
    try {
      await characteristic.write(utf8.encode(command), withoutResponse: true);
      print('Command sent: $command');
    } catch (e) {
      print('Error sending command: $e');
      throw 'Failed to send command: $e';
    }
  }

  void _toggleFan() async {
    try {
      if (_isPowerOn) {
        // Send code to turn off the fan
        await _sendBluetoothCommand('0x06');
      } else {
        // Send code to turn on the fan
        await _sendBluetoothCommand('0x0E');
      }

      // Update the UI state
      setState(() {
        _isPowerOn = !_isPowerOn;
        if (!_isPowerOn) {
          _fanSpeed = 0.0;
          _isOscillationOn = false;
        }
      });
    } catch (e) {
      // Handle any errors (e.g., Bluetooth connection issues)
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send command: $e')));
    }
  }

  void _changeSpeed(double value) async {
    try {
      setState(() {
        _fanSpeed = value;
      });

      // Send the appropriate command based on the fan speed
      String command;
      switch (_fanSpeed.toInt()) {
        case 1:
          command = '0x05';
          break;
        case 2:
          command = '0x0F';
          break;
        case 3:
          command = '0x0A';
          break;
        case 4:
          command = '0x03';
          break;
        case 5:
          command = '0x02';
          break;
        default:
          return; // Do nothing for speed 0 or invalid values
      }

      await _sendBluetoothCommand(command);
    } catch (e) {
      // Handle any errors (e.g., Bluetooth connection issues)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to change speed: $e')));
    }
  }

  void _toggleOscillation() {
    setState(() {
      _isOscillationOn = !_isOscillationOn;
    });
  }

  void _changeMode() async {
    try {
      switch (_fanMode) {
        case "Sleep":
          _fanMode = "Speed Mode";
          await _sendBluetoothCommand('0x1A'); // Send command for Speed Mode
          break;
        case "Speed Mode":
          _fanMode = "Boost Mode";
          await _sendBluetoothCommand('0x0C'); // Send command for Boost Mode
          break;
        case "Boost Mode":
          _fanMode = "Sleep";
          await _sendBluetoothCommand('0x06'); // Send command for Sleep Mode
          break;
      }

      // Update the UI
      setState(() {});
    } catch (e) {
      // Handle any errors (e.g., Bluetooth connection issues)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to change modes: $e')));
    }
  }

  void _showTimerDialog() {
    // Timer options in minutes and their corresponding commands
    final Map<int, String> timerCommands = {
      5: '0x1F', // Turn Off Fan After 5 Min
      30: '0xDD', // Turn Off Fan After 30 Min
      60: '0x10', // Turn Off Fan After 1 Hr
      120: '0x0D', // Turn Off Fan After 2 Hr
      240: '0x01', // Turn Off Fan After 4 Hr
      360: '0x09', // Turn Off Fan After 6 Hr
      480: '0x07', // Turn Off Fan After 8 Hr
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Timer'),
          content: SizedBox(
            height: 200,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: timerCommands.keys.length,
              itemBuilder: (context, index) {
                final minutes = timerCommands.keys.elementAt(index);
                return GestureDetector(
                  onTap: () async {
                    setState(() {
                      _timerValue = minutes;
                    });

                    // Send the corresponding Bluetooth command
                    final command = timerCommands[minutes];
                    if (command != null) {
                      await _sendBluetoothCommand(command);
                    }

                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          _timerValue == minutes
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        minutes < 60
                            ? '$minutes min'
                            : '${minutes ~/ 60} hr', // Convert minutes to hours if >= 60
                        style: TextStyle(
                          color:
                              _timerValue == minutes
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        title: Text(
          widget.deviceName,
          style: TextStyle(color: colorScheme.onPrimary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.bluetooth_disabled, color: colorScheme.onPrimary),
            onPressed: () {
              // TODO: Implement disconnect functionality
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                'Room: ${widget.roomName}',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              ),
              const SizedBox(height: 20),
              // Power and Oscillation Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    // Power Control
                    _buildControlCard(
                      icon:
                          _isPowerOn
                              ? Icons.power_settings_new
                              : Icons.power_off,
                      label: 'Power',
                      isActive: _isPowerOn,
                      onTap: _toggleFan,
                    ),
                    // Oscillation Control
                    _buildControlCard(
                      icon: Icons.sync,
                      label: 'Oscillation',
                      isActive: _isOscillationOn,
                      onTap: _isPowerOn ? _toggleOscillation : null,
                    ),
                    // Fan Mode Control
                    _buildControlCard(
                      icon: Icons.speed,
                      label: 'Fan Mode',
                      isActive: _isPowerOn,
                      onTap: _isPowerOn ? _changeMode : null,
                      extraLabel: _fanMode, // Displays the current fan mode
                    ),
                    // Timer Control
                    _buildControlCard(
                      icon: Icons.timer,
                      label: 'Timer',
                      isActive: _isPowerOn,
                      onTap: _isPowerOn ? _showTimerDialog : null,
                      extraLabel: _timerValue == 0 ? 'Off' : '$_timerValue min',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Fan Speed Control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Fan Speed',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SfRadialGauge(
                      axes: <RadialAxis>[
                        RadialAxis(
                          minimum: 0,
                          maximum: 5,
                          interval: 1,
                          pointers: <GaugePointer>[
                            RangePointer(
                              value: _fanSpeed,
                              color: colorScheme.primary,
                              enableAnimation: true,
                            ),
                            MarkerPointer(
                              value: _fanSpeed,
                              markerType: MarkerType.circle,
                              color: colorScheme.onSurface,
                              markerHeight: 15,
                              markerWidth: 15,
                              enableDragging: true,
                              onValueChanged: (value) {
                                _changeSpeed(value); // Calls the updated method
                              },
                            ),
                          ],
                          annotations: <GaugeAnnotation>[
                            GaugeAnnotation(
                              widget: Text(
                                '${_fanSpeed.toInt()}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              positionFactor: 0.1,
                              angle: 90,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback? onTap,
    String? extraLabel,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color:
                    isActive
                        ? colorScheme.primary
                        : colorScheme.onSurface.withAlpha(
                          128,
                        ), // Fixed alpha value
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
              ),
              if (extraLabel != null) ...[
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    extraLabel,
                    style: TextStyle(
                      color:
                          isActive
                              ? colorScheme.primary
                              : colorScheme.onSurface.withAlpha(
                                128,
                              ), // Fixed alpha value
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
