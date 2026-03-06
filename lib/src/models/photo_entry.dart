import 'package:hive_ce/hive_ce.dart';

part 'photo_entry.g.dart';

@HiveType(typeId: 0)
class PhotoEntry extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final int size;

  @HiveField(4)
  String? description;

  @HiveField(5)
  String? mimetype;

  // @HiveField(6)
  // String? localisation;

  // @HiveField(7)
  // Map<String, String>? exif;

  @HiveField(8)
  String? detectedText;

  @HiveField(9)
  List<String>? albums; 

  @HiveField(10)
  bool? hidden;

  @HiveField(11)
  DateTime? deletedAt;

  @HiveField(12)
  bool? favorite;

  @HiveField(14)
  double? latitude;

  @HiveField(15)
  double? longitude;

  @HiveField(16)
  String? cameraBrand;

  @HiveField(17)
  String? cameraModel;

  PhotoEntry({required this.path, required this.name, required this.date, required this.size, this.description, required this.mimetype, this.detectedText, this.albums, this.hidden, this.favorite, this.deletedAt, this.latitude, this.longitude, this.cameraBrand, this.cameraModel});

}