import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:fover/main.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/freebox_service.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

Future<List<dynamic>> fetchPhotosDir() async {
  List<dynamic> entries = [];
  Uint8List? imageBytes;

  switch (detectBackend()) {
    case ServerBackend.copyparty:
      entries = await CopypartyService.listFiles();
      break;
    case ServerBackend.freebox:
      var directories = await client?.fetch(url: "v15/fs/ls/L0ZyZWVib3gvVGVzdA==");
      entries = directories?['result']?['entries'] ?? [];
      break;
    default:
      break;
  }

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

        if (detectBackend() == ServerBackend.copyparty) {
          imageBytes = await CopypartyService.fetchFileRange(entry['path']);
        } else {
          final imageResponse = await client?.fetch(
            url: "v15/dl/${entry['path']}",
            parseJson: false,
            headers: {'Range': 'bytes=0-65536'},
          );
          if (imageResponse?.data is Uint8List) {
            imageBytes = imageResponse!.data as Uint8List;
          }
        }

        if (entry['mimetype'].contains('image/')) {

          try {
            if (detectBackend() == ServerBackend.copyparty) {
              imageBytes = await CopypartyService.fetchFileRange(entry['path']);
            } else {
              final isHeic = entry['mimetype'] == 'image/heic';
              final range = isHeic ? 'bytes=0-524287' : 'bytes=0-65536';
              final imageResponse = await client?.fetch(
                url: "v15/dl/${entry['path']}",
                parseJson: false,
                headers: {'Range': range},
              );
              if (imageResponse?.data is Uint8List) {
                imageBytes = imageResponse!.data as Uint8List;
              }
            }
          } catch (e) {
            log('⚠️ Fetch failed for ${entry['name']}: $e');
          }

          if (imageBytes != null) {
            try {
              exifData = await readExifFromBytes(imageBytes);
            } catch (e) {
              log('⚠️ EXIF parse failed for ${entry['name']}: $e');
            }
          }
        }
      }

      int parseExifDimension(Map<String, IfdTag> exifData, bool isHeight) {
        final raw = isHeight
            ? exifData['EXIF PixelYDimension']?.printable
              ?? exifData['EXIF ExifImageHeight']?.printable
              ?? exifData['Image ImageLength']?.printable
              ?? exifData['EXIF ExifImageLength']?.printable
            : exifData['EXIF PixelXDimension']?.printable
              ?? exifData['EXIF ExifImageWidth']?.printable
              ?? exifData['Image ImageWidth']?.printable;

        if (raw == null) return 0;
        if (raw.contains('/')) {
          final parts = raw.split('/');
          return (int.parse(parts[0]) / int.parse(parts[1])).round();
        }
        return int.tryParse(raw) ?? 0;
      }

      double? parseExifDouble(String? raw) {
      if (raw == null) return null;
      if (raw.contains('/')) {
        final parts = raw.split('/');
        final denominator = double.parse(parts[1]);
        if (denominator == 0) return null;
        return double.parse(parts[0]) / denominator;
      }
      return double.tryParse(raw);
    }

      exifData.forEach((key, value) {
        log('$key: ${value.printable}');
      });

      // Generated with AI (The code I wrote isn't working right, so I have to ask Claude to fix it 😔)

      bool isScreenshot(Map<String, IfdTag> exifData, int width, int height) {
        final hasCamera = exifData.containsKey('Image Make') ||
          exifData.containsKey('EXIF ExposureTime') ||
          exifData.containsKey('EXIF ISOSpeedRatings') ||
          exifData.containsKey('EXIF FocalLength');

        final software = exifData['Image Software']?.printable ?? '';
        final hasMobileSoftwareTag = software.toLowerCase().contains('ios') ||
          software.toLowerCase().contains('android');

        final knownScreenSizes = [
          // iPhone (portrait)
          (390, 844), (393, 852), (430, 932), (428, 926),
          (375, 812), (414, 896), (390, 844), (320, 568),
          // iPhone (landscape)
          (844, 390), (852, 393), (932, 430),
          // iPhone Retina (points × 2 ou ×3)
          (750, 1334), (1080, 1920), (1170, 2532), (1179, 2556),
          (1290, 2796), (1284, 2778), (1125, 2436), (828, 1792),
          // iPad
          (768, 1024), (1024, 1366), (820, 1180), (834, 1194),
          (1640, 2360), (2048, 2732),
        ];

        final matchesScreenSize = knownScreenSizes.any(
          (s) => s.$1 == width && s.$2 == height,
        );

        // Screenshot = pas de données caméra ET (software mobile OU dimensions d'écran)
        if (hasCamera) return false;
        return hasMobileSoftwareTag || matchesScreenSize;
      }

      // 

      int width = parseExifDimension(exifData, false);
      int height = parseExifDimension(exifData, true);

      if ((width == 0 || height == 0) && imageBytes != null) {
        try {
          final buffer = await ui.ImmutableBuffer.fromUint8List(imageBytes);
          final descriptor = await ui.ImageDescriptor.encoded(buffer);
          width = descriptor.width;
          height = descriptor.height;
          descriptor.dispose();
          buffer.dispose();
        } catch (_) {}
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
        cameraModel: exifData['Image Model']?.printable,
        height: height,
        width: width,
        iso: int.tryParse(exifData['EXIF ISOSpeedRatings']?.printable ?? ""),
        focalLength: parseExifDouble(exifData['EXIF FocalLengthIn35mmFilm']?.printable ?? exifData['EXIF FocalLength']?.printable)?.round(),
        exposureValue: parseExifDouble(exifData['EXIF ExposureBiasValue']?.printable)?.round(),
        focus: parseExifDouble(exifData['EXIF FNumber']?.printable.replaceAll('ƒ/', ''))?.round(),
        isScreenshot: isScreenshot(exifData, parseExifDimension(exifData, false), parseExifDimension(exifData, true))      );
    }
  }
  
  if (hasBeenEdited) {
    uploadHive();
  }
  return filesOnly.toList();
}

