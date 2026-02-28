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

  @HiveField(3)
  String? coverPath;

  AlbumEntry({required this.name, required this.createdAt, this.description, this.coverPath});
}