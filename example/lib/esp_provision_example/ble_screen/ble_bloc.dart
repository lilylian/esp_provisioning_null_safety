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

  // BleBloc(BleState initialState) : super(initialState);

  // BleBloc() : super(BleStateLoading()){
  //   onEvent(event) {
  //     emit(BleEventStart())
  //   }
  // };

  BleBloc() : super(BleStateLoading()) {
    on<BleEventStart>((event, emit) {
      // use `emit` to update the state.
      emit(state);
    });
  }

  @override
  Stream<BleState> mapEventToState(
    BleEvent event,
  ) async* {
    if (event is BleEventStart) {
      yield* _mapStartToState();
    } else if (event is BleEventDeviceUpdated) {
      yield BleStateLoaded(List.from(event.bleDevices));
    } else if (event is BleEventSelect) {
      bleService.select(event.selectedDevice['peripheral']);
    } else if (event is BleEventStopScan) {
      await bleService.stopScanBle();
    }
  }

  Stream<BleState> _mapStartToState() async* {
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
        .debounce((_) => TimerStream(true, Duration(milliseconds: 100)))
        .listen((List<ScanResult> scanResults) {
          scanResults.forEach((ScanResult scanResult) {
            var bleDevice = BleDevice(scanResult);
            if (scanResult.advertisementData.localName != null) {
              var idx = bleDevices.indexWhere((e) => e['id'] == bleDevice.id);

              if (idx < 0) {
                bleDevices.add(bleDevice.toMap());
              } else {
                bleDevices[idx] = bleDevice.toMap();
              }
              add(BleEventDeviceUpdated(bleDevices));
            }
          });
    });
  }

  @override
  Future<void> close() {
    _scanSubscription?.cancel();
    bleService.stopScanBle();
    return super.close();
  }
}
