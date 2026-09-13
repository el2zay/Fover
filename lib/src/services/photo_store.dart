import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' show Random;
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
  static bool merging = false;
  
  static void _scheduleUpload() {
    if (merging) return;
    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(
      const Duration(seconds: 5), () {
        syncHive();
      }
    );
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
    String? livePhotoPath
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
        deletedAt: deletedAt,
        livePhotoPath: livePhotoPath
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
        isScreenshot: entry.isScreenshot,
        editedFrom: entry.editedFrom,
        isOldVersion: entry.isOldVersion,
        displayDateUpdatedAt: entry.displayDateUpdatedAt,
        livePhotoPath: entry.livePhotoPath
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
    bool clearDisplayDate = false,
    String? localPath,
    String? editedForm,
    bool? isOldVersion,
  }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;

    if (description != null) entry.description = description;
    if (detectedText != null) entry.detectedText = detectedText;

    if (hidden != null) {
      entry.hidden = hidden;
      entry.touch('hidden');
    }
    if (favorite != null) {
      entry.favorite = favorite;
      entry.touch('favorite');
    }

    if (displayDate != null || clearDisplayDate) {
      entry.displayDate = clearDisplayDate ? null : displayDate;
      entry.displayDateUpdatedAt = DateTime.now();
    }

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

    final now = DateTime.now();
    entry.deletedAt = now;
    entry.touch('deletedAt');
    await entry.save();

    if (entry.livePhotoPath != null) {
      final videoEntry = _photoBox.get(entry.livePhotoPath);
      if (videoEntry != null) {
        videoEntry.deletedAt = now;
        videoEntry.touch('deletedAt');
        await videoEntry.save();
      }
    }

    _scheduleUpload();
  }

  static Future<void> permanentDelete(String path) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;

    final videoPath = entry.livePhotoPath;
    if (videoPath != null) {
      await _deleteFromBackend(videoPath);
      final videoEntry = _photoBox.get(videoPath);
      if (videoEntry != null) {
        videoEntry.deletedAt = DateTime.now().subtract(_deletionDelay * 2);
        videoEntry.touch('deletedAt');
        await videoEntry.save();
      }
    }

    await _deleteFromBackend(path);

    entry.deletedAt = DateTime.now().subtract(_deletionDelay * 2);
    entry.touch('deletedAt');
    await entry.save();

    _scheduleUpload();
  }

  //? Rajoutée juste pour éviter de répeter à 2 reprises le même code dans hardDelete
  static Future<void> _deleteFromBackend(String path) async {
    switch (detectBackend()) {
      case ServerBackend.freebox:
        FreeboxService.deleteLocalFile(path);
      case ServerBackend.copyparty:
          await CopypartyService.deleteFile(path);
      default:
        break;
    }
  }

  static Future<void> hardDelete(String path) async {
    final entry = _photoBox.get(path);
    final videoPath = entry?.livePhotoPath;

    if (videoPath != null) {
      await _deleteFromBackend(videoPath);
      await _photoBox.delete(videoPath);
    }

    await _deleteFromBackend(path);
    await _photoBox.delete(path);

    _scheduleUpload();
  }

  static Future<void> restore(String path) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;

    entry.deletedAt = null;
    entry.touch('deletedAt');
    await entry.save();

    if (entry.livePhotoPath != null) {
      final videoEntry = _photoBox.get(entry.livePhotoPath);
      if (videoEntry != null) {
        videoEntry.deletedAt = null;
        videoEntry.touch('deletedAt');
        await videoEntry.save();
      }
    }

    _scheduleUpload();
  }

  static Future<void> purgeExpired() async {
    final now = DateTime.now();

    final expired = _photoBox.values.where((e) =>
      e.deletedAt != null &&
      now.difference(e.deletedAt!) > _deletionDelay,
    ).toList();

    final expiredAlbums = _albumBox.values.where((a) =>
      a.deletedAt != null &&
      now.difference(a.deletedAt!) > _deletionDelay,
    ).toList();

    if (expired.isEmpty && expiredAlbums.isEmpty) return;

    if (expired.isNotEmpty) {
      switch (detectBackend()) {
        case ServerBackend.freebox:
          await client?.fetch(
            url: 'v6/fs/rm/',
            method: 'POST',
            body: {'files': expired.map((e) => e.path).toList()},
          );

        case ServerBackend.copyparty:
          for (final photo in expired) {
            try {
              await CopypartyService.deleteFile(photo.path);
            } catch (e) {
              log('[purge] suppression serveur échouée pour ${photo.name}: $e');
            }
          }

        case ServerBackend.none:
          return;
      }

      for (final photo in expired) {
        await photo.delete();
      }
    }

    for (final album in expiredAlbums) {
      await album.delete();
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

  static void linkLivePhoto({required String imagePath, required String videoPath}) {
    final imageEntry = _photoBox.get(imagePath);
    if (imageEntry != null) {
      imageEntry.livePhotoPath = videoPath;
      imageEntry.save();
    }
    _scheduleUpload();
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

    if (serverFiles.isEmpty) {
      log('[existsOnServer] listing vide, aucune suppression');
      return;
    }

    final now = DateTime.now();

    final toDelete = _photoBox.keys.where((key) {
      final entry = _photoBox.get(key);
      if (entry == null) return true;
      if (entry.deletedAt != null) return false;
      if (entry.isOldVersion == true) return false;
      if (now.difference(entry.date).inMinutes < 10) return false;
      return !serverFiles.contains(entry.path);
    }).toList();

    for (final key in toDelete) {
      final entry = _photoBox.get(key);
      if (entry == null) {
        await _photoBox.delete(key);
        continue;
      }
      log('${entry.name} absent du serveur, marqué supprimé');
      entry.deletedAt = DateTime.now().subtract(_deletionDelay * 2);
      entry.touch('deletedAt');
      await entry.save();
    }
    
    if (toDelete.isNotEmpty) await uploadHive();
  }

  static Future<void> addToAlbum({
    required String path,
    required String album,
  }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;
    if ((entry.albums ?? []).contains(album)) return;

    entry.albums = [...(entry.albums ?? []), album];
    entry.touch('albums');
    await entry.save();
    _scheduleUpload();
  }

  static Future<void> removeFromAlbum({
    required String path,
    required String album,
  }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;
    if (!(entry.albums ?? []).contains(album)) return;

    entry.albums = (entry.albums ?? []).where((a) => a != album).toList();
    entry.touch('albums');
    await entry.save();
    _scheduleUpload();
  }

  static Future<AlbumEntry?> createAlbum({
    required String name,
    String? description,
    Uint8List? coverBytes,
  }) async {
    final existing = _albumBox.get(name);
    if (existing != null) {
      if (existing.deletedAt == null) return null;
      existing.deletedAt = null;
      existing.touch('deletedAt');
      if (description != null) existing.description = description;
      if (coverBytes != null) existing.coverBytes = coverBytes;
      await existing.save();
      _scheduleUpload();
      return existing;
    }

    final album = AlbumEntry(
      name: name,
      createdAt: DateTime.now(),
      description: description,
      coverBytes: coverBytes,
    );
    await _albumBox.put(name, album);
    _scheduleUpload();
    return album;
  }

  static bool isAlbumDeleted(String name) => _albumBox.get(name)?.deletedAt != null;

  static Future<void> deleteAlbum(String name) async {
    final album = _albumBox.get(name);
    if (album == null) return;

    for (final photo in getAlbum(name)) {
      await removeFromAlbum(path: photo.path, album: name);
    }

    album.deletedAt = DateTime.now().subtract(_deletionDelay * 2);
    album.touch('deletedAt');
    await _albumBox.put(name, album);
    _scheduleUpload();
  }

  static Future<void> renameAlbum({
    required String oldName,
    required String newName,
  }) async {
    if (oldName == newName) return;
    if (_albumBox.containsKey(newName) && !isAlbumDeleted(newName)) return;

    final album = _albumBox.get(oldName);
    if (album == null || album.deletedAt != null) return;

    for (final photo in getAlbum(oldName)) {
      photo.albums =
          photo.albums?.map((a) => a == oldName ? newName : a).toList();
      photo.touch('albums');
      await photo.save();
    }

    await createAlbum(
      name: newName,
      description: album.description,
      coverBytes: album.coverBytes,
    );

    await deleteAlbum(oldName);
  }

  static Future<void> mergeFrom(String path, PhotoEntry entry) async {
    final local = _photoBox.get(path);
    if (local == null) {
      if (entry.deletedAt != null &&
          DateTime.now().difference(entry.deletedAt!) > _deletionDelay) {
        return;
      }
      await _photoBox.put(path, entry.clone());
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


    if (_takeRemote(local, entry, 'favorite')) {
      local.favorite = entry.favorite;
      changed = true;
    } else if (local.rev('favorite') == 0 && entry.rev('favorite') == 0) {
      if (entry.favorite == true && local.favorite != true) {
        local.favorite = true;
        changed = true;
      }
    }

    if (_takeRemote(local, entry, 'hidden')) {
      local.hidden = entry.hidden;
      changed = true;
    } else if (local.rev('hidden') == 0 && entry.rev('hidden') == 0) {
      if (entry.hidden == true && local.hidden != true) {
        local.hidden = true;
        changed = true;
      }
    }

    if (_takeRemote(local, entry, 'deletedAt')) {
      local.deletedAt = entry.deletedAt;
      changed = true;
    } else if (local.rev('deletedAt') == 0 && entry.rev('deletedAt') == 0) {
      if (entry.deletedAt != null && local.deletedAt == null) {
        local.deletedAt = entry.deletedAt;
        changed = true;
      }
    }


    final localAlbumsRev = local.rev('albums');
    final remoteAlbumsRev = entry.rev('albums');

    List<String> albums;
    if (remoteAlbumsRev > localAlbumsRev) {
      albums = List<String>.from(entry.albums ?? []);
      (local.revs ??= {})['albums'] = remoteAlbumsRev;
    } else if (localAlbumsRev > remoteAlbumsRev) {
      albums = List<String>.from(local.albums ?? []);
    } else {
      albums = {...?local.albums, ...?entry.albums}.toList();
    }
    albums = albums.where((a) => !isAlbumDeleted(a)).toList();

    final currentAlbums = local.albums ?? [];
    if (albums.length != currentAlbums.length ||
        !albums.every(currentAlbums.contains)) {
      local.albums = albums;
      changed = true;
    }


    if (entry.date.isAfter(DateTime(1970)) &&
        (local.date == DateTime(1970) || entry.date.isBefore(local.date))) {
      local.date = entry.date;
      changed = true;
    }


    final localTs =
        local.displayDateUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final remoteTs =
        entry.displayDateUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final remoteHasChange =
        entry.displayDate != null || entry.displayDateUpdatedAt != null;

    if (remoteHasChange && remoteTs.isAfter(localTs)) {
      local.displayDate = entry.displayDate;
      local.displayDateUpdatedAt = remoteTs;
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

  static List<DateTime> getAvailableMonths() {
    final months = _photoBox.values.where((e) => e.deletedAt == null).
      map((e) => DateTime(e.date.year, e.date.month)).toSet().toList();
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  static List<DateTime> getAvailableYears() {
    final years = _photoBox.values.where((e) => e.deletedAt == null).
      map((e) => DateTime(e.date.year)).toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  static String? getFirstPhotoOf(DateTime date) {
    final entry = _photoBox.values.where((e) =>
      e.deletedAt == null &&
      e.date.year == date.year &&
      (date.month == 1 || e.date.month == date.month)
    ).firstOrNull;
    return entry?.path;
  }

  static ValueListenable<Box<PhotoEntry>>? _listenable;

  static ValueListenable<Box<PhotoEntry>> get listenable {
    _listenable ??= _photoBox.listenable();
    return _listenable!;
  }

  static bool hasPendingUpload() => _uploadDebounce?.isActive == true;

  static List<PhotoEntry> getDeleted() =>
    _photoBox.values.where((e) => e.deletedAt != null).toList();

  static List<PhotoEntry> getAlbum(String album, {bool showEmpty = true}) {
    var query = _photoBox.values.where((e) => (e.albums ?? []).contains(album));
    if (!showEmpty) {
      query = query.where((e) => e.deletedAt == null && e.isOldVersion != true);
    }
    return query.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  static List<AlbumEntry> getAllAlbumEntries() =>
      _albumBox.values.where((a) => a.deletedAt == null).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  static List<String> getAllAlbums() =>
      _photoBox.values.expand((e) => (e.albums ?? []).toSet())
          .where((a) => !isAlbumDeleted(a)).toSet().toList()..sort();

  static ValueListenable<Box<AlbumEntry>>? _albumListenable;

  static ValueListenable<Box<AlbumEntry>> get albumListenable {
      _albumListenable ??= _albumBox.listenable();
      return _albumListenable!;
  }

  static String get boxDir => _photoBox.path!.substring(
    0, _photoBox.path!.lastIndexOf('/'),
  );

  static bool _takeRemote(PhotoEntry local, PhotoEntry remote, String field) {
    final remoteRev = remote.rev(field);
    if (remoteRev <= local.rev(field)) return false;
    (local.revs ??= {})[field] = remoteRev;
    return true;
  }

  static bool _takeRemoteAlbum(AlbumEntry local, AlbumEntry remote, String field) {
    final remoteRev = remote.rev(field);
    if (remoteRev <= local.rev(field)) return false;
    (local.revs ??= {})[field] = remoteRev;
    return true;
  }

  static Future<void> mergeAlbumFrom(String name, AlbumEntry remote) async {
    final local = _albumBox.get(name);
    if (local == null) {
      await _albumBox.put(name, remote.clone());
      return;
    }

    bool changed = false;

    if (_takeRemoteAlbum(local, remote, 'deletedAt')) {
      local.deletedAt = remote.deletedAt;
      changed = true;
    }
    if ((local.description == null || local.description!.isEmpty) &&
        remote.description != null) {
      local.description = remote.description;
      changed = true;
    }
    if (local.coverBytes == null && remote.coverBytes != null) {
      local.coverBytes = remote.coverBytes;
      changed = true;
    }

    if (changed) await _albumBox.put(name, local);
  }

  static String debugCounts() {
    final all = _photoBox.values.toList();
    return '${_photoBox.length} clés / ${getAll().length} visibles / '
        '${all.where((e) => e.deletedAt != null).length} supprimées / '
        '${all.where((e) => e.revs != null).length} avec revs / '
        '${_albumBox.length} albums';
  }

  static String get deviceId {
    var id = box.get('deviceId') as String?;
    if (id == null) {
      id = DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
          Random().nextInt(0x7fffffff).toRadixString(36);
      box.put('deviceId', id);
    }
    return id;
  }
}