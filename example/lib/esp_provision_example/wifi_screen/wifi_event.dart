import 'package:equatable/equatable.dart';

abstract class WifiEvent extends Equatable {
  const WifiEvent();

  @override
  List<Object> get props => [];
}

class WifiEventLoad extends WifiEvent {}

class WifiEventConnecting extends WifiEvent {}

class WifiEventScanning extends WifiEvent {}

class WifiEventScanned extends WifiEvent {}

class WifiEventLoaded extends WifiEvent {
  final String wifiName;

  const WifiEventLoaded({required this.wifiName});

  @override
  List<Object> get props => [wifiName];
}

class WifiEventStartProvisioning extends WifiEvent {
  final String ssid;
  final String password;

  const WifiEventStartProvisioning({required this.ssid, required this.password});

  @override
  List<Object> get props => [ssid, password];
}
