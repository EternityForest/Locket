import 'dart:convert';

import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_autofill_service_example/main.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';

import 'database.dart' as database;

final _logger = Logger('main');

void autofillEntryPoint() {
  Logger.root.level = Level.ALL;
  PrintAppender().attachToLogger(Logger.root);
  _logger.info('Initialized logger.');
  runApp(MyApp());
}

class AutofillActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CardActivity(true, {}, ''));
  }
}
//
// final response = await AutofillService().resultWithDatasets([
// PwDataset(
// label: 'user and pass 1',
// username: 'dummyUsername1',
// password: 'dpwd1',
// ),
// PwDataset(
// label: 'user and pass 2',
// username: 'dummyUsername2',
// password: 'dpwd2',
// ),
// PwDataset(
// label: 'user only',
// username: 'dummyUsername2',
// password: '',
// ),
// PwDataset(
// label: 'pass only',
// username: '',
// password: 'dpwd2',
// ),
// ]);

Map findMatchingCards(String? username, List packages, List domains) {
  var matches = {};
  //Have to have something to match on
    for (var i in database.cardsInVault.keys) {
      Map card = database.cardsInVault[i] ?? {};
      if (username == null ||
          (card.containsKey('username') && card['username'] == username)) {
        bool match = false;

        //Check for at least one domain match
        if (card.containsKey('domains')) {
          for (var d in card['domains']) {
            for (var d2 in domains) {
              if (d2 == d) {
                match = true;
              }
            }
          }
        }

        // Or at least one package match
        if (card.containsKey('packages')) {
          for (var d in card['packages']) {
            for (var d2 in packages) {
              if (d2 == d) {
                match = true;
              }
            }
          }
        }

        if (match) {
          matches[i] = card;
        }
      }
    }


  return matches;
}

class CardActivity extends StatefulWidget {
  const CardActivity(
      this.launchedByAutofillService, this.cardData, this.cardID);
  final bool launchedByAutofillService;
  final Map cardData;
  final String cardID;

  @override
  _CardActivityState createState() => _CardActivityState();
}

class _CardActivityState extends State<CardActivity>
    with WidgetsBindingObserver {
  AutofillMetadata? _autofillMetadata;
  bool? _fillRequestedAutomatic;
  bool? _fillRequestedInteractive;
  bool? _saveRequested;

  Map cardData = {};
  String cardID = '';
  
  bool wasChanged = false;

  @override
  void initState() {
    cardData.addAll(widget.cardData);
    cardID = widget.cardID;

    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateStatus();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _updateStatus() async {
    _autofillMetadata = await AutofillService().getAutofillMetadata();
    _saveRequested = _autofillMetadata?.saveInfo != null;
    _fillRequestedAutomatic = await AutofillService().fillRequestedAutomatic;
    _fillRequestedInteractive =
        await AutofillService().fillRequestedInteractive;

    // If we are in save mode, we have to find a card to save it in.
    if (_saveRequested ?? false) {
      // Show save button.
      wasChanged=true;
      if (_autofillMetadata != null) {
        var un = _autofillMetadata?.saveInfo?.username;
        var domains = _autofillMetadata?.webDomains;
        var pkgs = _autofillMetadata?.packageNames;

        if (un != null) {
          var m = findMatchingCards(
              un, pkgs?.toList() ?? [], domains?.toList() ?? []);
          for (var i in m.keys) {
            cardData.clear();
            cardData.addAll(m[i]);
            cardID = i;
          }
        }
      }
    }

    // No card has been found or opened, so we are on a new card with a new ID.
    if (cardID.length == 0) {
      cardID = base64Encode(database.urandom(16));
    }

    if (_autofillMetadata != null &&
        (_saveRequested ?? false) &&
        _autofillMetadata?.saveInfo?.username != null) {
      cardData.putIfAbsent(
          '\$title', () => _autofillMetadata?.saveInfo?.username ?? '');

      cardData['domains'] = _autofillMetadata?.webDomains.toList() ?? [];

      cardData['packages'] = _autofillMetadata?.packageNames.toList() ?? [];

      cardData['password'] = _autofillMetadata?.saveInfo?.password ?? '';
      cardData['username'] = _autofillMetadata?.saveInfo?.username ?? '';
    }

    cardData.putIfAbsent('username', () => '');
    cardData.putIfAbsent('password', () => '');
    cardData.putIfAbsent('packages', () => []);
    cardData.putIfAbsent('domains', () => []);

    cardData.putIfAbsent('\$title', () => "Untitled");

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
              TextFormField(
                  maxLength: 1024,
                  decoration: const InputDecoration(
                    icon: Icon(Icons.title),
                    hintText: 'Title',
                    labelText: 'Title',
                  ),
                  initialValue: cardData['\$title'],
                  onChanged: (String text) async {
                    cardData['\$title'] = text;
                    wasChanged=true;
                    await _updateStatus();
                  }),
              TextFormField(
                  decoration: const InputDecoration(
                    icon: Icon(Icons.domain),
                    hintText: 'URLs(; separated)',
                    labelText: 'URLs',
                  ),
                  initialValue: cardData['domains'].join(';'),
                  onChanged: (String text) async{
                    cardData['domains'] = text.split(';');
                    wasChanged=true;
                    await _updateStatus();
                  }),
              TextFormField(
                  decoration: const InputDecoration(
                    icon: Icon(Icons.domain),
                    hintText: 'Apps(; separated)',
                    labelText: 'Apps',
                  ),
                  initialValue: cardData['packages'].join(';'),
                  onChanged: (String text) async{
                    cardData['packages'] = text.split(';');
                    wasChanged=true;
                    await _updateStatus();
                  }),
              TextFormField(
                  decoration: const InputDecoration(
                    icon: Icon(Icons.domain),
                    hintText: 'Username',
                    labelText: 'Username',
                  ),
                  initialValue: cardData['username'],
                  onChanged: (String text) async{
                    cardData['username'] = text;
                    wasChanged=true;
                    await _updateStatus();
                  }),
              TextFormField(
                  decoration: const InputDecoration(
                    icon: Icon(Icons.domain),
                    hintText: 'Password',
                    labelText: 'Password',
                  ),
                  initialValue: cardData['password'],
                  onChanged: (String text) async {
                    cardData['password'] = text;
                    wasChanged=true;
                    await _updateStatus();
                  }),

            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                _logger.fine('TODO: save the supplied data now.');
                await database.saveCard(cardID,cardData);
                wasChanged=false;
                _logger.fine('save completed');
                await _updateStatus();
              }),

              ElevatedButton(
                child: const Text('Back'),
                onPressed: () async {
                  Navigator.pop(context);
                },
              ),
              Visibility(
                  visible: _fillRequestedInteractive ?? false,
                  child: ElevatedButton(
                    child: const Text('Autofill with this'),
                    onPressed: () async {
                      _logger.fine('Starting request.');
                      final response =
                          await AutofillService().resultWithDataset(
                        label: 'this is the label 3',
                        username: 'dummyUsername3',
                        password: 'dpwd3',
                      );
                      _logger.fine('resultWithDatasets $response');
                      await _updateStatus();
                    },
                  )),
              Visibility(
                visible: (_saveRequested ?? false) && (wasChanged==false),
                child: ElevatedButton(
                  child: const Text('Done'),
                  onPressed: () async {
                    _logger.fine('TODO: save the supplied data now.');
                    await AutofillService().onSaveComplete();
                    _logger.fine('save completed');
                    await _updateStatus();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
