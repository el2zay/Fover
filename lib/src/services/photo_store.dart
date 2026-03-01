import 'package:fover/src/models/album_entry.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:fover/src/models/photo_entry.dart';

class PhotoStore {
  static late Box<PhotoEntry> _photoBox;
  static late Box<AlbumEntry> _albumBox;

  static const _photoBoxName = 'photos';
  static const _albumBoxName = 'albums';

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
    Map<String, String>? exif,
  }) async {
    if (_photoBox.containsKey(path)) return;

    await _photoBox.put(path, PhotoEntry(path: path, name: name, date: date, size: size, mimetype: mimetype, exif: exif));
  }

  static Future<void> update({
    required String path,
    String? description,
    String? localisation,
    Map<String, String>? exif,
    String? detectedText,
    bool? hidden,
    
  }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;

    if (description != null) entry.description = description;
    if (localisation != null) entry.localisation = localisation;
    if (exif != null) entry.exif = exif;
    if (detectedText != null) entry.detectedText = detectedText;
    if (hidden != null) entry.hidden = hidden;
    await entry.save();
  }

  static Future<void> addToAlbum({
    required String path,
    required String album,
  }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;
    if (entry.albums!.contains(album)) return;

    entry.albums = [...entry.albums!, album];
    await entry.save();
  }

  static Future<void> removeFromAlbum({
    required String path, 
    required String album,
  }) async {
    final entry = _photoBox.get(path);
    if (entry == null) return;

    entry.albums = entry.albums?.where((a) => a != album).toList();
  await entry.save();
  }

  static Future<AlbumEntry?> createAlbum({
    required String name,
    String? description, 
    String? coverPath,
  }) async {
    if (_albumBox.containsKey(name)) return null;

    final album = AlbumEntry(
      name: name,
      createdAt: DateTime.now(), 
      description: description, 
      coverPath: coverPath
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
      coverPath: album.coverPath,
    );
    await _albumBox.delete(oldName);
  }

  static PhotoEntry? get(String path) => _photoBox.get(path);
  static List<PhotoEntry> getAll() => _photoBox.values.toList();
  static Future<void> delete(String path) async => await _photoBox.delete(path);
  static List<PhotoEntry> getAlbum(String album) =>
    _photoBox.values.where((e) => e.albums!.contains(album)).toList();
  static List<String> getAllAlbums() =>
    _photoBox.values.expand((e) => e.albums!).toSet().toList()..sort();
  static AlbumEntry? getAlbumEntry(String name) => _albumBox.get(name);
  static List<AlbumEntry> getAllAlbumEntries() =>
      _albumBox.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}