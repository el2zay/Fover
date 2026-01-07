import 'dart:io';

import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:freebox/freebox.dart';
import 'package:freebox_photos/main.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';


final box = GetStorage();

Future signUp(context) async {
  var register = await FreeboxClient.registerFreebox(
    appId: 'fbx.freebox_photos',
    appName: 'Freebox Photos',
    appVersion: '1.0.0',
    deviceName: Platform.operatingSystem,
    verbose: false
  );

  String sRegister = register.toString();

  if (sRegister.contains("appToken") && sRegister.contains("apiDomain") && sRegister.contains("httpsPort")) {
    box.write("appToken", register["appToken"]);
    box.write("apiDomain", register["apiDomain"]);
    box.write("httpsPort", register["httpsPort"]);

    Phoenix.rebirth(context);
  }

  return register;
}

// Permet d'afficher tous les dossiers
Future fetchDir() async {
  var directories = await client?.fetch(url: "v15/fs/ls/L0ZyZWVib3g=");

  log(directories.toString());
}

// Permet d'afficher le dossier sélectionné
Future fetchPhotosDir() async {
  var directories = await client?.fetch(url: "v15/fs/ls/L0ZyZWVib3gvVGVzdA==");
  List<dynamic> entries = directories?['result']['entries'] ?? [];

  var filesOnly = entries.where((e) => e['name'] != '.' && e['name'] != '..' && (e['mimetype'].contains('image/') || e['mimetype'].contains('video/')));
  
  log(filesOnly.toString());
}