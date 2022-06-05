import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'database.dart' as database;

final _logger = Logger('main');



class LoginActivity extends StatefulWidget {
  const LoginActivity();
  @override
  _LoginActivityState createState() => _LoginActivityState();
}

class _LoginActivityState extends State<LoginActivity> with WidgetsBindingObserver {

  String pwd='';

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
          title: const Text('Enter your Password'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[

              TextField(
                onChanged: (text) {
                 pwd=text;
                },
              ),
              ElevatedButton(
                child: const Text('Back'),
                onPressed: () async {
                  Navigator.pop(context);
                },
              ),
              ElevatedButton(
                child: const Text('Open Vault'),
                onPressed: () async {
                  await database.init(pwd);
                  if(database.knownKeys.isNotEmpty)
                  {
                    Navigator.pop(context);
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
