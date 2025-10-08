import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:parachute/models/omi_device.dart';
import 'package:parachute/services/omi/device_connection.dart';
import 'package:parachute/services/omi/models.dart';
import 'package:parachute/services/omi/omi_connection.dart';
import 'package:parachute/utils/platform_utils.dart';

/// Service status for the Bluetooth manager
enum OmiBluetoothServiceStatus {
  init,
  ready,
  scanning,
  stopped,
}

/// Manages Bluetooth scanning, device discovery, and connection to Omi devices
///
/// This service handles:
/// - BLE scanning for Omi devices
/// - Device connection management
/// - Auto-reconnect functionality
/// - Connection state monitoring
class OmiBluetoothService {
  OmiBluetoothServiceStatus _status = OmiBluetoothServiceStatus.init;
  List<OmiDevice> _discoveredDevices = [];
  List<ScanResult> _scanResults = [];

  DeviceConnection? _activeConnection;
  StreamSubscription<OnConnectionStateChangedEvent>?
      _connectionStateSubscription;

  DateTime? _firstConnectedAt;

  // Getters
  OmiBluetoothServiceStatus get status => _status;
  List<OmiDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  DeviceConnection? get activeConnection => _activeConnection;
  DateTime? get firstConnectedAt => _firstConnectedAt;

  /// Start the Bluetooth service
  void start() {
    if (_status == OmiBluetoothServiceStatus.stopped) {
      debugPrint('[OmiBluetoothService] Cannot start - service is stopped');
      return;
    }

    // Check platform support
    if (!PlatformUtils.isBleSupported) {
      debugPrint(
          '[OmiBluetoothService] BLE not supported on ${PlatformUtils.platformName}');
      _status = OmiBluetoothServiceStatus.stopped;
      return;
    }

    _status = OmiBluetoothServiceStatus.ready;
    debugPrint(
        '[OmiBluetoothService] Service started on ${PlatformUtils.platformName}');

    // Listen to global connection state changes
    _connectionStateSubscription =
        FlutterBluePlus.events.onConnectionStateChanged.listen(
      _onConnectionStateChanged,
    );
  }

  /// Stop the Bluetooth service
  Future<void> stop() async {
    debugPrint('[OmiBluetoothService] Stopping service');

    _status = OmiBluetoothServiceStatus.stopped;

    // Stop any ongoing scan
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    // Disconnect active connection
    if (_activeConnection != null) {
      await _activeConnection!.disconnect();
      _activeConnection = null;
    }

    // Cancel connection state listener
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    _discoveredDevices.clear();
    _scanResults.clear();

    debugPrint('[OmiBluetoothService] Service stopped');
  }

