import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static int ocrRunning = 0;
  static final int ocrMaxParallel = 3;
  static final ocrQueue = <(String, String)>[];
  
  static const _ocrChannel = MethodChannel('com.fover/ocr');

  // static Future<String?> extractText(String encodedPath, String mimetype) async {
    // final photo = PhotoStore.get(encodedPath);
    // if (photo == null) return null;
    // if (mimetype.startsWith('video')) return null;

    // final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    // try {
    //   InputImage inputImage;

    //   if (photo.localPath != null && File(photo.localPath!).existsSync()) {
    //     inputImage = InputImage.fromFilePath(photo.localPath!);
    //   } else {
    //     Uint8List? bytes;
    //     switch (detectBackend()) {
    //       case ServerBackend.copyparty:
    //         bytes = await CopypartyService.getThumbnail(encodedPath);
    //       case ServerBackend.freebox:
    //         bytes = await fetchImageBytes(encodedPath, mimetype);
    //       default:
    //         break;
    //     }

    //     if (bytes == null) return null;

    //     final dir = await getTemporaryDirectory();
    //     final tmpFile = File('${dir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
    //     await tmpFile.writeAsBytes(bytes);

    //     try {
    //       inputImage = InputImage.fromFilePath(tmpFile.path);
    //       final result = await recognizer.processImage(inputImage);
    //       log("OCR Result : ${result.text}");
    //       return result.text.isEmpty ? null : result.text;
    //     } finally {
    //       await tmpFile.delete();
    //     }
    //   }

    //   final result = await recognizer.processImage(inputImage);
    //   print("Résultat : ${result.text}");
    //   return result.text.isEmpty ? null : result.text;
    // } catch (e) {
    //   log("OCR error : $e");
    //   return null;
    // } finally {
    //   await recognizer.close();
    // }

      
    

  static Future<String?> extractText(Uint8List bytes) async {
    if (!Platform.isIOS && !Platform.isMacOS) return null;
    try {
      final String text = await _ocrChannel.invokeMethod(
        'extractText',
        bytes,
      );
      log("OCR Result: $text");
      return text.isEmpty ? null : text;
    } catch (e) {
      log("OCR error: $e");
      return null;
    }
  }

  static Future runOcrIfNeeded(String encodedPath, String mimetype) async {
    final photo = PhotoStore.get(encodedPath);
    if (photo == null || photo.detectedText != null) return;
    if (mimetype.startsWith('video')) return;

    if (ocrRunning >= ocrMaxParallel) {
      ocrQueue.add((encodedPath, mimetype));
      return;
    }

    ocrRunning++;
    try {
      Uint8List? bytes;

      if (photo.localPath != null && File(photo.localPath!).existsSync()) {
        bytes = await File(photo.localPath!).readAsBytes();
      } else {
        switch (detectBackend()) {
          case ServerBackend.copyparty:
            bytes = await CopypartyService.getThumbnail(encodedPath);
          default:
            break;
        }
      }

      if (bytes == null) return;

      final text = await extractText(bytes);
      await PhotoStore.update(path: encodedPath, detectedText: text ?? "");
    } finally {
      ocrRunning--;
      if (ocrQueue.isNotEmpty) {
        final next = ocrQueue.removeAt(0);
        Future.microtask(() => runOcrIfNeeded(next.$1, next.$2));
      }
    }
  }
}