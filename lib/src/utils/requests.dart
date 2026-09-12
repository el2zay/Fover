import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:fover/main.dart';
import 'package:fover/src/models/album_entry.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/freebox_service.dart';
import 'package:fover/src/services/ocr_service.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

bool _syncInProgress = false;

Future<List<dynamic>> fetchPhotosDir() async {
  List<dynamic> entries = [];
  Uint8List? imageBytes;
  int? videoDuration;
  VideoPlayerController? controller;

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


  var filesOnly = entries.where((e) =>
      e['name'] != '.' &&
      e['name'] != '..' &&
      e['hidden'] != true &&
      (e['mimetype'].contains('image/') || e['mimetype'].contains('video/')));

  for (var entry in filesOnly) {
    if (PhotoStore.get(entry['path']) == null) {
      // await PhotoStore.addPhoto(
      //   path: entry['path'],
      //   name: entry['name'],
      //   date: DateTime.fromMillisecondsSinceEpoch(entry['modification'] * 1000),
      //   size: entry['size'] ?? 0,
      //   mimetype: entry['mimetype']
      // );

      Map<String, IfdTag> exifData = {};
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
          log('Fetch failed for ${entry['name']}: $e');
        }

        if (imageBytes != null) {
          try {
            exifData = await readExifFromBytes(imageBytes);
          } catch (e) {
            log('EXIF parse failed for ${entry['name']}: $e');
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

      if ((entry['mimetype'] as String).startsWith('video/')) {
        try {
          if (detectBackend() == ServerBackend.copyparty) {
            controller = VideoPlayerController.networkUrl(
              Uri.parse("${CopypartyService.baseUrl}/photos/${entry['path']}"),
              httpHeaders: {'Authorization': 'Basic ${CopypartyService.credentials}'},
            );
          } else {
            controller = VideoPlayerController.networkUrl(
              Uri.parse("https://${box.get('apiDomain')}:${box.get('httpsPort')}/api/v15/dl/${entry['path']}"),
              httpHeaders: {"X-Fbx-App-Auth": client!.sessionToken!},
            );
          }
          await controller.initialize();
          videoDuration = controller.value.duration.inSeconds;
          await controller.dispose();
        } catch (e) {
          log("$e");
          log("Path : ${entry['path']}");
        }
      }

      await PhotoStore.addPhoto(
        path: entry['path'], 
        name: entry['name'], 
        date: parseExifDate(exifData['Image DateTime']?.printable) ?? DateTime.now(), 
        size: entry['size'] ?? 0, 
        mimetype: entry['mimetype'],
        duration: videoDuration,
        latitude: parseGpsFromTag(
          exifData['GPS GPSLatitude'],
          exifData['GPS GPSLatitudeRef'],
        ),
        longitude: parseGpsFromTag(
          exifData['GPS GPSLongitude'],
          exifData['GPS GPSLongitudeRef'],
        ),
        cameraBrand: exifData['Image Make']?.printable ?? "Unknown",
        cameraModel: exifData['Image Model']?.printable,
        height: height,
        width: width,
        iso: int.tryParse(exifData['EXIF ISOSpeedRatings']?.printable ?? ""),
        focalLength: parseExifDouble(exifData['EXIF FocalLengthIn35mmFilm']?.printable ?? exifData['EXIF FocalLength']?.printable)?.round(),
        exposureValue: parseExifDouble(exifData['EXIF ExposureBiasValue']?.printable)?.round(),
        focus: parseExifDouble(exifData['EXIF FNumber']?.printable.replaceAll('ƒ/', ''))?.round(),
        isScreenshot: isScreenshot(exifData, parseExifDimension(exifData, false), parseExifDimension(exifData, true))
      );
    }

    Future.microtask(() => OcrService.runOcrIfNeeded(
      entry['path'], 
      (entry['mimetype'] as String?) ?? 'image/jpeg',
    ));
  }
  return filesOnly.toList();
}

Future<void> uploadHive() async {
  final appDir = PhotoStore.boxDir;
  final id = PhotoStore.deviceId;

  for (final boxName in ['photos', 'albums']) {
    final file = File('$appDir/$boxName.hive');
    if (!file.existsSync()) continue;

    if (Hive.isBoxOpen(boxName)) {
      if (boxName == 'photos') {
        await Hive.box<PhotoEntry>('photos').compact();
      } else {
        await Hive.box<AlbumEntry>('albums').compact();
      }
    }

    // Nom stable propre à cet appareil
    final remoteName = '$boxName-$id.hive';
    try {
      await CopypartyService.deleteFile(remoteName);
    } catch (_) {
      // 404 au premier upload : normal
    }
    await CopypartyService.uploadLocalFiles(files: [file], filenames: [remoteName]);
    log('[up] ↑ $remoteName');
  }
}

Future<Uint8List?> downloadHive(String filename) async {
  try {
    switch (detectBackend()) {
      case ServerBackend.copyparty:
        final bytes = await CopypartyService.fetchFile(filename);
        return Uint8List.fromList(bytes);
      case ServerBackend.freebox:
        final response = await client?.fetch(
          url: "v15/dl/$filename",
          parseJson: false
        );
        return response?.data is Uint8List ? response!.data as Uint8List : null;

        default:
          return null;
    }
  } catch (e) {
    log("Failed to download $filename: $e");
    return null;
  }
}

Future<void> syncHive() async {
  if (_syncInProgress) return;
  _syncInProgress = true;
  PhotoStore.cancelScheduledUpload();

  try {
    final appDir = PhotoStore.boxDir;
    final mine = PhotoStore.deviceId;
    final serverFiles = await CopypartyService.listAllFiles();

    for (final boxName in ['photos', 'albums']) {
      final remotes = serverFiles.where((f) =>
          f.startsWith('$boxName-') &&
          f.endsWith('.hive') &&
          f != '$boxName-$mine.hive');

      log('[sync] $boxName : ${remotes.length} fichier(s) distant(s)');

      for (final remote in remotes) {
        final bytes = await downloadHive(remote);
        if (bytes == null || bytes.isEmpty) continue;
        log('[sync] ↓ $remote (${bytes.length} o)');
        await mergeHive(File('$appDir/$boxName.hive'), bytes, '$boxName.hive');
      }
    }

    await uploadHive();
  } finally {
    _syncInProgress = false;
  }
}

Future<void> mergeHive(File localFile, Uint8List serverBytes, String filename) async {
  final dir = localFile.parent.path;
  final boxName = filename.replaceAll('.hive', '');
  final tempName = 'temp_$boxName';

  Future<void> cleanup() async {
    if (Hive.isBoxOpen(tempName)) {
      if (boxName == 'photos') {
        await Hive.box<PhotoEntry>(tempName).close();
      } else {
        await Hive.box<AlbumEntry>(tempName).close();
      }
    }
    await Hive.deleteBoxFromDisk(tempName, path: dir);
  }

  await cleanup();
  try {
    await File('$dir/$tempName.hive').writeAsBytes(serverBytes, flush: true);
    log('[merge] $tempName.hive écrit (${serverBytes.length} octets)');

    if (boxName == 'photos') {
      await mergePhotosBox(dir);
    } else {
      await mergeAlbumsBox(dir);
    }
  } finally {
    await cleanup();
  }
}

Future<void> mergePhotosBox(String dir) async {
  final f = File('$dir/temp_photos.hive');
  log('[merge] temp_photos.hive : existe=${f.existsSync()} '
      'taille=${f.existsSync() ? f.lengthSync() : 0}');

  final serverBox = await Hive.openBox<PhotoEntry>('temp_photos', path: dir);
  log('[merge] ${serverBox.length} entrées côté serveur');

  PhotoStore.merging = true;
  var created = 0, updated = 0, skipped = 0;

  try {
    for (final key in serverBox.keys) {
      final serverEntry = serverBox.get(key);
      if (serverEntry == null) continue;

      final local = PhotoStore.get(key as String);

      if (serverEntry.deletedAt != null || serverEntry.revs != null) {
        log('[merge] ${serverEntry.name} | '
            'serveur: del=${serverEntry.deletedAt} rev=${serverEntry.rev("deletedAt")} '
            'fav=${serverEntry.favorite} | '
            'local: ${local == null ? "ABSENTE" : "del=${local.deletedAt} rev=${local.rev("deletedAt")} fav=${local.favorite}"}');
      }

      if (local == null) {
        created++;
      } else {
        updated++;
      }

      await PhotoStore.mergeFrom(key, serverEntry);

      if (local == null && PhotoStore.get(key) == null) {
        created--;
        skipped++;
        log('[merge] ${serverEntry.name} ignorée (tombstone expiré)');
      }
    }
  } catch (e, st) {
    log('[merge] EXCEPTION : $e\n$st');
    rethrow;
  } finally {
    PhotoStore.merging = false;
    await serverBox.close();
    log('[merge] $created créées, $updated fusionnées, $skipped ignorées');
  }
}

Future<void> mergeAlbumsBox(String dir) async {
  final serverBox = await Hive.openBox<AlbumEntry>('temp_albums', path: dir);
  log('[merge] ${serverBox.length} albums côté serveur');

  PhotoStore.merging = true;
  try {
    for (final key in serverBox.keys) {
      final remote = serverBox.get(key);
      if (remote == null) continue;
      log('[merge] album ${remote.name} | del=${remote.deletedAt} '
          'rev=${remote.rev("deletedAt")}');
      await PhotoStore.mergeAlbumFrom(key as String, remote);
    }
  } catch (e, st) {
    log('[merge] EXCEPTION albums : $e\n$st');
    rethrow;
  } finally {
    PhotoStore.merging = false;
    await serverBox.close();
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