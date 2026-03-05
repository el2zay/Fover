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

  AlbumEntry({required this.name, required this.createdAt, this.description, this.coverBytes});
}