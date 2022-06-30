import 'package:collection/collection.dart';
import 'package:flutter_blue/flutter_blue.dart';

class BleDevice {
  final BluetoothDevice bluetoothDevice;
  final String name;
  int rssi;

  String get id => bluetoothDevice.id.id;

  BleDevice(ScanResult scanResult)
      : bluetoothDevice = scanResult.device,
        name = scanResult.device.name,
        rssi = scanResult.rssi;

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator == (other) =>
      other is BleDevice && compareAsciiLowerCase(name, other.name) == 0 &&
      id == other.id &&
      rssi == other.rssi;

  @override
  String toString() {
    return 'BleDevice {name: $name, id: $id, rssid: $rssi}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rssi': rssi,
      'peripheral': bluetoothDevice,
    };
  }

  int compareTo(BleDevice other) {
    if (rssi > other.rssi) {
      return -1;
    }
    if (rssi == other.rssi) {
      return 0;
    }
    return 1;
  }
}
