import 'package:hive_ce/hive_ce.dart';

part 'photo_entry.g.dart';

@HiveType(typeId: 0)
class PhotoEntry extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final int size;

  @HiveField(3)
  String? description;

  @HiveField(4)
  String? localisation;

  @HiveField(5)
  Map<String, String>? exif;

  @HiveField(6)
  String? detectedText;

  @HiveField(7)
  List<String>? albums; 

  PhotoEntry({required this.path, required this.date, required this.size, this.description, this.localisation, this.exif, this.detectedText, this.albums});

}