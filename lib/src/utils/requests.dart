import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';

import 'package:freebox/freebox.dart';
import 'package:fover/main.dart';
import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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
    box.put("appToken", register["appToken"]);
    box.put("apiDomain", register["apiDomain"]);
    box.put("httpsPort", register["httpsPort"]);

    Phoenix.rebirth(context);
  }

  return register;
}

Future<String> getFreeboxModel() async {
  var info = await client?.fetch(url: "v15/system");
  String deviceName = info?['result']['model_info']['name'] ?? ""; 

  if (deviceName.contains("fbxgw9")) return "Ultra";
  if (deviceName.contains("fbxgw8")) return "Pop";
  if (deviceName.contains("fbxgw7")) return "Delta";
  if (deviceName.contains("fbxgw6")) return "Révolution";
  if (deviceName.contains("fbxgw")) return "Mini 4K";
  return "Unknown";
}

Future<int> getStorageUsed() async {
  //! TODO
  var result = await client?.fetch(url: "v15/storage/partition");
  print(result);
  // int used =  result['used_bytes'];
  return 10;
}

Future uploadLocalFiles(List<File> file) async {
  final uploader = FreeboxUploader(
    apiDomain: client!.apiDomain,
    httpsPort: client!.httpsPort,
    sessionToken: client!.sessionToken!,
  );

  for (int i = 0; i < file.length; i++) {
    await uploader.uploadFile(
      fileBytes: file[i].readAsBytesSync(),
      filename: file[i].path.split('/').last,
      dirname: "L0ZyZWVib3gvVGVzdA==",
      onProgress: (uploaded, total) {
        final percent = (uploaded / total * 100).toStringAsFixed(1);
        log('$percent% — $uploaded / $total bytes');
        // setState(() => _progress = uploaded / total); // pour une ProgressBar
      },
    );
  }
}

// Permet d'afficher tous les dossiers
Future fetchDir() async {
  var directories = await client?.fetch(url: "v15/fs/ls/L0ZyZWVib3g=");

  log(directories.toString());
}


Future<List<dynamic>> fetchPhotosDir() async {
  var directories = await client?.fetch(url: "v15/fs/ls/L0ZyZWVib3gvVGVzdA=="); // TODO changer par le vrai dossier
  List<dynamic> entries = directories?['result']?['entries'] ?? [];
  bool hasBeenEdited = false;
  var filesOnly = entries.where((e) =>
      e['name'] != '.' &&
      e['name'] != '..' &&
      e['hidden'] != true &&
      (e['mimetype'].contains('image/') || e['mimetype'].contains('video/')));

  for (var entry in filesOnly) {
    if (PhotoStore.get(entry['path']) == null) {
      hasBeenEdited = true;
      // await PhotoStore.addPhoto(
      //   path: entry['path'],
      //   name: entry['name'],
      //   date: DateTime.fromMillisecondsSinceEpoch(entry['modification'] * 1000),
      //   size: entry['size'] ?? 0,
      //   mimetype: entry['mimetype']
      // );

      Map<String, IfdTag> exifData = {};
      if (entry['mimetype'].contains('image/')) {
        final imageResponse = await client?.fetch(
          url: "v15/dl/${entry['path']}",
          parseJson: false,
          headers: {'Range': 'bytes=0-65536'}, 
        );

        if (imageResponse?.data is Uint8List) {
          exifData = await readExifFromBytes(imageResponse!.data as Uint8List);
        }
      }

      await PhotoStore.addPhoto(
        path: entry['path'], 
        name: entry['name'], 
        date: parseExifDate(exifData['Image DateTime']?.printable) ?? DateTime.now(), 
        size: entry['size'] ?? 0, 
        mimetype: entry['mimetype'],
        latitude: exifData['GPS GPSLatitude'] != null && exifData['GPS GPSLatitudeRef'] != null
          ? parseGps(exifData['GPS GPSLatitude']!.printable, exifData['GPS GPSLatitudeRef']!.printable)
          : null,
        longitude: exifData['GPS GPSLongitude'] != null && exifData['GPS GPSLongitudeRef'] != null
          ? parseGps(exifData['GPS GPSLongitude']!.printable, exifData['GPS GPSLongitudeRef']!.printable)
          : null,
        cameraBrand: exifData['Image Make']?.printable ?? "Unknown",
        cameraModel: exifData['Image Model']?.printable
      );
    }
  }
  
  if (hasBeenEdited) {
    uploadLocalFiles([
      File("${(await getApplicationDocumentsDirectory()).path}/photos.hive"),
      File("${(await getApplicationDocumentsDirectory()).path}/photos.lock"),
      File("${(await getApplicationDocumentsDirectory()).path}/albums.hive"),
      File("${(await getApplicationDocumentsDirectory()).path}/albums.lock")
    ]);
  }

  return filesOnly.toList();
}

Future<void> deleteLocalFile(String path) async {
  await client?.fetch(
      url: 'v15/fs/rm/',
      method: 'POST',
      body: {'files': [path]},
    );
}


Future<Uint8List?> fetchImageBytes(String path, String mimetype) async {
  final isVideo = mimetype.startsWith('video/');

    if (isVideo) {
      final response = await client?.fetch(
        url: "v15/dl/$path",
        parseJson: false,
        headers: {'Range': 'bytes=0-10000000'},
      );

      if (response?.data is! Uint8List) return null;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/tmp_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await tempFile.writeAsBytes(response!.data as Uint8List);

      final bytes = await VideoThumbnail.thumbnailData(
        video: tempFile.path,
        imageFormat: ImageFormat.WEBP,
        maxWidth: 300,
        quality: 50,
      );

      await tempFile.delete();
      return bytes;
    }



  final response = await client?.fetch(
    url: "v15/dl/$path",
    parseJson: false,
  );

  return response?.data is Uint8List ? response!.data : null;
}


