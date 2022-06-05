import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';

final _logger = Logger('main');

class SettingsActivity extends StatefulWidget {
  const SettingsActivity();

  @override
  _SettingsActivityState createState() => _SettingsActivityState();
}

class _SettingsActivityState extends State<SettingsActivity>
    with WidgetsBindingObserver {
  bool? _hasEnabledAutofillServices;
  AutofillMetadata? _autofillMetadata;
  bool? _fillRequestedAutomatic;
  bool? _fillRequestedInteractive;
  bool? _saveRequested;
  AutofillPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateStatus();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _updateStatus() async {
    _hasEnabledAutofillServices =
        await AutofillService().hasEnabledAutofillServices;
    _autofillMetadata = await AutofillService().getAutofillMetadata();
    _saveRequested = _autofillMetadata?.saveInfo != null;
    _fillRequestedAutomatic = await AutofillService().fillRequestedAutomatic;
    _fillRequestedInteractive =
        await AutofillService().fillRequestedInteractive;
    _preferences = await AutofillService().getPreferences();
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
              Text('Offer save enabled: ${_preferences?.enableSaving}\n'),
              ElevatedButton(
                child: const Text('Toggle Save enabled setting'),
                onPressed: () async {
                  await AutofillService().setPreferences(AutofillPreferences(
                    enableDebug: _preferences!.enableDebug,
                    enableSaving: !_preferences!.enableSaving,
                  ));
                  await _updateStatus();
                },
              ),
              ElevatedButton(
                child: const Text('Autofill Settings'),
                onPressed: () async {
                  _logger.fine('Starting request.');
                  final response =
                      await AutofillService().requestSetAutofillService();
                  _logger.fine('request finished $response');
                  await _updateStatus();
                },
              ),
              ElevatedButton(
                  child: const Text('Back'),
                  onPressed: () {
                    Navigator.pop(context);
                  })
            ],
          ),
        ),
      ),
    );
  }
}
