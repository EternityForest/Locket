import 'dart:async';

import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'card.dart' as card;
import 'settings.dart' as settings;
import 'database.dart' as database;
import 'login.dart' as login;
import 'vault.dart' as vault;

final _logger = Logger('main');

void main() {
  Logger.root.level = Level.ALL;
  PrintAppender().attachToLogger(Logger.root);
  _logger.info('Initialized logger.');
  runApp(MyApp());
}

void autofillEntryPoint() {
  card.autofillEntryPoint();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MyHome());
  }
}

class MyHome extends StatefulWidget {
  const MyHome();

  @override
  _MyHomeState createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateStatus();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _updateStatus() async {
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      await _updateStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.info(
        'Building AppState. defaultRouteName:${WidgetsBinding.instance.window.defaultRouteName}');

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ElevatedButton(
                  child: const Text('Log in'),
                  onPressed: (){
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const login.LoginActivity()),
                    ).then((value) {
                      _updateStatus();
                    });
                  }),
              ElevatedButton(
                  child: const Text('Launch settings'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const settings.SettingsActivity()),
                    ).then((value) => _updateStatus());
                  }),
              Visibility(
                  visible: database.knownKeys.containsKey('current'),
                  child: ElevatedButton(
                      child: const Text('Launch Vault'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const vault.Vault()),
                        );
                      })),
              ElevatedButton(
                  child: const Text('Lock Vault'),
                  onPressed: () async{
                    database.knownKeys.clear();
                    await _updateStatus();
                  })
            ],
          ),
        ),
      ),
    );
  }
}
