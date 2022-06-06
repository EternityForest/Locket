import 'dart:convert';
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:flutter/services.dart';
import 'dart:convert' as conv;

import 'database.dart' as database;

final _logger = Logger('main');


List<String> processdomains(Set<AutofillWebDomain>? d){
  List<String> d2=[];
  if(d==null)
    {
      return d2;
    }

  for (var i in d)
    {
      d2.add( (i.scheme ?? 'https') + "://" + i.domain);
    }

  return d2;
}

//Create the widget to move to
Future<Widget?> autofillEntryPoint() async {
  print("AutofillEntryPoint");

  var _autofillMetadata = await AutofillService().getAutofillMetadata();
  var _saveRequested = _autofillMetadata?.saveInfo != null;
  var _fillRequestedAutomatic = await AutofillService().fillRequestedAutomatic;
  var _fillRequestedInteractive =
      await AutofillService().fillRequestedInteractive;

  var cardData = {};
  var cardID = '';

  // If we are in save mode, we have to find a card to save it in.
  if (_saveRequested) {
    // Show save button.
    if (_autofillMetadata != null) {
      var un = _autofillMetadata.saveInfo?.username;
      var domains = processdomains(_autofillMetadata.webDomains);
      var pkgs = _autofillMetadata.packageNames;

      if (un != null) {
        var m = findMatchingCards(un, pkgs.toList(), domains.toList());
        for (var i in m.keys) {
          var x = m[i];
          if (x != null) {
            cardData.clear();
            cardData.addAll(x);
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
        _autofillMetadata.saveInfo?.username != null) {
      cardData.putIfAbsent(
          '\$title', () => _autofillMetadata.saveInfo?.username ?? '');

      cardData['domains'] =  processdomains(_autofillMetadata.webDomains);

      cardData['packages'] = _autofillMetadata.packageNames.toList();

      cardData['password'] = _autofillMetadata.saveInfo?.password ?? '';
      cardData['username'] = _autofillMetadata.saveInfo?.username ?? '';
    }

    Logger.root.level = Level.ALL;
    PrintAppender().attachToLogger(Logger.root);
    _logger.info('Initialized logger.');
    return CardActivity('save', cardData, cardID);
  } else {
    if (_fillRequestedAutomatic) {
      List<PwDataset> ds = [];
      Map<dynamic, Map> c = findMatchingCards(
          _autofillMetadata?.saveInfo?.username,
          _autofillMetadata?.packageNames.toList() ?? [],
          processdomains(_autofillMetadata?.webDomains));
      for (var i in c.keys) {
        c[i]?.putIfAbsent('password', () => '');
        c[i]?.putIfAbsent('username', () => '');
        c[i]?.putIfAbsent('label', () => c["username"]);

        ds.add(PwDataset(
            label: c['label'].toString(),
            username: c['username'].toString(),
            password: c['password'].toString()));
      }

      await AutofillService().resultWithDatasets(ds);
    } else if (_fillRequestedInteractive) {}
  }

  return null;
}

Map<String, Map> findMatchingCards(
    String? username, List packages, List domains) {
  Map<String, Map> matches = {};
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

      if(domains.isEmpty)
        {
          // Or at least one package match.  But not if there are domains.
          //Because they we would get matches on the browser itself in site lookups
          if (card.containsKey('packages')) {
            for (var d in card['packages']) {
              for (var d2 in packages) {
                if (d2 == d) {
                  match = true;
                }
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

askRegenPassword(BuildContext context, Map obj, _CardActivityState s) {
  // set up the button
  Widget okButton = ElevatedButton(
    child: Text("Medium"),
    onPressed: () {
      obj['password'] = conv.base64Encode(database.urandom(10));
      s.wasChanged = true;
      s._updateStatus();
      Navigator.of(context, rootNavigator: true)
          .pop(); // dismisses only the dialog and returns nothing
    },
  );

  Widget okButton2 = ElevatedButton(
    child: Text("Extreme"),
    onPressed: () {
      obj['password'] = conv.base64Encode(database.urandom(32));
      s.wasChanged = true;
      s._updateStatus();
      Navigator.of(context, rootNavigator: true)
          .pop(); // dismisses only the dialog and returns nothing
    },
  );

  Widget exitButton = ElevatedButton(
    child: Text("Cancel"),
    onPressed: () {
      Navigator.of(context, rootNavigator: true)
          .pop(); // dismisses only the dialog and returns nothing
    },
  );
  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: Text("Random Password"),
    content: Text("Select password strength"),
    actions: [okButton, okButton2, exitButton],
  );
  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

class CardActivity extends StatefulWidget {
  const CardActivity(
      this.launchedByAutofillService, this.cardData, this.cardID);
  final String launchedByAutofillService;
  final Map cardData;
  final String cardID;

  @override
  _CardActivityState createState() => _CardActivityState();
}

class _CardActivityState extends State<CardActivity>
    with WidgetsBindingObserver {
  String autofillMode = '';

  Map cardData = {};
  String cardID = '';

  bool wasChanged = false;

  @override
  void initState() {
    cardData.addAll(widget.cardData);
    cardID = widget.cardID;

    autofillMode = widget.launchedByAutofillService;

    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateStatus();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _updateStatus() async {
    if (autofillMode == 'save') {
      wasChanged = true;
    }

    // No card has been found or opened, so we are on a new card with a new ID.
    if (cardID.length == 0) {
      cardID = base64Encode(database.urandom(16));
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
                    wasChanged = true;
                    await _updateStatus();
                  }),
              TextFormField(
                  decoration: const InputDecoration(
                    icon: Icon(Icons.domain),
                    hintText: 'URLs(; separated)',
                    labelText: 'URLs',
                  ),
                  initialValue: cardData['domains'].join(';'),
                  onChanged: (String text) async {
                    cardData['domains'] = text.split(';');
                    wasChanged = true;
                    await _updateStatus();
                  }),
              TextFormField(
                  decoration: const InputDecoration(
                    icon: Icon(Icons.domain),
                    hintText: 'Apps(; separated)',
                    labelText: 'Apps',
                  ),
                  initialValue: cardData['packages'].join(';'),
                  onChanged: (String text) async {
                    cardData['packages'] = text.split(';');
                    wasChanged = true;
                    await _updateStatus();
                  }),
              TextFormField(
                  decoration: const InputDecoration(
                    icon: Icon(Icons.domain),
                    hintText: 'Username',
                    labelText: 'Username',
                  ),
                  initialValue: cardData['username'],
                  onChanged: (String text) async {
                    cardData['username'] = text;
                    wasChanged = true;
                    await _updateStatus();
                  }),
              TextFormField(
                  decoration: const InputDecoration(
                    icon: Icon(Icons.domain),
                    hintText: 'Password',
                    labelText: 'Password',
                  ),
                  obscureText: true,
                  initialValue: cardData['password'],
                  onChanged: (String text) async {
                    cardData['password'] = text;
                    wasChanged = true;
                    await _updateStatus();
                  }),
              Visibility(
                  visible: wasChanged,
                  child: ElevatedButton(
                      child: const Text('Save'),
                      onPressed: () async {
                        _logger.fine('TODO: save the supplied data now.');
                        await database.saveCard(cardID, cardData);
                        wasChanged = false;
                        _logger.fine('save completed');
                        await _updateStatus();
                      })),
              ElevatedButton(
                child: const Text('Copy Password'),
                onPressed: () async {
                  Clipboard.setData(ClipboardData(text: cardData['password']));
                },
              ),
              ElevatedButton(
                child: const Text('New Password'),
                onPressed: () async {
                  askRegenPassword(context, cardData, this);
                },
              ),
              ElevatedButton(
                child: const Text('Back'),
                onPressed: () async {
                  Navigator.pop(context);
                },
              ),
              Visibility(
                  visible: autofillMode == 'manual',
                  child: ElevatedButton(
                    child: const Text('Autofill with this'),
                    onPressed: () async {
                      _logger.fine('Starting request.');
                      final response =
                          await AutofillService().resultWithDataset(
                        label: cardData['\$title'],
                        username: cardData['username'],
                        password: cardData['password'],
                      );
                      _logger.fine('resultWithDatasets $response');
                      await _updateStatus();
                    },
                  )),
              Visibility(
                visible: autofillMode == 'save',
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
