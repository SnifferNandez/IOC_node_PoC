// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// https://medium.com/@hernandez.hs/publicaci%C3%B3n-de-una-app-flutter-en-google-play-store-57b07092092c

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';
import 'dart:convert' as JSON;
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

//Declared Globaly
String _configName = "iocoind.conf";
String _daemonName = "iocoind";

void main() {
  runApp(IONode());
}

class IONode extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IOCoin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'IOCoin full staking node'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  MyHomePage({Key key, this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _daemonFolder = "ioc";
  String _daemonPID = "---";
  bool _fileDaemonFound = false;
  String _downloadStatus = "Verifying...";
  String _appPath; // appDocumentsDirectoryPath + / + _daemonFolder

  Future<ProcessResult> _daemonContent;
  Future<ProcessResult> _nodeStart;
  Future<ProcessResult> _nodeStop;
  String _cmdContentShell;
  String _daemonPath;
  String _releasePath =
      "https://github.com/IOCoinNetwork/ioc-CrossCompiler/releases/download/";
  String _archDevice = "unknow";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: RaisedButton(
                    child: const Text('Download the daemon'),
                    //onPressed: _downloadDaemon,
                    onPressed: () async {
                      _downloadDaemon();
                      final ConfirmAction action =
                          await _asyncConfirmDialog(context);
                      if (action == ConfirmAction.OK) {
                        //_downloadBootstrap();
                        //print("Downloading bootstrap");
                      }
                    },
                  ),
                ),
              ],
            ),
            Expanded(
              child: _wdownloadDaemon(),
            ),
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: RaisedButton(
                    child: const Text('Start the node'),
                    onPressed: _requestNodeStart,
                  ),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<ProcessResult>(
                  future: _nodeStart, builder: _startDaemon),
            ),
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: RaisedButton(
                    child: const Text('Stop the node'),
                    onPressed: _requestNodeStop,
                  ),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<ProcessResult>(
                  future: _nodeStop, builder: _stopDaemon),
            ),
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: RaisedButton(
                    child: const Text('Use the API'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SecondRoute()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _checkDaemon();
  }

  void _checkDaemon() async {
    _setArchDevice();
    List _appPathFiles = new List();
    bool _fileConfigFound = false;
    _appPath =
        (await getApplicationDocumentsDirectory()).path + "/" + _daemonFolder;
    try {
      Directory.current = _appPath;
    } catch (e) {
      await _createConf();
    }
    _appPathFiles = Directory("$_appPath/").listSync();
    _appPathFiles.forEach((fileOrDir) {
      if (fileOrDir.path == '$_appPath/$_daemonName')
        setState(() {
          _fileDaemonFound = true;
        });
      if (fileOrDir.path == '$_appPath/$_configName') _fileConfigFound = true;
    });
    if (_fileConfigFound == false) {
      await _createConf();
    }
    if (_fileDaemonFound == false) {
      setState(() {
        _downloadStatus = "Need to download the $_archDevice";
      });
      print('Ready to download deamon:$_archDevice');
    } else {
      ProcessResult result = await Process.run('pidof', [_daemonName]);
      setState(() {
        _downloadStatus = "$_daemonName installed";
        _daemonPID = result.stdout.toString();
      });
    }
    //_requestCmd('rm', ['i686-linux-android_aurora.tar.gz']);
    //_requestCmd('kill', ['4515']);
    //_requestCmd('ps', []);
    _requestCmd('ls', ['-la']);
    _requestCmd('file', ['iocoind']);
    //_requestCmd('cat', ['iocoind.conf']);
  }

  Future<void> _createConf() async {
    print('Creating the config');
    String configdata = 'rpcuser=iocrpcusername\n';
    configdata += 'rpcpassword=';
    configdata += _randomString(32);
    configdata += '\n';
    configdata += 'staking=1\n';
    configdata += 'addnode=amer.supernode.iocoin.io\n';
    configdata += 'addnode=emea.supernode.iocoin.io\n';
    configdata += 'addnode=apac.supernode.iocoin.io\n';
    await new File('$_appPath/$_configName')
        .create(recursive: true)
        .then((File file) {
      file.writeAsString(configdata);
    });
    Directory.current = _appPath;
  }

  String _randomString(int length) {
    var rand = new Random();
    var codeUnits = new List.generate(length, (index) {
      return rand.nextInt(33) + 89;
    });

    return new String.fromCharCodes(codeUnits);
  }

/*
  void _deleteConf() {
    print('Deleting the config');
    _requestCmd('rm', [_configName]);
  }
*/
  void _downloadDaemon() async {
    //TODO: Search the latest release from git repo
    String tagRelease = "1904";
    var dio = new Dio();
    print("$_releasePath/$tagRelease/release.json");
    Response response = await dio.get("$_releasePath/$tagRelease/release.json");
    final releaseJson = JSON.jsonDecode(response.data.toString());
    assert(releaseJson is Map);
    String _archRelease = _archDevice + "_$tagRelease.tar.gz";
    String _daemonSHAsum = releaseJson[_archRelease];
    if (_daemonSHAsum == null) {
      setState(() {
        _downloadStatus = "$_archDevice is not supported yet";
        _fileDaemonFound = true;
      });
    } else {
      try {
        String _daemonDownloadPath = "$_releasePath/$tagRelease/$_archRelease";
        _daemonPath = "$_appPath/$_archRelease";
        print("Downloading $_daemonDownloadPath");
        response = await dio.download(_daemonDownloadPath, _daemonPath,
            onReceiveProgress: (int received, int total) {
          setState(() {
            _fileDaemonFound = true;
            _downloadStatus = "$_daemonName " +
                (100 * (received / total)).toInt().toString() +
                "% downloaded";
          });
        });

        List<int> bytes = new File(_daemonPath).readAsBytesSync();
        var digest = sha256.convert(bytes);
        print("$_daemonSHAsum expected and get ${digest.toString()}");
        if (_daemonSHAsum == digest.toString()) {
          List<int> daemonGz = new GZipDecoder().decodeBytes(bytes);
          Archive archive = new TarDecoder().decodeBytes(daemonGz);
          for (ArchiveFile file in archive) {
            String filename = file.name;
            if (file.isFile) {
              List<int> data = file.content;
              new File(filename)
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            } else {
              new Directory(filename)..create(recursive: true);
            }
          }
          _requestCmd('chmod', ['777', _daemonName]);
        } else {
          setState(() {
            _downloadStatus = "$_daemonName corrupted, try again";
          });
        }
        _requestCmd('rm', ['-f', _daemonPath]);
      } catch (e) {
        print("Fatal error $e");
      }
    }
  }

  void _downloadBootstrap() async {
    String _bootstDownloadPath = "http://172.23.0.247/bootst.tar.gz";
    var dio = new Dio();

    await dio.download(_bootstDownloadPath, "$_appPath/bootst.tar.gz",
        onReceiveProgress: (int received, int total) {
      setState(() {
        _fileDaemonFound = true;
        _downloadStatus = "Bootstrap file " +
            (100 * (received / total)).toInt().toString() +
            "% downloaded";
      });
    });

// TODO: Read the file as stream and decompress
    // https://stackoverflow.com/questions/20815913/how-to-stream-a-file-line-by-line-in-dart

/*
        Stream<List<int>> inputStream = new File("$_appPath/bootst.zip").openRead();
        InputStream filestream;
        inputStream.listen((List<int> bytes){
          filestream = InputStream(bytes);
          Archive bootstArchive = new ZipDecoder().decodeBuffer(filestream);
        });
*/
    //InputStream bootstFile = InputStream(File("$_appPath/bootst.zip").openRead());
    //Stream<List<int>> bootstFile = new File("$_appPath/bootst.zip").openRead();
    //InputStream _rawContent = new InputStream(File("$_appPath/bootst.zip").readAsBytesSync());
    //Archive bootstArchive = new ZipDecoder().decodeBuffer(_rawContent);


    /*
    List<int> bytes = new File("$_appPath/bootst.tar.gz").readAsBytesSync();
    List<int> daemon_gz = new GZipDecoder().decodeBytes(bytes);
    Archive archive = new TarDecoder().decodeBytes(daemon_gz);
    // Extract the contents of the Zip archive to disk.
    for (ArchiveFile file in archive) {
      String filename = file.name;
      if (file.isFile) {
        List<int> data = file.content;
        new File(filename)
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        new Directory(filename)..create(recursive: true);
      }
    }
    */
/*
    // TODO: Change the status for "checking integrity"
        List<int> bytes = new File("$_appPath/bootst.zip").readAsBytesSync();
        var digest = sha256.convert(bytes);
        if ("b036e909b4c60c37d501e6dd4641a85eab3cdfe1534a814f728af82b5081eefc" == digest.toString()) {
          Archive archive = new ZipDecoder().decodeBytes(bytes);
          for (ArchiveFile file in archive) {
            String filename = file.name;
            if (file.isFile) {
              List<int> data = file.content;
              new File(filename)
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            } else {
              new Directory(filename)..create(recursive: true);
            }
          }
        } else {
          setState(() {
            _downloadStatus = "Bootst corrupted, try again";
          });
        }
        */
  }

  Widget _readCmd(BuildContext context, AsyncSnapshot<ProcessResult> snapshot) {
    Text text = const Text('');
    if (snapshot.connectionState == ConnectionState.done) {
      if (snapshot.hasError) {
        text = Text('Error: ${snapshot.error}');
      } else if (snapshot.hasData) {
        if (snapshot.data.exitCode == 0)
          _cmdContentShell = snapshot.data.stdout;
        else
          _cmdContentShell =
              'Exit:${snapshot.data.exitCode.toString()} ==> ${snapshot.data.stderr}';
        text = Text(_cmdContentShell);
      } else {
        text = const Text('CMD unavailable');
      }
    }
    return Padding(padding: const EdgeInsets.all(16.0), child: text);
  }

  void _requestCmd(String command, List<String> param) async {
    print('RequestCMD:$command $param');
    ProcessResult result = await Process.run(command, param);
    print('Exit:${result.exitCode.toString()} ==> ${result.stderr}');
    print(result.stdout);
  }

  void _requestNodeStart() {
    setState(() {
      _nodeStart = run(
          _daemonName, ['--datadir=./', '--conf=./$_configName', '--daemon'],
          verbose: true);
    });
  }

  void _requestNodeStop() async{
    //_updatePID();
    //if (_daemonPID != "---")
    setState(() {
      //_daemonPID = "--";
      //_nodeStop = run(
      //    _daemonName, ['stop'],
      //    verbose: true);

      _daemonContent = Process.run(
          _daemonName, ['--datadir=./', '--conf=./$_configName', 'stop']);
      /*
      _nodeStop = run(
          'pidof', [_daemonName],
          verbose: true);*/
    });
  }
  void _setArchDevice() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      print('Supported Abis ${androidInfo.supportedAbis}'); // e.g. "[x86]"
      switch (androidInfo.supportedAbis[0]) {
        case "armeabi-v7a":
          _archDevice = "arm-linux-androideabi";
          break;
        case "arm64-v8a":
          _archDevice = "aarch64-linux-android";
          break;
        case "x86":
          _archDevice = "i686-linux-android";
          break;
        case "x86_64":
          _archDevice = "x86_64-linux-android";
          break;
        default:
          _archDevice = androidInfo.supportedAbis[0];
      }
    } else if (Platform.isIOS) {
      // TODO: test _setArchDevice on iOS
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      print('Running on ${iosInfo.utsname.machine}'); // e.g. "iPod7,1"
      print('Running on ${iosInfo.utsname.version}');
      /*
      ARMv6 – iPhone & iPhone 3G
      ARMv7 – iPhone 3GS, iPhone 4 & iPhone4S
      ARMv7s – iPhone 5 & iPhone 5C
      ARM64 – iPhone 5S & iPhone 6

      'name': data.name,
      'systemName': data.systemName,
      'systemVersion': data.systemVersion,
      'model': data.model,
      'localizedModel': data.localizedModel,
      'identifierForVendor': data.identifierForVendor,
      'isPhysicalDevice': data.isPhysicalDevice,
      'utsname.sysname:': data.utsname.sysname,
      'utsname.nodename:': data.utsname.nodename,
      'utsname.release:': data.utsname.release,
      'utsname.version:': data.utsname.version,
      'utsname.machine:': data.utsname.machine,

https://github.com/flutter/flutter/issues/17735

      */

      //final String cpuArchitecture = await iMobileDevice.getInfoForDevice(id, 'CPUArchitecture');
      //iMobileDevice declared on
      //https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/ios/mac.dart
      //import 'package:flutter_tools/src/ios/mac.dart';
      switch (iosInfo.utsname.sysname) {
        case 'armv7':
          _archDevice = "armv7-linux-ios";
          break;
        case 'arm64':
          _archDevice = "arm64-linux-ios";
          break;
        default:
          _archDevice = iosInfo.utsname.sysname;
      }
    } else {
      print('No one before');
    }
  }

  Widget _startDaemon(
      BuildContext context, AsyncSnapshot<ProcessResult> snapshot) {
    Text text = const Text('');
    if (snapshot.connectionState == ConnectionState.done) {
      if (snapshot.hasError) {
        //text = Text('Error: ${snapshot.error}');
        text = Text('Already running on process $_daemonPID');
      } else if (snapshot.hasData) {
        //expect(result.pid, isNotNull);
        _daemonPID = snapshot.data.pid.toString();
        text = Text('Running on process $_daemonPID, ${snapshot.data.stdout};');
      } else {
        text = const Text('CMD unavailable');
      }
    }
    return Padding(padding: const EdgeInsets.all(16.0), child: text);
  }

  Widget _stopDaemon(
      BuildContext context, AsyncSnapshot<ProcessResult> snapshot) {
    Text text = const Text('');
    if (snapshot.connectionState == ConnectionState.done) {
      if (snapshot.hasError) {
        //text = Text('Error: ${snapshot.error}');
        text = Text('Error killing process $_daemonPID');
      } else if (snapshot.hasData) {
        //setState(() {
         // _daemonPID = (snapshot.data.stdout.toString() == "")?"---":snapshot.data.stdout.toString();
        //});
        text = Text('Stoping server $_daemonPID ${snapshot.data.stdout}');
      } else {
        text = const Text('CMD unavailable');
      }
    }
    return Padding(padding: const EdgeInsets.all(16.0), child: text);
  }

  Widget _wdownloadDaemon() {
    Text text = const Text('');
    //if (_fileDaemonFound == false) {
    //  text = Text('Need to download the $_archDevice');
    //} else {
      text = Text('$_downloadStatus');
    //}
    return Padding(padding: const EdgeInsets.all(16.0), child: text);
  }
}

