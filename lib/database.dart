import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:shared_storage/saf.dart' as saf;
import 'package:shared_storage/shared_storage.dart';
import 'package:sqlite3/sqlite3.dart' as db;
import 'dart:convert' as conv;
import 'package:flutter_sodium/flutter_sodium.dart' as sodium;
import 'dart:math';

import 'dart:io' show Platform;

db.Database cache = db.sqlite3.openInMemory();
var dummy = sodium.Sodium.init();

Map knownKeys = {};

Map<String, Map> cardsInVault = {};

Map unrecoveredKeyfiles = {};

Uint8List filenameObfuscationKey = Uint8List(0);

// Given the URI of a keyfile and the password with which to open it,
// Returns a mapping from KeyIDs to decryption keys.

Future<Map> getKeyInfo(String data, String password, bool isOldPassword) async {
  Map<dynamic, dynamic> v = {};

  var keydata = conv.jsonDecode(data);

  var salt = conv.Base64Decoder().convert(keydata['salt']);
  var nonce = conv.Base64Decoder().convert(keydata['nonce']);
  var encdata = conv.Base64Decoder().convert(keydata['encdata']);

  var pwhash = sodium.PasswordHash.hashString(password, salt, outlen: 32);

  var keyid = conv.base64Encode(sodium.GenericHash.hash(pwhash));

  var decdata = sodium.SecretBox.decrypt(encdata, nonce, pwhash);
  var jsondata = conv.jsonDecode(conv.utf8.decode(decdata));

  //If using an old password, do not set current
  if (!isOldPassword) {
    v['current'] = pwhash;
  }

  v[keyid] = pwhash;

  for (var i in jsondata['oldkeys'].keys) {
    v[i] = conv.base64Decode(jsondata['oldkeys'][i]);
  }
  return v;
}

Uint8List urandom(int l) {
  var random = Random.secure();
  return Uint8List.fromList(List<int>.generate(l, (i) => random.nextInt(256)));
}

String changePassword(String password) {
  var newKey = urandom(32);
  var newKeyId = sodium.GenericHash.hash(newKey);

  knownKeys['current'] = newKey;
  knownKeys[conv.base64Encode(newKeyId)] = newKey;

  var kl = {};

  for (var i in knownKeys.keys) {
    kl[i] = conv.base64Encode(knownKeys[i]);
  }

  String encdata = conv.jsonEncode({'oldkeys': kl});
  Uint8List nonce = urandom(24);
  Uint8List salt = urandom(16);

  Uint8List key = sodium.PasswordHash.hashString(password, salt,outlen: 32);

  encdata = conv.base64Encode(sodium.SecretBox.encrypt(
      Uint8List.fromList(conv.utf8.encode(encdata)), nonce, key));

  return conv.jsonEncode({
    'nonce': conv.base64Encode(nonce),
    'salt': conv.base64Encode(salt),
    'keyid': conv.base64Encode(sodium.GenericHash.hash(key)),
    'encdata': encdata
  });
}

Map makeSavableCardFileData(Map data) {
  String idseed = '';

  if (data.containsKey("uri")) {
    idseed += data['uri'] + "\$\$";
  }

  if (data.containsKey("title")) {
    idseed += data['title'] + ";\$\$,";
  }

  if (data.containsKey("username")) {
    idseed += data['username'] + ";\$\$,";
  }

  if (data.containsKey("username")) {
    idseed += data['username'] + ";\$\$,";
  }

  if (data.containsKey("filenameNonce")) {
    idseed += data['filenameNonce'] + ";\$\$,";
  } else {
    var x = conv.base64Encode(urandom(32));
    data['filenameNonce'] = x;
    idseed += data['filenameNonce'];
  }

  String fn = conv.base64Encode(sodium.GenericHash.hash(
          Uint8List.fromList(conv.utf8.encode(idseed)))) +
      ".card.enc";

  String encdata = conv.jsonEncode(data);

  Uint8List nonce = urandom(24);

  return {
    "\$fn": fn,
    "encdata": conv.base64Encode(sodium.SecretBox.encrypt(
        Uint8List.fromList(conv.utf8.encode(encdata)),
        nonce,
        knownKeys['current'])),
    "nonce": conv.base64Encode(nonce),
    "keyid": conv.base64Encode(sodium.GenericHash.hash(knownKeys['current']))
  };
}