Future<void> uploadHive() async {
  final appDir = (await getApplicationDocumentsDirectory()).path;
  final files = [
    File("$appDir/photos.hive"),
    File("$appDir/photos.lock"),
    File("$appDir/albums.hive"),
    File("$appDir/albums.lock")
  ];

  switch (detectBackend()) {
    case ServerBackend.freebox:
      await FreeboxService.uploadLocalFiles(files: files);
      break;

    case ServerBackend.copyparty:
      for (final file in files) {
        final filename = file.path.split('/').last;
        try {
          await CopypartyService.deleteFile(filename);
        } catch (_) {}
        await CopypartyService.uploadLocalFiles(files: [file]);
      }
      break;

    default:
      break;
  }
}

Future<Uint8List?> fetchFullBytes(String encodedPath) async {
  final photo = PhotoStore.get(encodedPath);

  if (photo?.localPath != null && File(photo!.localPath!).existsSync()) {
    return await File(photo.localPath!).readAsBytes();
  }

  if (detectBackend() == ServerBackend.copyparty) {
    final bytes = await CopypartyService.fetchFile(encodedPath);
    return Uint8List.fromList(bytes);
  }

  final response = await client?.fetch(
    url: "v15/dl/$encodedPath",
    parseJson: false,
  );

  return response?.data is Uint8List ? response!.data as Uint8List : null;
}

Future<Uint8List?> fetchImageBytes(String path, String mimetype) async {
  final isVideo = mimetype.startsWith('video/');

    if (detectBackend() == ServerBackend.copyparty) {
      return await CopypartyService.getThumbnail(path);
    }

    if (isVideo) {
      final response = await client?.fetch(
        url: "v15/dl/$path",
        parseJson: false,
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