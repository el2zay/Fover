import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:fover/main.dart';
import 'package:fover/src/models/album_entry.dart';
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

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PhotoEntryAdapter());
    Hive.registerAdapter(AlbumEntryAdapter());
    _photoBox = await Hive.openBox(_photoBoxName);
    _albumBox = await Hive.openBox(_albumBoxName);
  }

  static Future<void> addPhoto ({
    required String path,
    required String name,
    required DateTime date, 
    required int size,
    required String mimetype,
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
    int? shutterSpeed
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
        shutterSpeed: shutterSpeed
      )
    );
  }

  static Future<void> duplicate({
    required String path
  }) async {

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
        shutterSpeed: entry.shutterSpeed
      )
    );

  }

  static Future<void> update({
    required String path,
    String? description,
    String? localisation,
    Map<String, String>? exif,
    String? detectedText,
    bool? hidden,
    bool? favorite  
    }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;

    if (description != null) entry.description = description;
    if (detectedText != null) entry.detectedText = detectedText;
    if (hidden != null) entry.hidden = hidden;
    if (favorite != null) entry.favorite = favorite;
    await entry.save();
  }

  static Future<void> softDelete(String path) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;
    entry.deletedAt = DateTime.now();
    entry.albums = [];
    entry.favorite = false;
    await entry.save();
  }

  static Future<void> hardDelete(String path) async {
    deleteLocalFile(path);
    await _photoBox.delete(path);
  }

  static Future<void> restore(String path) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;
    entry.deletedAt = null;
    await entry.save();
  }

  static Future<void> purgeExpired(FreeboxClient client) async {
    final now = DateTime.now();
    final expired = _photoBox.values.where((e) =>
      e.deletedAt != null &&
      now.difference(e.deletedAt!) > _deletionDelay,
    ).toList();

    for (final photo in expired) {
      // Supprime sur la Freebox
      await client.fetch(
        url: 'v6/fs/rm/',
        method: 'POST',
        body: {'files': [photo.path]},
      );
      // Supprime de Hive
      await photo.delete();
    }
  }

  static Future<void> existsOnServer() async {
    final response = await client?.fetch(
      url: 'v15/fs/ls/L0ZyZWVib3gvVGVzdA=='
    );

    final serverFiles = (response?.data?['result']?['entries'] as List<dynamic>?)
      ?.map((e) => e['path'] as String).toSet() ?? {};

    final toDelete = _photoBox.keys.where((key) => !serverFiles.contains(key)).toList();
  
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
  }

  static Future<void> removeFromAlbum({
    required String path, 
    required String album,
  }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;

    entry.albums = (entry.albums ?? []).where((a) => a != album).toList();
  await entry.save();
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
    return album;
  }

  static Future<void> deleteAlbum(String name) async {
    for (final photo in getAlbum(name)) {
      await removeFromAlbum(path: photo.path, album: name);
    }
    await _albumBox.delete(name);
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

  static PhotoEntry? get(String path) => _photoBox.get(path);

  static List<PhotoEntry> getAll() =>
    _photoBox.values.where((e) => e.deletedAt == null).toList();

  static int get favoritesCount => 
    _photoBox.values.where((e) => e.favorite == true).length;

  static int get videosCount => 
    _photoBox.values.where((e) => e.mimetype?.startsWith('video/') == true && e.deletedAt == null).length;

  static ValueListenable<Box<PhotoEntry>>? _listenable;

  static ValueListenable<Box<PhotoEntry>> get listenable {
    _listenable ??= _photoBox.listenable();
    return _listenable!;
  }

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