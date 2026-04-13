import 'dart:io';
import 'dart:typed_data';

import 'package:fover/main.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/photo_store.dart';

DateTime? parseExifDate(String? raw) {
  if (raw == null) return null;
  try {
    final parts = raw.split(' ');
    final datePart = parts[0].replaceAll(':', '-');
    final timePart = parts.length > 1 ? parts[1] : '00:00:00';
    return DateTime.parse('$datePart $timePart');
  } catch (_) {
    return null;
  }
}

double? parseGps(String value, String ref) {
  try {
    final parts = value.split(', ');
    
    double parseFraction(String fraction) {
      final nums = fraction.split('/');
      return double.parse(nums[0]) / double.parse(nums[1]);
    }

    final degrees = parseFraction(parts[0]);
    final minutes = parseFraction(parts[1]);
    final seconds = parseFraction(parts[2]);

    double decimal = degrees + (minutes / 60) + (seconds / 3600);

    if (ref == 'S' || ref == 'W') decimal = -decimal;

    return decimal;
  } catch (_) {
    return null;
  }
}

int getMP(PhotoEntry photo) {
  int mp = ((photo.height ?? 0) * (photo.width ?? 0) / 1000000).toInt();
  return mp;
}

String formatSize(int size) {
  if (size < 1000) {
    return "$size B";
  } else if (size < 1000000) {
    return "${(size / 1000).toStringAsFixed(1)} KB";
  } else if (size < 1000000000) {
    return "${(size / 1000000).toStringAsFixed(1)} MB";
  } else {
    return "${(size / 1000000000).toStringAsFixed(1)} GB";
  }
}

Future<bool> hasInternet() async {
  try {
    final result = await InternetAddress.lookup('example.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}

enum ServerBackend {
  freebox,
  copyparty,
  none
}

ServerBackend detectBackend() {
  if (box.get("appToken") != null) return ServerBackend.freebox;
  if (box.get("copypartyUrl") != null) return ServerBackend.copyparty;
  return ServerBackend.none;
}

Future<Uint8List?> fetchFullBytes(String encodedPath) async {
    final photo = PhotoStore.get(encodedPath);

    if (photo?.localPath != null && File(photo!.localPath!).existsSync()) {
      return await File(photo.localPath!).readAsBytes();
    }

    if (detectBackend() == ServerBackend.copyparty) {
      final bytes = await CopypartyService.fetchFile(encodedPath);
      return Uint8List.fromList(bytes);
    }

    final response = await client?.fetch(
      url: "v15/dl/$encodedPath",
      parseJson: false,
    );

    return response?.data is Uint8List ? response!.data as Uint8List : null;
}