class SecondRoute extends StatefulWidget {
  final String title;
  SecondRoute({Key key, this.title}) : super(key: key);

  @override
  _SecondRoute createState() => _SecondRoute();
}

class _SecondRoute extends State<SecondRoute> {
  String _apiAnswer = "";
  Future<ProcessResult> _daemonContent;
  final apiCall = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the Widget is disposed
    apiCall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("IOCoin API calls"),
      ),
      body: Center(
          child: Column(
        children: <Widget>[
          Expanded(
              child: new ListView(
            shrinkWrap: true,
            children: <Widget>[
              //Text(_apiAnswer, style: new TextStyle(fontSize: 30.0),),
              FutureBuilder<ProcessResult>(
                  future: _daemonContent, builder: _readCmd),
              //Your content
            ],
          )),
          Padding(
            // TODO: down position
            //https://stackoverflow.com/questions/45746636/flutter-trying-to-bottom-center-an-item-in-a-column-but-it-keeps-left-aligning?rq=1
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: FractionalOffset.bottomCenter,
              child: TextField(
                controller: apiCall,
                decoration: new InputDecoration.collapsed(
                    hintText: 'Write here the API call'),
                //hintText: 'Please enter an API call',
              ),
            ),
          ),
        ],
      )),
      floatingActionButton: FloatingActionButton(
        // When the user presses the button, show an alert dialog with the
        // text the user has typed into our text field.
        onPressed: () {
          _makeApiCall(apiCall.text);
        },
        tooltip: 'Call the API!',
        child: Icon(Icons.send),
      ),
    );
  }

  void _makeApiCall(String rpccall) {
    setState(() {
      _daemonContent = Process.run(
          _daemonName, ['--datadir=./', '--conf=./$_configName', rpccall]);
    });
  }

  Widget _readCmd(BuildContext context, AsyncSnapshot<ProcessResult> snapshot) {
    Text text = const Text('');
    if (snapshot.connectionState == ConnectionState.done) {
      if (snapshot.hasError) {
        text = Text('Error: ${snapshot.error}');
      } else if (snapshot.hasData) {
        if (snapshot.data.exitCode == 0)
          _apiAnswer = snapshot.data.stdout;
        else
          _apiAnswer =
              'Exit:${snapshot.data.exitCode.toString()} ==> ${snapshot.data.stderr}';
        text = Text(_apiAnswer);
      } else {
        text = const Text('CMD unavailable');
      }
    }
    return Padding(padding: const EdgeInsets.all(16.0), child: text);
  }
}

enum ConfirmAction { OK }

Future<ConfirmAction> _asyncConfirmDialog(BuildContext context) async {
  return showDialog<ConfirmAction>(
    context: context,
    barrierDismissible: false, // user must tap button for close dialog!
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Bootstrap unavailable'),
        content: const Text(
            "For now you can't download the bootstrap file, it will possible in a next release."),
        actions: <Widget>[
          FlatButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(ConfirmAction.OK);
            },
          ),
        ],
      );
    },
  );
}
