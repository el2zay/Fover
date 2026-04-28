import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:fover/main.dart';
import 'package:fover/src/models/album_entry.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/freebox_service.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:freebox/freebox.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:fover/src/models/photo_entry.dart';

class PhotoStore {
  static late Box<PhotoEntry> _photoBox;
  static late Box<AlbumEntry> _albumBox;

  static const _photoBoxName = 'photos';
  static const _albumBoxName = 'albums';
  static const _deletionDelay = Duration(days:30);

  static Timer? _uploadDebounce;
  
  static void _scheduleUpload() {
    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(const Duration(seconds: 5), () {
      print('_scheduleUpload firing -> uploadHive');
      uploadHive();
    });
  }

  static void cancelScheduledUpload() {
    _uploadDebounce?.cancel();
  }

  static Future<void> init() async {
    await Hive.initFlutter();
    
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PhotoEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AlbumEntryAdapter());
    }

    _photoBox = await Hive.openBox(_photoBoxName);
    _albumBox = await Hive.openBox(_albumBoxName);
  }


  static Future<void> addPhoto ({
    required String path,
    required String name,
    required DateTime date, 
    required int size,
    required String mimetype,
    int? duration,
    double? latitude,
    double? longitude,
    String? cameraBrand,
    String? cameraModel,
    int? height,
    int? width,
    int? iso,
    int? focalLength,
    int? exposureValue,
    int? focus,
    int? shutterSpeed,
    DateTime? displayDate,
    bool? isScreenshot,
    String? editedFrom,
    bool isOldVersion = false,
    DateTime? deletedAt,
  }) async {
    if (_photoBox.containsKey(path)) return;

    await _photoBox.put(
      path, 
      PhotoEntry(
        path: path, 
        name: name,
        date: date, 
        size: size, 
        mimetype: mimetype, 
        duration: duration,
        latitude: latitude,
        longitude: longitude,
        cameraBrand: cameraBrand,
        cameraModel: cameraModel,
        height: height,
        width: width,
        iso: iso,
        focalLength: focalLength,
        exposureValue: exposureValue,
        focus: focus,
        shutterSpeed: shutterSpeed,
        displayDate: displayDate,
        isScreenshot: isScreenshot,
        editedFrom: editedFrom,
        isOldVersion: isOldVersion,
        deletedAt: deletedAt
      )
    );
    _scheduleUpload();
  }

  static Future<void> duplicate({
    required String path
  }) async {
    // TODO apparemment il n'est pas possible de dupliquer des fichiers avec copyparty
    // A vérifier !
    if (detectBackend() != ServerBackend.freebox) return; 

    final entry = _photoBox.get(path);
    if (entry == null) return;

    final decoded = utf8.decode(base64.decode(path));
    final parentDecoded = decoded.substring(0, decoded.lastIndexOf('/'));
    final dst = base64.encode(utf8.encode(parentDecoded));
    final filename = decoded.substring(decoded.lastIndexOf('/') + 1);

    final success = await client?.fetch(
      url: "v15/fs/cp",
      method: "POST",
      body: {
        "files" : [path],
        "dst" : dst,
        "mode" : "both"
      },
    );

    final newName = success?.data?['result']?['name'] ?? filename;
    final newPath = base64.encode(utf8.encode("$parentDecoded/$newName"));

    if (success?.data?['success'] != true) return;

    await _photoBox.put(
      dst,
      PhotoEntry(
        path: newPath, 
        name: newName, 
        date: entry.date, 
        size: entry.size, 
        mimetype: entry.mimetype,
        latitude: entry.latitude,
        longitude: entry.longitude,
        cameraBrand: entry.cameraBrand,
        cameraModel: entry.cameraModel,
        height: entry.height,
        width: entry.width,
        iso: entry.iso,
        focalLength: entry.focalLength,
        exposureValue: entry.exposureValue,
        focus: entry.focus,
        shutterSpeed: entry.shutterSpeed,
        displayDate: entry.displayDate,
        localPath: entry.localPath,
        isScreenshot: entry.isScreenshot
      )
    );
    _scheduleUpload();
  }

  static Future<void> update({
    required String path,
    String? description,
    double? latitude,
    double? longitude,
    Map<String, String>? exif,
    String? detectedText,
    bool? hidden,
    bool? favorite,
    DateTime? displayDate,
    String? localPath,
    String? editedForm,
    bool? isOldVersion
    }) async {
      final entry = _photoBox.get(path);
      if (entry == null) return;

      if (description != null) entry.description = description;
      if (detectedText != null) entry.detectedText = detectedText;
      if (hidden != null) entry.hidden = hidden;
      if (favorite != null) entry.favorite = favorite;
      if (displayDate != null) entry.displayDate = displayDate;
      if (localPath != null) entry.localPath = localPath;
      if (editedForm != null) entry.editedFrom = editedForm;
      if (isOldVersion != null) entry.isOldVersion = isOldVersion;

      if (latitude != null && longitude != null) {
        entry.latitude = latitude;
        entry.longitude = longitude;
      }
      
      await entry.save();
      _scheduleUpload();
  }

  static DateTime getDate(String path) {
    final entry = _photoBox.get(path);
    return entry?.displayDate ?? entry?.date ?? DateTime(1970);
  }

  static DateTime getOriginalDate(String path) {
    final entry = _photoBox.get(path);
    return entry?.date ?? DateTime(1970);
  }

  static Future<void> softDelete(String path) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;
    entry.deletedAt = DateTime.now();
    entry.albums = [];
    entry.favorite = false;
    await entry.save();
    _scheduleUpload();
  }

  static Future<void> hardDelete(String path) async {
    switch (detectBackend()) {
      case ServerBackend.freebox:
        FreeboxService.deleteLocalFile(path);
      case ServerBackend.copyparty:
        await CopypartyService.deleteFile(path);
      default:
        break;
    }
    await _photoBox.delete(path);
    _scheduleUpload();
  }

  static Future<void> restore(String path) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;
    entry.deletedAt = null;
    await entry.save();
    _scheduleUpload();
  }

  static Future<void> purgeExpired() async {
    final now = DateTime.now();
    final expired = _photoBox.values.where((e) =>
      e.deletedAt != null &&
      now.difference(e.deletedAt!) > _deletionDelay,
    ).toList();

    if (expired.isEmpty) return;

    switch (detectBackend()) {
      case ServerBackend.freebox:
        await client?.fetch(
          url: 'v6/fs/rm/',
          method: 'POST',
          body: {'files': expired.map((e) => e.path).toList()},
        );

      case ServerBackend.copyparty:
        for (final photo in expired) {
          await CopypartyService.deleteFile(photo.path);
        }

      case ServerBackend.none:
        break;
    }

    for (final photo in expired) {
      await photo.delete();
    }
    _scheduleUpload();
  }

  static Future<void> revertEdit(String editedPath) async {
    final editedEntry = _photoBox.get(editedPath);
    if (editedEntry == null) return;

    final originalPath = editedEntry.editedFrom;
    if (originalPath == null) return;

    await update(path: originalPath, isOldVersion: false);

    await hardDelete(editedPath);
  }

  static Future<String?> uploadEditedPhoto({
    required Uint8List bytes, 
    required String filename,
    required String folderEncodedPath
  }) async {
    switch (detectBackend()) {
      case ServerBackend.copyparty:
        return await CopypartyService.uploadBytes(
          bytes: bytes, 
          filename: filename, 
          folderEncodedPath: folderEncodedPath
        );
      
      case ServerBackend.freebox:
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
        return base64.encode(utf8.encode('$folderDecoded/$filename'));

        default:
          return null;
    }
  }


  static Future<void> existsOnServer() async {
    Set<String> serverFiles = {};
    switch (detectBackend()) {
      case ServerBackend.freebox:
        final response = await client?.fetch(url: 'v15/fs/ls/L0ZyZWVib3gvVGVzdA==');
        serverFiles = (response?.data?['result']?['entries'] as List<dynamic>?)
          ?.map((e) => e['path'] as String).toSet() ?? {};

      case ServerBackend.copyparty:
        serverFiles = await CopypartyService.listAllFiles();

      case ServerBackend.none:
        return;
    }

    final toDelete = _photoBox.keys.where((key) {
      final entry = _photoBox.get(key);
      if (entry == null) return true;
      if (entry.deletedAt != null) return false;
      if (entry.isOldVersion == true) return false;
      return !serverFiles.contains(entry.path);
    }).toList();

    for (final key in toDelete) {
      log('File ${_photoBox.get(key)?.name} does not exist on server, deleting locally');
      await _photoBox.delete(key);
    }
  }

  static Future<void> addToAlbum({
    required String path,
    required String album,
  }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;
    if ((entry.albums ?? []).contains(album)) return;

    entry.albums = [...(entry.albums ?? []), album];
    await entry.save();
    _scheduleUpload();
  }

  static Future<void> removeFromAlbum({
    required String path, 
    required String album,
  }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;

    entry.albums = (entry.albums ?? []).where((a) => a != album).toList();
    await entry.save();
    _scheduleUpload();
  }

  static Future<AlbumEntry?> createAlbum({
    required String name,
    String? description, 
    Uint8List? coverBytes,
  }) async {
    if (_albumBox.containsKey(name)) return null;

    final album = AlbumEntry(
      name: name,
      createdAt: DateTime.now(), 
      description: description, 
      coverBytes: coverBytes
    );
    await _albumBox.put(name, album);
    _scheduleUpload();
    return album;
  }

  static Future<void> deleteAlbum(String name) async {
    for (final photo in getAlbum(name)) {
      await removeFromAlbum(path: photo.path, album: name);
    }
    await _albumBox.delete(name);
    _scheduleUpload();
  }

  static Future<void> renameAlbum({
    required String oldName,
    required String newName,
  }) async {
    if (_albumBox.containsKey(newName)) return;

    final album = _albumBox.get(oldName);
    if (album == null) return;

    for (final photo in getAlbum(oldName)) {
      photo.albums = photo.albums?.map((a) => a == oldName ? newName : a).toList();
      await photo.save();
    }

    await createAlbum(
      name: newName,
      description: album.description,
      coverBytes: album.coverBytes,
    );
    await _albumBox.delete(oldName);
  }

  static Future<void> mergeFrom(String path, PhotoEntry entry) async {
    final local = _photoBox.get(path);

    if (local == null) {
      await _photoBox.put(path, entry);
      return;
    }

    bool changed = false;

    if (local.latitude == null && entry.latitude != null) {
        local.latitude = entry.latitude;
        local.longitude = entry.longitude;
        changed = true;
      }
    if ((local.detectedText == null || local.detectedText!.isEmpty) &&
        entry.detectedText != null && entry.detectedText!.isNotEmpty) {
      local.detectedText = entry.detectedText;
      changed = true;
    }
    if ((local.description == null || local.description!.isEmpty) &&
        entry.description != null) {
      local.description = entry.description;
      changed = true;
    }
    if (local.cameraModel == null && entry.cameraModel != null) {
      local.cameraModel = entry.cameraModel;
      changed = true;
    }
    if ((local.width == null || local.width == 0) && entry.width != null) {
      local.width = entry.width;
      local.height = entry.height;
      changed = true;
    }
    if (entry.favorite != local.favorite) {
      local.favorite = entry.favorite;
      changed = true;
    }
    if (entry.hidden != local.hidden) {
      local.hidden = entry.hidden;
      changed = true;
    }

    final localAlbums = local.albums ?? [];
    final merged = {...localAlbums, ...(entry.albums ?? [])}.toList();
    if (merged.length != localAlbums.length) {
      local.albums = merged;
      changed = true;
    }

    if (entry.date.isAfter(DateTime(1970)) &&
        (local.date == DateTime(1970) || entry.date.isBefore(local.date))) {
      local.date = entry.date;
      changed = true;
    }

    if (entry.displayDate != null) {
      if (local.displayDate == null || entry.displayDate!.isAfter(local.displayDate!)) {
        local.displayDate = entry.displayDate;
        changed = true;
      }
    }

    if (entry.deletedAt != local.deletedAt) {
      local.deletedAt = entry.deletedAt;
      changed = true;
    }

    if (changed) await local.save();
  }

  static PhotoEntry? get(String path) => _photoBox.get(path);

  static List<PhotoEntry> getAll() =>
    _photoBox.values.where((e) =>
      e.deletedAt == null &&
      e.isOldVersion != true
    ).toList();

  static int get favoritesCount => 
    _photoBox.values.where((e) => e.favorite == true).length;

  static int get videosCount => 
    _photoBox.values.where((e) => e.mimetype?.startsWith('video/') == true && e.deletedAt == null).length;

  static int get screenshotsCount => 
    _photoBox.values.where((e) => e.isScreenshot == true && e.deletedAt == null).length;

  static bool isLandscape(String path) {
    final photo = _photoBox.get(path);
    final w = photo?.width ?? 0;
    final h = photo?.height ?? 0;
    if (w == 0 || h == 0) return false;
    return w > h;
  }

  static List<PhotoEntry> getGeotagged() =>
    _photoBox.values.where((e) =>
      e.deletedAt == null &&
      e.isOldVersion != true &&
      e.latitude != null &&
      e.longitude != null,
    ).toList();

  static ValueListenable<Box<PhotoEntry>>? _listenable;

  static ValueListenable<Box<PhotoEntry>> get listenable {
    _listenable ??= _photoBox.listenable();
    return _listenable!;
  }

  static bool hasPendingUpload() => _uploadDebounce?.isActive == true;

  static List<PhotoEntry> getDeleted() =>
    _photoBox.values.where((e) => e.deletedAt != null).toList();

  static List<PhotoEntry> getAlbum(String album) =>
    _photoBox.values.where((e) => (e.albums ?? []).contains(album)).toList();

  static List<String> getAllAlbums() =>
    _photoBox.values.expand((e) => (e.albums ?? []).toSet()).toList()..sort();

  static AlbumEntry? getAlbumEntry(String name) => _albumBox.get(name);

  static List<AlbumEntry> getAllAlbumEntries() =>
      _albumBox.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  static ValueListenable<Box<AlbumEntry>>? _albumListenable;

  static ValueListenable<Box<AlbumEntry>> get albumListenable {
      _albumListenable ??= _albumBox.listenable();
      return _albumListenable!;
  }
}