import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:fover/src/services/copyparty_service.dart';

class ShareIntentService {
  static StreamSubscription? _intentSub;

  static void init() {
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) => _handleSharedFiles(files),
      onError: (err) => log("Erreur de partage : $err"),
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleSharedFiles(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  static void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    print("Fichiers reçus : ${files.length}");
    for (final file in files) {
      CopypartyService.uploadLocalFiles(
        files: [File(file.path)],
        filenames: [file.path.split('/').last],
      );
    }
  }

  static void dispose() {
    _intentSub?.cancel();
    _intentSub = null;
  }
}