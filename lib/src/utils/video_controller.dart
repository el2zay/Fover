import 'dart:developer';
import 'dart:io';

import 'package:fover/main.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/download.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController?> buildVideoController(String encodedPath) async {
  VideoPlayerController controller;
  final decodedPath = Uri.decodeFull(encodedPath);
  final lastSlash = decodedPath.lastIndexOf('/');
  final dir = lastSlash >= 0 ? decodedPath.substring(0, lastSlash + 1) : '';
  final filename = lastSlash >= 0 ? decodedPath.substring(lastSlash + 1) : decodedPath;

  if (DownloadService.isDownloaded(encodedPath)) {
    final localPath = PhotoStore.get(encodedPath)?.localPath;
    if (localPath == null) return null;

    final controller = VideoPlayerController.file(
      File(localPath),
    );

    try {
      await controller.initialize();
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  } else if (detectBackend() == ServerBackend.copyparty) {
    final cleanedName = cleanName(filename, removeExtension: true);
    final hlsPath = '$dir.hls/$cleanedName/master.m3u8';

    final hlsUri = Uri.parse(CopypartyService.baseUrl).resolve(
      'photos/${hlsPath.split('/').map(Uri.encodeComponent).join('/')}',
    );

    final originalUri = Uri.parse(CopypartyService.baseUrl).resolve(
      'photos/${decodedPath.split('/').map(Uri.encodeComponent).join('/')}',
    );

    final hlsExists = await urlExists(
      hlsUri.toString(),
      headers: {'Authorization': 'Basic ${CopypartyService.credentials}'}
    );

    controller = VideoPlayerController.networkUrl(
      hlsExists ? hlsUri : originalUri,
      httpHeaders: {
        'Authorization': 'Basic ${CopypartyService.credentials}',
      },
    );

    log('hlsUri: $hlsUri\n hlsExists: $hlsExists originalUri: $originalUri');
  } else {
    controller = VideoPlayerController.networkUrl(
      Uri.parse('https://${box.get('apiDomain')}:${box.get('httpsPort')}/api/v1/5dl$encodedPath'),
      httpHeaders: {'X-Fbx-App-Auth': client!.sessionToken!},
    );
  }

  try {
    await controller.initialize();
    return controller;
  } catch (_) {
    await controller.dispose();
    return null;
  }
}