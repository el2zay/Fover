import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:freebox/freebox.dart';
import 'package:fover/main.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';

final box = GetStorage();

Future signUp(context) async {
  var register = await FreeboxClient.registerFreebox(
    appId: 'fbx.fover',
    appName: 'Fover',
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
Future<int> fetchPhotosDir() async {
  var directories = await client?.fetch(url: "v15/fs/ls/L0ZyZWVib3gvVGVzdA==");
  List<dynamic> entries = directories?['result']?['entries'] ?? [];

  var filesOnly = entries.where((e) => e['name'] != '.' && e['name'] != '..' && (e['mimetype'].contains('image/') || e['mimetype'].contains('video/')));
  log(filesOnly.toString());
  fetchImageBytes();
  return filesOnly.length;
}

Future<Uint8List?> fetchImageBytes() async {
  var response = await client?.fetch(url: "v15/dl/L0ZyZWVib3gvVGVzdC9pc3RvY2twaG90by0xMDY5NTM5MjEwLTYxMng2MTIuanBn", parseJson: false);

  if (response is List<dynamic>) {
    return Uint8List.fromList(response.cast<int>());
  }

  return null;
}

// Future fetchThumbnails() async {
//   CachedNetworkImage(
//     imageUrl: await client?.fetch(url: "v15/dl/L0ZyZWVib3gvVGVzdC9pc3RvY2twaG90by0xMDY5NTM5MjEwLTYxMng2MTIuanBn", parseJson: false),
//     placeholder: (context, url) => CircularProgressIndicator(color: Colors.red,),
//     errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
//   // Optionnel : redimensionne en mémoire pour économiser la RAM
//   // memCacheWidth: 200, 
//   );
// }

Future<Image> fetchThumbnails() async {
  var response = await client?.fetch(url: "v15/dl/L0ZyZWVib3gvVGVzdC9pc3RvY2twaG90by0xMDY5NTM5MjEwLTYxMng2MTIuanBn", parseJson: false);
  if (response is List<dynamic>) {
    Uint8List bytes = Uint8List.fromList(response.cast<int>());
    return Image.memory(bytes);
  }
  throw Exception('Failed to load image');

}