// Save a card to the valult
Future<void> saveCard(String id, Map data) async {
  if (Platform.isAndroid) {
    UriPermission? p = await getAndroidFolder();
    if (p == null) {
      //TODO: some kind of error here
    } else {
      // Use a temp file.  This means if anything happens when saving, we do not delete the
      // Old before we get the new.  This could matter in some cases.

      var file = await saf.createFileAsString(p.uri,
          mimeType: "application/octet-stream",
          displayName: id + "temp.card.enc",
          content: conv.jsonEncode(makeSavableCardFileData(data)));

      var old = await saf.findFile(p.uri, id + ".card.enc");
      if (old != null) {
        saf.delete(old.uri);
      }

      file?.renameTo(id + ".card.enc");
    }
  }

  cardsInVault[id]= data;
}

// Load a Card into the decrypted cache
void readCardFile(String filename, String data) {
  var j = conv.jsonDecode(data);
  var nonce = conv.base64Decode(j['nonce']);
  Uint8List encdata = Uint8List(0);

  // Failsafe, TODO: should raise error
  if(j['encdata'].runtimeType == String)
    {
      encdata = conv.base64Decode(j['encdata']);
    }
  else{
    return;
  }

  if (knownKeys.containsKey(j['keyid'])) {
    var cipherkey = knownKeys[j['keyid']];
    var decdata =
        conv.utf8.decode(sodium.SecretBox.decrypt(encdata, nonce, cipherkey));
    var decdatamap = conv.jsonDecode(decdata);
    cardsInVault[filename] = decdatamap;
  }
}

Future<void> init(String password) async {
  if (Platform.isAndroid) {
    await fillCacheFromSAF(password, false);
  }
  return;
}

Future<saf.UriPermission?> getAndroidFolder() async {
  var f = await saf.persistedUriPermissions();
  if (f == null || f.isEmpty) {
    await saf.openDocumentTree(grantWritePermission: true);
  }

  //User may have selected a SAF tree by now
  f = await saf.persistedUriPermissions();
  if (f == null || f.isEmpty) {
    return null;
  }
  return f[0];
}

Future<void> fillCacheFromSAF(String password, bool isOldPassword) async {
  var directory = await getAndroidFolder();

 bool keyfilefound = false;

  if (directory == null) {
    return;
  }

  var files = await saf.listFiles(directory.uri, columns: [
    saf.DocumentFileColumn.id,
    saf.DocumentFileColumn.displayName
  ]).toList();

  // Get any keys we might need
  for (var file in files) {
    Uri? fn = file.metadata?.uri;

    if (fn == null) {
      return;
    }

    var filename = file.data?[saf.DocumentFileColumn.displayName]?.toString();

    if (filename != null) {
      if (filename.endsWith('.key.enc')) {
        keyfilefound=true;
        var data = await saf.getDocumentContentAsString(fn);
        if (data == null) {
        } else {
          try {
            knownKeys.addAll(await getKeyInfo(data, password, isOldPassword));
            if (unrecoveredKeyfiles.containsKey(fn)) {
              unrecoveredKeyfiles.remove(fn);
            }
          } catch (e) {
            unrecoveredKeyfiles[fn] = true;
            throw e;
          }
        }
      }
    }
  }

  // Now we are going to decrypt any vault items we can
  for (var file in files) {
    Uri? fn = file.metadata?.uri;

    if (fn == null) {
      return;
    }

    var filename = file.data?[saf.DocumentFileColumn.displayName]?.toString();

    if (filename != null) {
      if (filename.endsWith('card.enc')) {
        var data = await saf.getDocumentContentAsString(fn);
        if (data != null) {
          try {
            readCardFile(filename, data);
          }
          catch(e)
          {
            throw e;
          }
        }
      }
    }
  }

  if(!keyfilefound){
    if (!knownKeys.containsKey('current')) {
      String kfn = conv.base64Encode(urandom(16)) + ".key.enc";
      String s = changePassword(password);
      await saf.createFileAsString(directory.uri,
          mimeType: "text/json", displayName: kfn, content: s);
    }
  }
}
