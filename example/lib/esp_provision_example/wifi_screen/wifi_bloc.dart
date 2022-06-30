import 'dart:async';
import 'package:bloc/bloc.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:esp_provisioning/esp_provisioning.dart';
import 'package:logger/logger.dart';
import '../ble_service.dart';
import './wifi.dart';

class WifiBloc extends Bloc<WifiEvent, WifiState> {
  var bleService = BleService.getInstance();
  EspProv? prov;
  Logger log = Logger(printer: PrettyPrinter());

  WifiBloc() : super(WifiStateLoading()) {
    on<WifiEventLoad>(_mapLoadToState);
    on<WifiEventStartProvisioning>(_mapProvisioningToState);
  }

  FutureOr<void> _mapLoadToState(WifiEventLoad event, Emitter<WifiState> emit) async {
    emit(WifiStateConnecting());
    try {
      prov = await bleService.startProvisioning();
    } catch (e) {
      log.e('Error conencting to device $e');
      emit(const WifiStateError('Error conencting to device'));
    }
    emit(WifiStateScanning());

    try {
      var listWifi = await prov?.startScanWiFi();
      List<Map<String, dynamic>> mapListWifi = [];
      listWifi?.forEach((element) {
        mapListWifi.add({
          'ssid': element.ssid,
          'rssi': element.rssi,
          'auth': element.private.toString() != 'Open'
        });
      });

      emit(WifiStateLoaded(wifiList: mapListWifi));
      log.v('Wifi $listWifi');
    } catch (e) {
      log.e('Error scan WiFi network $e');
      emit(const WifiStateError('Error scan WiFi network'));
    }
  }

  Future<void> _mapProvisioningToState(WifiEventStartProvisioning event, Emitter<WifiState> emit) async {
    emit(WifiStateProvisioning());
    await prov?.sendWifiConfig(ssid: event.ssid, password: event.password);
    await prov?.applyWifiConfig();
    await Future.delayed(const Duration(seconds: 1));
    emit(WifiStateProvisioned());
  }

  @override
  Future<void> close() {
    prov?.dispose();
    return super.close();
  }
}
