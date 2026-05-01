import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Garmin device info
class GarminDevice {
  final BluetoothDevice device;
  final String name;
  final String id;

  GarminDevice({required this.device, required this.name, required this.id});

  @override
  String toString() => 'GarminDevice(name: $name, id: $id)';
}

/// Connection state enum
enum BleConnectionState { disconnected, connecting, connected }

/// BLE service for Garmin device management
class GarminBleService {
  // Unified Garmin Service UUID
  static const String _garminServiceUuid = '0000FE1F-0000-1000-8000-00805F9B34FB';
  // Navigation write characteristic
  static const String _navWriteUuid = '6A4E8022-667B-11E3-949A-0800200C9A66';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;

  final _scanResultsController = StreamController<List<GarminDevice>>.broadcast();
  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<List<GarminDevice>> get scanResults => _scanResultsController.stream;
  Stream<BleConnectionState> get connectionState => _connectionStateController.stream;
  Stream<String> get errors => _errorController.stream;

  BleConnectionState _state = BleConnectionState.disconnected;
  BleConnectionState get state => _state;

  List<GarminDevice> _devices = [];

  /// Start scanning for Garmin devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    _devices.clear();

    // Check Bluetooth state
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      _errorController.add('Bluetooth is not enabled');
      return;
    }

    // Start scan
    await FlutterBluePlus.startScan(timeout: timeout);

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      _devices = results
          .where((r) =>
              r.device.platformName.contains('GARMIN') ||
              r.device.platformName.contains('Fenix') ||
              r.device.platformName.contains('Forerunner') ||
              r.device.platformName.contains('Edge'))
          .map((r) => GarminDevice(
                device: r.device,
                name: r.device.platformName,
                id: r.device.remoteId.str,
              ))
          .toList();

      _scanResultsController.add(_devices);
    });

    // Stop scan after timeout
    Future.delayed(timeout, () => stopScan());
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to a device
  Future<bool> connect(GarminDevice garminDevice) async {
    _state = BleConnectionState.connecting;
    _connectionStateController.add(_state);

    try {
      _connectedDevice = garminDevice.device;

      // Connect with timeout
      await Future.any([
        garminDevice.device.connect(timeout: const Duration(seconds: 15)),
        Future.delayed(const Duration(seconds: 16), () => throw TimeoutException('connect')),
      ]);

      _state = BleConnectionState.connected;
      _connectionStateController.add(_state);

      // Discover services
      await _discoverServices();

      return true;
    } catch (e) {
      _state = BleConnectionState.disconnected;
      _connectionStateController.add(_state);
      _errorController.add('Connection failed: $e');
      return false;
    }
  }

  /// Discover GATT services and find write characteristic
  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;

    final services = await _connectedDevice!.discoverServices();

    for (final service in services) {
      if (service.uuid.toString().toUpperCase().contains(_garminServiceUuid.toUpperCase())) {
        // Found Garmin service, find write characteristic
        for (final char in service.characteristics) {
          if (char.uuid.toString().toUpperCase().contains(_navWriteUuid.toUpperCase()) ||
              char.uuid.toString().toUpperCase().contains('6A4E8022')) {
            _writeCharacteristic = char;
            return;
          }
        }
      }
    }
  }

  /// Write route data to device
  /// [data] - raw bytes to write (will be chunked by MTU)
  Future<bool> writeRouteData(List<int> data) async {
    if (_writeCharacteristic == null) {
      _errorController.add('Write characteristic not found');
      return false;
    }

    // Get MTU (negotiated size minus 3 bytes header)
    final mtu = await _connectedDevice?.mtu.first ?? 517;
    final chunkSize = mtu - 3;

    try {
      // Write in chunks
      for (int offset = 0; offset < data.length; offset += chunkSize) {
        final end = (offset + chunkSize < data.length) ? offset + chunkSize : data.length;
        final chunk = data.sublist(offset, end);

        await _writeCharacteristic!.write(chunk, withoutResponse: false);

        // Small delay between writes to avoid buffer overflow
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return true;
    } catch (e) {
      _errorController.add('Write failed: $e');
      return false;
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _writeCharacteristic = null;
    _state = BleConnectionState.disconnected;
    _connectionStateController.add(_state);
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _scanResultsController.close();
    _connectionStateController.close();
    _errorController.close();
  }
}