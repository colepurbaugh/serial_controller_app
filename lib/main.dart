import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';

int redColorValue = 0;     //color 0-256
int greenColorValue = 0;   //color 0-256
int blueColorValue = 0;    //color 0-256
int whiteColorValue = 0;   //color 0-256
int timeValue = 1000;      //time in ms
int menuValue = 0;         //hidden menu for return values: status, temp, etc.

void main() => runApp(ControllerApp());

class ControllerApp extends StatefulWidget {
  @override
  _ControllerAppState createState() => _ControllerAppState();
}

class _ControllerAppState extends State<ControllerApp> {
  UsbPort _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  List<Widget> _serialData = [];
  StreamSubscription<String> _subscription;
  Transaction<String> _transaction;
  int _deviceId;
  TextEditingController _textController = TextEditingController();

  Future<bool> _connectTo(device) async {
    _serialData.clear();

    if (_subscription != null) {
      _subscription.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port.close();
      _port = null;
    }

    if (device == null) {
      _deviceId = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    _port = await device.create();
    if (!await _port.open()) {
      setState(() {
        _status = "Failed to open port";
      });
      return false;
    }

    _deviceId = device.deviceId;
    await _port.setDTR(true);
    await _port.setRTS(true);
    await _port.setPortParameters(
        38400, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port.inputStream, Uint8List.fromList([13, 10]));

    _subscription = _transaction.stream.listen((String line) {
      setState(() {
        _serialData.add(Text(line));
        if (_serialData.length > 20) {
          _serialData.removeAt(0);
        }
      });
    });

    setState(() {
      _status = "Connected";
    });
    return true;
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    print(devices);

    devices.forEach((device) {
      _ports.add(ListTile(
          leading: Icon(Icons.usb),
          title: Text(device.productName),
          subtitle: Text(device.manufacturerName),
          trailing: RaisedButton(
            child:
                Text(_deviceId == device.deviceId ? "Disconnect" : "Connect"),
            onPressed: () {
              _connectTo(_deviceId == device.deviceId ? null : device)
                  .then((res) {
                _getPorts();
              });
            },
          )));
    });

    setState(() {
      print(_ports);
    });
  }

  @override
  void initState() {
    super.initState();

    UsbSerial.usbEventStream.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();
  }

  @override
  void dispose() {
    super.dispose();
    _connectTo(null);
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('USB Serial Plugin example app'),
        ),
        body: Center(
          child: Column(children: <Widget>[
        Text(
            _ports.length > 0
                ? "Available Serial Ports"
                : "No serial devices available",
            style: Theme.of(context).textTheme.title),
        ..._ports,
        // Lock Popper Section *****************************************************************
        Text('Status: $_status\n'),
        Text(" ", style: Theme.of(context).textTheme.title,),
        Text("Lock Popper", style: Theme.of(context).textTheme.title),
        new Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
              child: Text("Open"),
              onPressed: _port == null
                ? null
                : () async {
                    if (_port == null) {
                      return;
                    }
                    String data = "open1\r\n";
                    await _port.write(Uint8List.fromList(data.codeUnits));
                    _textController.text = "";
                  },
            ),
            RaisedButton(
              child: Text("Close"),
              onPressed: _port == null
                ? null
                : () async {
                    if (_port == null) {
                      return;
                    }
                    String data = "close1\r\n";
                    await _port.write(Uint8List.fromList(data.codeUnits));
                    _textController.text = "";
                  },
            ),
        ]),
        // LED Controller Section *****************************************************************
        Text(" ", style: Theme.of(context).textTheme.title),
        Text("LED Controller", style: Theme.of(context).textTheme.title),
        //Red Slider
        Slider(
          value: redColorValue.toDouble(),
          min: 0.0,
          max: 256.0,
          divisions: 256,
          label: 'red',
          onChanged: (double newValue){
            setState(() {
              redColorValue = newValue.toInt();
            });
          },
        ),
        //Green Slider
        Slider(
          value: greenColorValue.toDouble(),
          min: 0.0,
          max: 256.0,
          divisions: 256,
          label: 'green',
          onChanged: (double newValue){
            setState(() {
              greenColorValue = newValue.toInt();
            });
          },
        ),
        //Blue Slider
        Slider(
          value: blueColorValue.toDouble(),
          min: 0.0,
          max: 256.0,
          divisions: 256,
          label: 'blue',
          onChanged: (double newValue){
            setState(() {
              blueColorValue = newValue.toInt();
            });
          },
        ),
        //White Slider
        Slider(
          value: whiteColorValue.toDouble(),
          min: 0.0,
          max: 256.0,
          divisions: 256,
          label: 'white',
          onChanged: (double newValue){
            setState(() {
              whiteColorValue = newValue.toInt();
            });
            _port == null
                ? null
                : () async {
                  if (_port == null) {
                    return;
                  }
                  String data = ledControllerCommand();
                  await _port.write(Uint8List.fromList(data.codeUnits));
                  _textController.text = "";
                };
          },
        ),

        Text("Command Sent: " + ledControllerCommand(),
          style: Theme.of(context).textTheme.title),
        RaisedButton(
            child: Text("Send"),
            onPressed: _port == null
                ? null
                : () async {
                    if (_port == null) {
                      return;
                    }
                    String data = ledControllerCommand();
                    await _port.write(Uint8List.fromList(data.codeUnits));
                    _textController.text = "";
                  },
          ),
        /*
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
              child: Text("Red"),
              onPressed: _port == null
                ? null
                : () async {
                  if (_port == null) {
                    return;
                  }
                  String data = "100.0.0.0.1000";
                  await _port.write(Uint8List.fromList(data.codeUnits));
                  _textController.text = "";
                },
            ),
            RaisedButton(
            child: Text("Green"),
            onPressed: _port == null
                ? null
                : () async {
                    if (_port == null) {
                      return;
                    }
                    String data = "0.100.0.0.1000";
                    await _port.write(Uint8List.fromList(data.codeUnits));
                    _textController.text = "";
                  },
              ),
            RaisedButton(
              child: Text("Blue"),
              onPressed: _port == null
                  ? null
                  : () async {
                      if (_port == null) {
                        return;
                      }
                      String data = "0.0.100.0.1000";
                      await _port.write(Uint8List.fromList(data.codeUnits));
                      _textController.text = "";
                    },
            ),
          ]
        ),
        */
        // Custom Command Section *****************************************************************
        Text(" ", style: Theme.of(context).textTheme.title),
        Text("Custom Commands", style: Theme.of(context).textTheme.title),
        ListTile(
          title: TextField(
            controller: _textController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Custom Command',
            ),
          ),
          trailing: RaisedButton(
            child: Text("Send"),
            onPressed: _port == null
                ? null
                : () async {
                    if (_port == null) {
                      return;
                    }
                    String data = _textController.text + "\r\n";
                    await _port.write(Uint8List.fromList(data.codeUnits));
                    _textController.text = "";
                  },
          ),
        ),

        Text("Result Data", style: Theme.of(context).textTheme.title),
        ..._serialData,
      ])),
    ));
  }

  String ledControllerCommand (){
    String val = redColorValue.toString() + "." +
      greenColorValue.toString() + "." + 
      blueColorValue.toString() + "." + 
      whiteColorValue.toString() + "." + 
      timeValue.toString() + "." + 
      menuValue.toString();

    return val;
  }
}