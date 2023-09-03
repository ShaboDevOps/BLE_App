import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController pasword = TextEditingController();
  TextEditingController ssid = TextEditingController();
  List<BluetoothDevice> availableDevices = [];
  List<BluetoothDevice> connectesDevices = [];
  bool bluetoothOn = false;

  void _showDialog(BluetoothDevice device) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Set ESP32 Wi-Fi Credentials',
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ssid,
                decoration: const InputDecoration(labelText: 'SSID'),
              ),
              const SizedBox(
                height: 8,
              ),
              TextField(
                controller: pasword,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(
                height: 16,
              ),
              ElevatedButton(
                onPressed: () {
                  changePassword(device, ssid.text, pasword.text);
                  Navigator.of(context).pop();
                },
                child: Container(
                  alignment: Alignment.center,
                  width: 120,
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF694242)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Container(
                    width: 120,
                    alignment: Alignment.center,
                    child: const Text('Close')),
              ),
            ],
          ),
        );
      },
    );
  }

  deviceCard(BluetoothDevice device, bool isConnected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        tileColor: const Color(0xFF1B1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        titleTextStyle: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        subtitleTextStyle: GoogleFonts.lato(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        title: Text(device.localName),
        subtitle: Text(device.remoteId.str),
        trailing: SizedBox(
          width: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              isConnected
                  ? InkWell(
                      onTap: () {
                        _showDialog(device);
                      },
                      child: Icon(Icons.wifi),
                    )
                  : const SizedBox(),
              const SizedBox(
                width: 10,
              ),
              InkWell(
                onTap: () async {
                  device.connectionState
                      .listen((BluetoothConnectionState state) async {
                    if (state == BluetoothConnectionState.disconnected) {
                      // typically, start a periodic timer that tries to periodically reconnect.
                      // Note: you must always re-discover services after disconnection!
                    }
                  });
                  isConnected
                      ? await device.disconnect()
                      : await device.connect(autoConnect: true);
                },
                child: Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future changePassword(
    BluetoothDevice device,
    String ssid,
    String password,
  ) async {
    String data = "$ssid $password";
    final services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        final isWrite = characteristic.properties.write;
        if (isWrite) {
          await characteristic.write(data.codeUnits);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 80,
          title: Text(
            "ESP32Wizard",
            style:
                GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w500),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                if (Platform.isAndroid) {
                  await FlutterBluePlus.turnOn();
                }
                var state = await FlutterBluePlus.adapterState
                    .map((s) {
                      return s;
                    })
                    .where((s) => s == BluetoothAdapterState.on)
                    .first;
                if (state.name == "on") {
                  setState(() {
                    bluetoothOn = true;
                  });
                } else {
                  setState(() {
                    bluetoothOn = false;
                  });
                }
              },
              icon: Icon(
                bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                color: const Color(0xFFFFFFFF),
                size: 30,
              ),
            )
          ],
          bottom: TabBar(
            onTap: (value) async {
              if (value == 1) {
                availableDevices.clear();
                List<BluetoothDevice> devices =
                    await FlutterBluePlus.connectedSystemDevices;
                setState(() {
                  connectesDevices = devices;
                });
              } else {
                connectesDevices.clear();
                List<BluetoothDevice> devices = [];
                var subscription =
                    FlutterBluePlus.scanResults.listen((newResults) {
                  for (ScanResult result in newResults) {
                    if (result.device.localName.isNotEmpty) {
                      if (!devices.contains(result.device)) {
                        devices.add(result.device);
                      }
                    }
                  }
                  setState(() {
                    availableDevices = devices;
                  });
                });

                subscription.onDone(() {});
                if (!FlutterBluePlus.isScanningNow) {
                  FlutterBluePlus.startScan(
                    timeout: const Duration(seconds: 5),
                  );
                }
              }
            },
            tabs: const [
              Tab(text: 'Not Connected'),
              Tab(text: 'Connected'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            availableDevices.isNotEmpty
                ? Expanded(
                    child: ListView.builder(
                      itemCount: availableDevices.length,
                      itemBuilder: (context, index) =>
                          deviceCard(availableDevices.elementAt(index), false),
                    ),
                  )
                : const Center(child: Text("No Device Detected")),
            connectesDevices.isNotEmpty
                ? Expanded(
                    child: ListView.builder(
                      itemCount: connectesDevices.length,
                      itemBuilder: (context, index) =>
                          deviceCard(connectesDevices.elementAt(index), true),
                    ),
                  )
                : const Center(child: Text("No Connected Device ")),
          ],
        ),
      ),
    );
  }
}
