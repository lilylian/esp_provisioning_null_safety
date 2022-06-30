// esp_provisioning_blue_null_safety_example
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../scan_list.dart';
import '../wifi_screen/wifi_screen.dart';
import 'ble.dart';

class BleScreen extends StatefulWidget {
  const BleScreen({Key? key}) : super(key: key);

  @override
  _BleScreenState createState() => _BleScreenState();
}

class _BleScreenState extends State<BleScreen> {

  void _showBottomSheet(Map<String, dynamic> item, BuildContext _context) {
    BlocProvider.of<BleBloc>(_context).add(BleEventStopScan());
    BlocProvider.of<BleBloc>(_context).add(BleEventSelect(item));

    var bottomSheetController = showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
        ),
        builder: (BuildContext context) {
          return Container(
            padding: const EdgeInsets.only(top: 5.0),
            height: MediaQuery.of(context).size.height - 50,
            child: WiFiScreen(),
          );
        });
    bottomSheetController.whenComplete(() {
      BlocProvider.of<BleBloc>(_context).add(BleEventStart());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text('Scanning BLE devices'),
      ),
      body: BlocProvider(
        create: (BuildContext context) => BleBloc()..add(BleEventStart()),
        child: BlocBuilder<BleBloc, BleState>(
          builder: (BuildContext context, BleState state) {
            if (state is BleStatePermissionDenied) {
              return const Center(
                child: Text('Please grant location access in "Settings"'),
              );
            }
            if (state is BleStateLoaded) {
              return ScanList(state.bleDevices, Icons.bluetooth,
                  onTap: (Map<String, dynamic> item, BuildContext _context) {
                _showBottomSheet(item, _context);
              });
            }

            return Center(
              child: SpinKitRipple(color: Theme.of(context).textSelectionColor),
            );
          },
        ),
      ),
    );
  }
}
