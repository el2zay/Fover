import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:freebox/freebox.dart';
import 'package:fover/main.dart';
import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';


class FreeboxService {
  static Future signUp(context) async {
    var register = await FreeboxClient.registerFreebox(
      appId: 'fbx.fover',
      appName: 'Fover',
      appVersion: '1.0.0',
      deviceName: Platform.operatingSystem,
      verbose: false
    );

    String sRegister = register.toString();

    if (sRegister.contains("appToken") && sRegister.contains("apiDomain") && sRegister.contains("httpsPort")) {
      box.put("appToken", register["appToken"]);
      box.put("apiDomain", register["apiDomain"]);
      box.put("httpsPort", register["httpsPort"]);

      await initApp();
      Phoenix.rebirth(context);
    }

    return register;
  }

  static Future<String> getFreeboxModel() async {
    var info = await client?.fetch(url: "v15/system");
    String deviceName = info?['result']['model_info']['name'] ?? ""; 

    if (deviceName.contains("fbxgw9")) return "Ultra";
    if (deviceName.contains("fbxgw8")) return "Pop";
    if (deviceName.contains("fbxgw7")) return "Delta";
    if (deviceName.contains("fbxgw6")) return "Révolution";
    if (deviceName.contains("fbxgw")) return "Mini 4K";
    return "Unknown";
  }

  static Future<int> getStorageUsed() async {
    //! TODO
    var result = await client?.fetch(url: "v15/storage/partition");
    // int used =  result['used_bytes'];
    return 10;
  }

  static Future uploadLocalFiles({required List<File> files, List<String>? filenames}) async {
    final uploader = FreeboxUploader(
      apiDomain: client!.apiDomain,
      httpsPort: client!.httpsPort,
      sessionToken: client!.sessionToken!,
    );

    for (int i = 0; i < files.length; i++) {
      await uploader.uploadFile(
        fileBytes: await files[i].readAsBytes(),
        filename: filenames?[i] ?? files[i].path.split('/').last,
        dirname: "L0ZyZWVib3gvVGVzdA==",
        onProgress: (uploaded, total) {
          final percent = (uploaded / total * 100).toStringAsFixed(1);
          log('$percent% — $uploaded / $total bytes');
        },
      );
    }
  }

  // AI Generated
  static Future<String?> uploadEditedBytes({
    required Uint8List bytes,
    required String filename,
    required String folderEncodedPath,
  }) async {
    final uploader = FreeboxUploader(
      apiDomain: client!.apiDomain,
      httpsPort: client!.httpsPort,
      sessionToken: client!.sessionToken!,
    );

    await uploader.uploadFile(
      fileBytes: bytes,
      filename: filename,
      dirname: folderEncodedPath,
      onProgress: (uploaded, total) {
        final percent = (uploaded / total * 100).toStringAsFixed(1);
        log('Uploading edited file: $percent% — $uploaded / $total bytes');
      },
    );

    final folderDecoded = utf8.decode(base64.decode(folderEncodedPath));
    final fullPath = '$folderDecoded/$filename';
    return base64.encode(utf8.encode(fullPath));
  }
  //



  // Permet d'afficher tous les dossiers
  static Future fetchDir() async {
    var directories = await client?.fetch(url: "v15/fs/ls/L0ZyZWVib3g=");

    log(directories.toString());
  }

  static Future<void> deleteLocalFile(String path) async {
    await client?.fetch(
        url: 'v15/fs/rm/',
        method: 'POST',
        body: {'files': [path]},
      );
  }
}