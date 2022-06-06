import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'card.dart' as card;
import 'database.dart' as database;

final _logger = Logger('main');



class Vault extends StatefulWidget {
  const Vault();

  @override
  _VaultState createState() => _VaultState();
}

class _VaultState extends State<Vault> with WidgetsBindingObserver {

  String searchq = '';
  @override
  void initState() {
    searchq ='';
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

    List<Widget> l = [];

    for (var id in database.cardsInVault.keys)
      {
        Map? i = database.cardsInVault[id];
        if(i==null)
          {
            continue;
          }

        String t = "Untitled";
        if(i.containsKey('\$title') )
          {
            t = i['\$title'];
          }

        else if(i.containsKey('url'))
        {
          t = i['url'];
        }


        String d = '';
        if(i.containsKey('domains'))
          {
            d+=i['domains'].join(';');
          }

        if(i.containsKey('packages'))
        {
          d+="  "+i['packages'].join(';');
        }

        Widget editButton = ElevatedButton(
            child: const Text('View Card'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => card.CardActivity('', i, id)),
              ).then((value){
                _updateStatus();
              });
            });

        Widget c = Card(
          child: Column(
            children: <Widget>[
              ListTile(
                title: Text(t),
                subtitle: Text(d),
              ),
              Row(
                children: [
                  editButton
                ],
              )
            ],
          ),
        );

        l.add(c);
      }

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Vault'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ElevatedButton(
                  child: const Text('Back'),
                  onPressed: () {
                    Navigator.pop(context);
                  }),
              ElevatedButton(
                  child: const Text('Add Card'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                          const card.CardActivity('', {}, '')),
                    ).then((value){
                      _updateStatus();
                    });
                  }),
              TextField(
                onChanged: (text) {
                  searchq=text;
                },
              ),
            ]+l,
          ),
        ),
      ),
    );
  }
}
