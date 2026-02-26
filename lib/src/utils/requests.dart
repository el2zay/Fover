import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fover/src/utils/video_thumbnail.dart';
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

Future<String> getFreeboxModel() async {
  var info = await client?.fetch(url: "v15/system");
  String deviceName = info['result']?['model_info']?['name'] ?? ""; 

  if (deviceName.contains("fbxgw9")) return "Ultra";
  if (deviceName.contains("fbxgw8")) return "Pop";
  if (deviceName.contains("fbxgw7")) return "Delta";
  if (deviceName.contains("fbxgw6")) return "Révolution";
  if (deviceName.contains("fbxgw")) return "Mini 4K";
  return "Unknown";
}

// Permet d'afficher tous les dossiers
Future fetchDir() async {
  var directories = await client?.fetch(url: "v15/fs/ls/L0ZyZWVib3g=");

  log(directories.toString());
}


Future<List<dynamic>> fetchPhotosDir() async {
  var directories = await client?.fetch(url: "v15/fs/ls/L0ZyZWVib3gvVGVzdA==");
  List<dynamic> entries = directories?['result']?['entries'] ?? [];

  var filesOnly = entries.where((e) =>
      e['name'] != '.' &&
      e['name'] != '..' &&
      e['hidden'] != true &&
      (e['mimetype'].contains('image/') || e['mimetype'].contains('video/')));
  return filesOnly.toList();
}

Future<Uint8List?> fetchImageBytes(String path, String mimetype) async {
  var response = await client?.fetch(
    url: "v15/dl/$path",
    parseJson: false,
  );

  if (response is Uint8List) {
    if (mimetype.startsWith('video/')) {
      return await VideoThumbnailService.getFirstFrame(response);
    }
    return response;
  }

  return null;
}

