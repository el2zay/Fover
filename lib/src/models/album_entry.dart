import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

part 'album_entry.g.dart';

@HiveType(typeId: 1)
class AlbumEntry extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final DateTime createdAt;

  @HiveField(2)
  String? description;

  // Obliger de sauter le 3 car on l'a déjà utilisé auparavent : risque de corruption

  @HiveField(4)
  Uint8List? coverBytes;

  @HiveField(5)
  DateTime? deletedAt;

  @HiveField(6)
  Map<String, int>? revs;

  AlbumEntry({
    required this.name,
    required this.createdAt,
    this.description,
    this.coverBytes,
    this.deletedAt,
    this.revs,
  });

  void touch(String field) =>
      (revs ??= {})[field] = DateTime.now().toUtc().millisecondsSinceEpoch;

  int rev(String field) => revs?[field] ?? 0;

  AlbumEntry clone() {
    return AlbumEntry(
      name: name,
      createdAt: createdAt,
      description: description,
      coverBytes: coverBytes != null ? Uint8List.fromList(coverBytes!) : null,
      deletedAt: deletedAt,
      revs: revs != null ? Map<String, int>.from(revs!) : null,
    );
  }
}