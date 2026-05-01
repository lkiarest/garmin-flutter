import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import 'map_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GarminBleService _btService = GarminBleService();

  List<GarminDevice> _devices = [];
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  bool _isScanning = false;
  String? _error;

  StreamSubscription<List<GarminDevice>>? _scanSub;
  StreamSubscription<BleConnectionState>? _connSub;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _setupListeners();
  }

  void _setupListeners() {
    _scanSub = _btService.scanResults.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });

    _connSub = _btService.connectionState.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });

    _errorSub = _btService.errors.listen((err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
        );
      }
    });
  }

  Future<void> _initBluetooth() async {
    // Request permissions
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Check if Bluetooth is on
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (mounted) setState(() => _error = 'Please enable Bluetooth');
      return;
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    if (mounted) {
      setState(() {
        _isScanning = true;
        _devices = [];
        _error = null;
      });
    }

    await _btService.startScan(timeout: const Duration(seconds: 10));

    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connect(GarminDevice device) async {
    final success = await _btService.connect(device);
    if (!success || !mounted) return;

    // Navigate to map page
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MapPage(bluetoothService: _btService),
      ),
    );
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _errorSub?.cancel();
    _btService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Garmin Navigation'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _isScanning ? _btService.stopScan : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _getStatusColor(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getStatusIcon(), color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Error message
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Scanning for Garmin devices...'
                              : 'No devices found.\nTap refresh to scan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        if (_isScanning) ...[
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: const Icon(Icons.watch, color: Colors.blue),
                        title: Text(device.name),
                        subtitle: Text('ID: ${device.id}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _connect(device),
                      );
                    },
                  ),
          ),

          // Scan button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_connectionState) {
      case BleConnectionState.connected:
        return Colors.green;
      case BleConnectionState.connecting:
        return Colors.orange;
      case BleConnectionState.disconnected:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_connectionState) {
      case BleConnectionState.connected:
        return Icons.bluetooth_connected;
      case BleConnectionState.connecting:
        return Icons.bluetooth_searching;
      case BleConnectionState.disconnected:
        return Icons.bluetooth_disabled;
    }
  }

  String _getStatusText() {
    switch (_connectionState) {
      case BleConnectionState.connected:
        return 'Connected';
      case BleConnectionState.connecting:
        return 'Connecting...';
      case BleConnectionState.disconnected:
        return 'Disconnected';
    }
  }
}
