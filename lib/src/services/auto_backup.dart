import 'dart:developer';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fover/main.dart';
import 'package:fover/src/services/local_gallery.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:photo_manager/photo_manager.dart';

class AutoBackup {
  static const _batchSize = 20;
  static bool _running = false;
  static bool _stopRequested = false;

  static Future<bool> batteryAllows() async {
    final threshold = (box.get('batterySync', defaultValue: 100) as num).toInt();
    if (threshold >= 100) return false;
    if (threshold <= 0) return true;
    try {
      return await Battery().batteryLevel > threshold;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _onWifi() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  static bool _networkAllows(AssetEntity asset, bool onWifi) {
    if (onWifi) return true;
    final key = asset.type == AssetType.video ? 'syncVideos' : 'syncPhotos';
    return box.get(key, defaultValue: 'wifi') == 'any';
  }


  static Future<void> run() async {
    if (_running) return;
    if (galleryMode != GalleryMode.merged || !connectedToInternet) return;
    if (!await batteryAllows()) return;

    _running = true;
    _stopRequested = false;
    try {
      // D'abord rapprocher ce qui existe déjà, pour ne rien envoyer en double
      await LocalLinks.autoMatch();
      final linked = LocalLinks.assetIds();
      final pending = LocalGallery.assets.value
          .where((a) => !linked.contains(a.id))
          .toList();

      var sent = 0;
      while (sent < pending.length) {
        // Les conditions peuvent changer pendant l'envoi : on revérifie à chaque lot
        if (_stopRequested || !await batteryAllows()) break;

        final onWifi = await _onWifi();
        final batch = pending
            .skip(sent)
            .take(_batchSize)
            .where((a) => _networkAllows(a, onWifi))
            .toList();
        sent += _batchSize;

        if (batch.isEmpty) continue;
        await libraryKey.currentState?.uploadAssets(batch);
        await libraryKey.currentState?.refresh();
      }
      log('[backup] terminé');
    } catch (e) {
      log('[backup] interrompu : $e');
    } finally {
      _running = false;
    }
  }

  static void stop() => _stopRequested = true;
}