import 'dart:async';
import 'dart:io';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:logger/logger.dart';
import 'package:esp_provisioning/esp_provisioning.dart';
import 'package:permission_handler/permission_handler.dart';


class BleService {
  static BleService? _instance;
  static final FlutterBlue _ble = FlutterBlue.instance;
  // static BleManager _bleManager;
  static Logger log = Logger(printer: PrettyPrinter());
  bool _isPowerOn = false;
  BluetoothDevice? selectedBluetoothDevice;

  static BleService getInstance() {
    _instance ??= BleService();
    log.v('BleService started');
    return _instance!;
  }

  Future<BluetoothState> start() async {
    log.i('Ble sevice start');
    if (_isPowerOn) {
      var state = await _waitForBluetoothPoweredOn();
      log.i('Device power was on $state');
      return state;
    }
    var isPermissionOk = await requestBlePermissions();
    if (!isPermissionOk) {
      throw Future.error(Exception('Location permission not granted'));
    }

    log.v('createClient');
    
    _ble.scanResults.listen((List<ScanResult> results) { 
      // restoreStateIdentifier: "example-ble-client-id",
      for (var result in results) {
        BluetoothDevice bluetoothDevice = result.device;
        log.v("Restored bluetoothDevice: ${bluetoothDevice.name}");
        selectedBluetoothDevice = bluetoothDevice;
      }
    });

    var state = await _waitForBluetoothPoweredOn();
    _isPowerOn = true;
    return state;
  }

  void select(BluetoothDevice bluetoothDevice) {
    selectedBluetoothDevice = bluetoothDevice;
    log.v('selectedPeripheral = $selectedBluetoothDevice');
  }

  Future<bool> stop() async {
    if (!_isPowerOn) {
      return true;
    }
    _isPowerOn = false;
    stopScanBle();
    
    BluetoothDeviceState? deviceState = (await selectedBluetoothDevice?.state.first);
    bool _check = deviceState == BluetoothDeviceState.connected || deviceState == BluetoothDeviceState.connecting;
    if(_check) {
      selectedBluetoothDevice?.disconnect();
    }

    return true;
  }

  Stream<List<ScanResult>> scanBle() {
    stopScanBle();
    _ble.startScan(
      scanMode: ScanMode.balanced,
      // withDevices: [TransportBLE.PROV_BLE_SERVICE],
      // withServices: [TransportBLE.PROV_BLE_SERVICE],
      allowDuplicates: true,
      timeout: const Duration(seconds: 4)
    );
    return _ble.scanResults;
    // return _bleManager.startPeripheralScan(
    //     uuids: [TransportBLE.PROV_BLE_SERVICE],
    //     scanMode: ScanMode.balanced,
    //     allowDuplicates: true);
  }

  Future<void> stopScanBle() {
    return _ble.stopScan();
  }

  Future<EspProv> startProvisioning({BluetoothDevice? bluetoothDevice, String pop = 'abcd1234'}) async {
    if (!_isPowerOn) {
      await _waitForBluetoothPoweredOn();
    }
    BluetoothDevice p = bluetoothDevice ?? selectedBluetoothDevice!;
    log.v('peripheral $p');
    await stopScanBle();
    EspProv prov = EspProv(
        transport: TransportBLE(p), security: Security1(pop: pop));
    await prov.establishSession();
    // var success = await prov.establishSession();
    // if (!success) {
    //   throw Exception('Error establishSession');
    // }
    return prov;
  }

  Future<BluetoothState> _waitForBluetoothPoweredOn() async {
    Completer completer = Completer<BluetoothState>();
    
    _ble.state.listen((BluetoothState bluetoothState) { 
      if ((bluetoothState == BluetoothState.on ||
              bluetoothState == BluetoothState.unauthorized) &&
          !completer.isCompleted) {
        completer.complete(bluetoothState);
      }
    });

    return completer.future.timeout(const Duration(seconds: 5),
        onTimeout: () => throw Exception('Wait for Bluetooth PowerOn timeout')) as Future<BluetoothState>;
  }

  Future<bool> requestBlePermissions() async {
    var isLocationGranted = await Permission.locationWhenInUse.request();
    log.v('checkBlePermissions, isLocationGranted=$isLocationGranted');
    return isLocationGranted == PermissionStatus.granted;
  }
}
