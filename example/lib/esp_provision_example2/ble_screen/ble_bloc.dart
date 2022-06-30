import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:rxdart/rxdart.dart';
import '../ble_service.dart';
import 'ble.dart';

class BleBloc extends Bloc<BleEvent, BleState> {
  var bleService = BleService.getInstance();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<Map<String, dynamic>> bleDevices = [];

  BleBloc() : super(BleStateLoading()) {
    on<BleEventStart>(_mapStartToState);
    on<BleEventDeviceUpdated>((event, emit) => emit(BleStateLoaded(List.from(event.bleDevices))));
    on<BleEventSelect>((event, emit) {
      bleService.select(event.selectedDevice['peripheral']);
    });
    on<BleEventStopScan>((event, emit) async {
      await bleService.stopScanBle();
    });
  }

  Future<void> _mapStartToState(BleEventStart event, Emitter<BleState> emit) async {
    var permissionIsGranted = await bleService.requestBlePermissions();
    if (!permissionIsGranted) {
      add(BleEventPermissionDenied());
      return;
    }
    var bleState = await bleService.start();
    if (bleState == BluetoothState.unauthorized) {
      add(BleEventPermissionDenied());
      return;
    }
    _scanSubscription?.cancel();
    _scanSubscription = bleService
        .scanBle()
        .debounce((_) => TimerStream(true, const Duration(milliseconds: 100)))
        .listen((List<ScanResult> scanResults) {
          for (var scanResult in scanResults) {
            var bleDevice = BleDevice(scanResult);
            var idx = bleDevices.indexWhere((e) => e['id'] == bleDevice.id);

            if (idx < 0) {
              bleDevices.add(bleDevice.toMap());
            } else {
              bleDevices[idx] = bleDevice.toMap();
            }
            add(BleEventDeviceUpdated(bleDevices));
          }
    });
  }

  @override
  Future<void> close() {
    _scanSubscription?.cancel();
    bleService.stopScanBle();
    return super.close();
  }
}