  /// Scan for nearby Omi devices
  Future<void> scanForDevices({
    int timeoutSeconds = 5,
    Function(List<OmiDevice>)? onDevicesFound,
  }) async {
    if (_status == OmiBluetoothServiceStatus.stopped) {
      throw Exception('Service is stopped');
    }

    if (_status == OmiBluetoothServiceStatus.scanning) {
      debugPrint('[OmiBluetoothService] Already scanning');
      return;
    }

    // Check if Bluetooth is supported
    if (!(await FlutterBluePlus.isSupported)) {
      throw Exception('Bluetooth is not supported on this device');
    }

    // Check if already scanning
    if (FlutterBluePlus.isScanningNow) {
      debugPrint('[OmiBluetoothService] Scan already in progress');
      return;
    }

    debugPrint(
        '[OmiBluetoothService] Starting device scan (${timeoutSeconds}s)');
    _status = OmiBluetoothServiceStatus.scanning;

    // Clear previous results
    _discoveredDevices.clear();
    _scanResults.clear();

    // Listen to scan results
    final scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        _processScanResults(results);
        onDevicesFound?.call(_discoveredDevices);
      },
      onError: (e) {
        debugPrint('[OmiBluetoothService] Scan error: $e');
      },
    );

    FlutterBluePlus.cancelWhenScanComplete(scanSubscription);

    // Wait for Bluetooth adapter to be on
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      debugPrint('[OmiBluetoothService] Waiting for Bluetooth to be enabled');
      await FlutterBluePlus.adapterState
          .where((state) => state == BluetoothAdapterState.on)
          .first;
    }

    // Start scan with service UUID filter
    try {
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeoutSeconds),
        withServices: [Guid(omiServiceUuid)],
      );

      debugPrint('[OmiBluetoothService] Scan started');
    } catch (e) {
      debugPrint('[OmiBluetoothService] Error starting scan: $e');
      _status = OmiBluetoothServiceStatus.ready;
      rethrow;
    }

    // Wait for scan to complete
    await FlutterBluePlus.isScanning.where((isScanning) => !isScanning).first;

    _status = OmiBluetoothServiceStatus.ready;
    debugPrint(
        '[OmiBluetoothService] Scan complete - found ${_discoveredDevices.length} devices');
  }

  /// Process scan results and convert to OmiDevice objects
  void _processScanResults(List<ScanResult> results) {
    _scanResults = results;

    // Filter devices with names and convert to OmiDevice
    final devices = results
        .where((result) => result.device.platformName.isNotEmpty)
        .map((result) => OmiDevice(
              id: result.device.remoteId.toString(),
              name: result.device.platformName,
              type: DeviceType.omi, // TODO: Detect type from services
              rssi: result.rssi,
            ))
        .toList();

    // Sort by signal strength (strongest first)
    devices.sort((a, b) => b.rssi.compareTo(a.rssi));

    _discoveredDevices = devices;
    debugPrint('[OmiBluetoothService] Processed ${devices.length} devices');
  }

  /// Connect to a specific device
  Future<DeviceConnection?> connectToDevice(
    String deviceId, {
    Function(String deviceId, DeviceConnectionState state)?
        onConnectionStateChanged,
  }) async {
    debugPrint('[OmiBluetoothService] Connecting to device: $deviceId');

    // Disconnect existing connection if any
    if (_activeConnection != null) {
      debugPrint('[OmiBluetoothService] Disconnecting existing connection');
      await _activeConnection!.disconnect();
      _activeConnection = null;
    }

    // Find device in scan results
    final scanResult = _scanResults.firstWhereOrNull(
      (result) => result.device.remoteId.toString() == deviceId,
    );

    if (scanResult == null) {
      debugPrint('[OmiBluetoothService] Device not found in scan results');
      return null;
    }

    final omiDevice = _discoveredDevices.firstWhereOrNull(
      (device) => device.id == deviceId,
    );

    if (omiDevice == null) {
      debugPrint(
          '[OmiBluetoothService] Device not found in discovered devices');
      return null;
    }

    // Create connection
    _activeConnection = OmiDeviceConnection(
      device: omiDevice,
      bleDevice: scanResult.device,
    );

    // Connect
    try {
      await _activeConnection!.connect(
        onConnectionStateChanged: onConnectionStateChanged,
      );

      _firstConnectedAt ??= DateTime.now();
      debugPrint('[OmiBluetoothService] Connected successfully');

      return _activeConnection;
    } catch (e) {
      debugPrint('[OmiBluetoothService] Connection failed: $e');
      _activeConnection = null;
      rethrow;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_activeConnection != null) {
      debugPrint('[OmiBluetoothService] Disconnecting');
      await _activeConnection!.disconnect();
      _activeConnection = null;
    }
  }

  /// Auto-reconnect to a previously connected device
  Future<DeviceConnection?> reconnectToDevice(
    String deviceId, {
    Function(String deviceId, DeviceConnectionState state)?
        onConnectionStateChanged,
  }) async {
    debugPrint('[OmiBluetoothService] Attempting to reconnect to: $deviceId');

    // First try to scan for the device
    await scanForDevices(timeoutSeconds: 10);

    // Try to connect
    return await connectToDevice(
      deviceId,
      onConnectionStateChanged: onConnectionStateChanged,
    );
  }

  /// Handle global connection state changes
  void _onConnectionStateChanged(OnConnectionStateChangedEvent event) {
    final deviceId = event.device.remoteId.toString();
    final isConnected =
        event.connectionState == BluetoothConnectionState.connected;

    debugPrint(
        '[OmiBluetoothService] Connection state changed: $deviceId -> ${event.connectionState}');

    if (!isConnected && _activeConnection?.device.id == deviceId) {
      debugPrint('[OmiBluetoothService] Active device disconnected');
      _activeConnection = null;
    }
  }

  /// Check if device is currently connected
  bool get isConnected =>
      _activeConnection != null &&
      _activeConnection!.status == DeviceConnectionState.connected;

  /// Get connected device
  OmiDevice? get connectedDevice => _activeConnection?.device;
}
