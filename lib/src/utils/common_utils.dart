import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:fover/main.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

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

double? parseGpsFromTag(dynamic rawTag, dynamic rawRef) {
  if (rawTag == null || rawRef == null) return null;

  try {
    final raw = rawTag.printable
        .replaceAll('[', '')
        .replaceAll(']', '')
        .trim();

    final parts = raw.split(',').map((p) => p.trim()).toList();

    double parseRatio(String s) {
      if (s.contains('/')) {
        final nums = s.split('/');
        final den = double.parse(nums[1]);
        if (den == 0) return 0;
        return double.parse(nums[0]) / den;
      }
      return double.parse(s);
    }

    final degrees = parseRatio(parts[0]);
    final minutes = parseRatio(parts[1]);
    final seconds = parseRatio(parts[2]);

    final ref = rawRef.printable.trim().toUpperCase();
    var decimal = degrees + (minutes / 60) + (seconds / 3600);
    if (ref == 'S' || ref == 'W') decimal = -decimal;

    return decimal;
  } catch (e) {
    log('parseGps error: $e | tag=$rawTag');
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

String formatDate(String date, {bool yearsOnly = false}) {
  try {
    final parts = date.split('-');
    final year = parts[0];
    final monthNum = int.parse(parts[1]);
    final month = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][monthNum - 1];
    return yearsOnly ? year : '$month $year';
  } catch (_) {
    return date;
  }
}

Future<bool> hasInternet({bool? withBox}) async {
  if (withBox != false && box.get("offlineMode") == true) return false;
  
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

Future<bool> urlExists(String url, {required Map<String, String> headers}) async {
  try {
    final response = await http.head(
      Uri.parse(url), 
      headers: headers
    ).timeout(const Duration(seconds: 3));
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}


String cleanName(String filename, {bool removeExtension = false}) {
  final pattern = RegExp(r'-\d+\.\d+-[a-zA-Z0-9]+\.[a-zA-Z0-9]+$');
  String cleaned = filename.replaceAll(pattern, '');
  if (removeExtension) {
    final ext = cleaned.lastIndexOf('.');
    if (ext >= 0) {
      cleaned = cleaned.substring(0, ext);
    }
  }
  return cleaned;
}

Future<void> openUrl(Uri url) async {
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  }
}

bool get isTablet {
  final display = PlatformDispatcher.instance.views.first.display;
  return display.size.shortestSide / display.devicePixelRatio > 600;
}