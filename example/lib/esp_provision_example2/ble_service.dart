import 'dart:async';
// import 'dart:html';
import 'dart:io';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:esp_provisioning/esp_provisioning.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:location/location.dart' as location;
// import 'package:permission_handler/permission_handler.dart';

class BleService {
  static BleService? _instance;
  static final FlutterBlue _ble = FlutterBlue.instance;
  // static BleManager _bleManager;
  static Logger log = Logger(printer: PrettyPrinter());
  bool _isPowerOn = false;
  StreamSubscription<BluetoothState>? _stateSubscription;
  BluetoothDevice? selectedBluetoothDevice;
  // bool _isPowerOn = false;
  // BluetoothDevice? selectedBluetoothDevice;

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
      for (var result in results) {
        BluetoothDevice bluetoothDevice = result.device;
        log.v("Restored bluetoothDevice: ${bluetoothDevice.name}");
        selectedBluetoothDevice = bluetoothDevice;
      }
    });

    try {
      BluetoothState state = await _waitForBluetoothPoweredOn();
      _isPowerOn = state == BluetoothState.on;
      if(!_isPowerOn){
        _isPowerOn=true;
      } 
      return state;
    } catch (e) {
      log.e('Error ${e.toString()}');
    }
    return BluetoothState.unknown;
  }

  void select(BluetoothDevice bluetoothDevice) async {
    BluetoothDeviceState? deviceState = await selectedBluetoothDevice?.state.first;
    bool _check = deviceState == BluetoothDeviceState.connected || deviceState == BluetoothDeviceState.connecting;
    if(_check == true){
      await selectedBluetoothDevice!.disconnect();
    }
    selectedBluetoothDevice = bluetoothDevice;
    log.v('selectedPeripheral = $selectedBluetoothDevice');
  }

  Future<bool> stop() async {
    if (!_isPowerOn) {
      return true;
    }
    _isPowerOn = false;
    stopScanBle();
    await _stateSubscription?.cancel();
    BluetoothDeviceState? deviceState = (await selectedBluetoothDevice?.state.first);
    bool _check = deviceState == BluetoothDeviceState.connected || deviceState == BluetoothDeviceState.connecting;
    if(_check) {
      selectedBluetoothDevice?.disconnect();
    }
    return true;
  }

  Stream<List<ScanResult>> scanBle() {
    stopScanBle();
    // return _bleManager.startPeripheralScan(
    //     uuids: [TransportBLE.PROV_BLE_SERVICE],
    //     scanMode: ScanMode.balanced,
    //     allowDuplicates: true);
    _ble.startScan(
      scanMode: ScanMode.balanced,
      allowDuplicates: true,
      timeout: const Duration(seconds: 4)
    );

    return _ble.scanResults;
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
    return prov;
  }

  Future<BluetoothState> _waitForBluetoothPoweredOn() async {
    Completer completer = Completer<BluetoothState>();
    _stateSubscription?.cancel();
    _stateSubscription = _ble.state.listen((BluetoothState bluetoothState) { 
      if ((bluetoothState == BluetoothState.on ||
              bluetoothState == BluetoothState.unauthorized) &&
          !completer.isCompleted) {
        completer.complete(bluetoothState);
      }
    });

    return completer.future.timeout(const Duration(seconds: 5),
        onTimeout: () => throw Exception('Wait for Bluetooth PowerOn timeout')) as Future<BluetoothState>;
    // return completer.future.timeout(Duration(seconds: 5),
    //     onTimeout: () {}) as BluetoothState;
    //     // => throw Exception('Wait for Bluetooth PowerOn timeout'));
  }

  Future<bool> requestBlePermissions() async {
    location.Location _location = new location.Location();
    bool _serviceEnabled;

    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        return false;
      }
    }
    var isLocationGranted = await Permission.locationWhenInUse.request();
    log.v('checkBlePermissions, isLocationGranted=$isLocationGranted');
    return isLocationGranted == PermissionStatus.granted;
  }
}
