import 'package:hive_ce/hive_ce.dart';

part 'photo_entry.g.dart';

@HiveType(typeId: 0)
class PhotoEntry extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final String name;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  final int size;

  @HiveField(4)
  String? description;

  @HiveField(5)
  String? mimetype;

  @HiveField(6)
  int? duration;

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

  @HiveField(18)
  int? height;

  @HiveField(19)
  int? width;

  @HiveField(20)
  int? iso;

  @HiveField(21)
  int? focalLength;

  @HiveField(22)
  int? exposureValue;

  @HiveField(23)
  int? focus;

  @HiveField(24)
  int? shutterSpeed;

  @HiveField(25)
  DateTime? displayDate;
  
  @HiveField(26)
  String? localPath;

  @HiveField(27)
  bool? isScreenshot;

  @HiveField(28)
  String? editedFrom;

  @HiveField(29)
  bool? isOldVersion;

  @HiveField(30)
  DateTime? displayDateUpdatedAt;
  PhotoEntry({required this.path, required this.name, required this.date, required this.size, this.description, required this.mimetype, this.duration, this.detectedText, this.albums, this.hidden, this.favorite, this.deletedAt, this.latitude, this.longitude, this.cameraBrand, this.cameraModel, this.height, this.width, this.iso, this.focalLength, this.exposureValue, this.focus, this.shutterSpeed, this.displayDate, this.localPath, this.isScreenshot, this.editedFrom, this.isOldVersion, this.displayDateUpdatedAt});

}