import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parachute/models/omi_device.dart';
import 'package:parachute/services/omi/models.dart';
import 'package:parachute/services/omi/omi_bluetooth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for OmiBluetoothService
///
/// This service manages BLE scanning, device discovery, and connections.
/// It is started automatically when first accessed and kept alive for the app lifetime.
final omiBluetoothServiceProvider = Provider<OmiBluetoothService>((ref) {
  final service = OmiBluetoothService();

  // Start service on creation
  service.start();

  // Clean up on dispose
  ref.onDispose(() async {
    await service.stop();
  });

  return service;
});

/// Provider for the current connection state
///
/// Returns the connection state of the active Omi device connection.
final omiConnectionStateProvider = Provider<DeviceConnectionState?>((ref) {
  final bluetoothService = ref.watch(omiBluetoothServiceProvider);
  return bluetoothService.activeConnection?.status;
});

/// Provider for the currently connected Omi device
///
/// Returns null if no device is connected.
final connectedOmiDeviceProvider = Provider<OmiDevice?>((ref) {
  final bluetoothService = ref.watch(omiBluetoothServiceProvider);
  return bluetoothService.connectedDevice;
});

/// Provider for discovered devices during scan
///
/// This is a StateProvider that gets updated during device scanning.
final discoveredOmiDevicesProvider = StateProvider<List<OmiDevice>>((ref) {
  return [];
});

/// Provider for the last paired device ID
///
/// Persists to SharedPreferences for auto-reconnect functionality.
final lastPairedDeviceIdProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('omi_last_paired_device_id');
});

/// Provider for the last paired device info
///
/// Returns the full OmiDevice object from SharedPreferences.
final lastPairedDeviceProvider = FutureProvider<OmiDevice?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final deviceJson = prefs.getString('omi_last_paired_device_json');

  if (deviceJson == null || deviceJson.isEmpty) {
    return null;
  }

  try {
    final json = jsonDecode(deviceJson) as Map<String, dynamic>;
    return OmiDevice.fromJson(json);
  } catch (e) {
    return null;
  }
});

/// Helper function to save paired device to SharedPreferences
Future<void> savePairedDevice(OmiDevice device) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('omi_last_paired_device_id', device.id);
  await prefs.setString(
      'omi_last_paired_device_json', jsonEncode(device.toJson()));
}

/// Helper function to clear paired device from SharedPreferences
Future<void> clearPairedDevice() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('omi_last_paired_device_id');
  await prefs.remove('omi_last_paired_device_json');
}

/// Provider for auto-reconnect preference
final autoReconnectEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('omi_auto_reconnect_enabled') ?? true; // Default to true
});

/// Helper function to save auto-reconnect preference
Future<void> setAutoReconnectEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('omi_auto_reconnect_enabled', enabled);
}
