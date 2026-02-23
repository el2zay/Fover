import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ✅ Obligatoire - enregistre path_provider et tous les autres plugins
    GeneratedPluginRegistrant.register(with: self)

    // ✅ Approche officielle Flutter (le warning est bénin pour l'instant)
    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }

    let channel = FlutterMethodChannel(
      name: "fover/video_thumbnail",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      if call.method == "getFirstFrame",
         let args = call.arguments as? [String: Any],
         let path = args["path"] as? String {

        let asset = AVAsset(url: URL(fileURLWithPath: path))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
          let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
          let uiImage = UIImage(cgImage: cgImage)
          if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
            result(FlutterStandardTypedData(bytes: jpegData))
          } else {
            result(FlutterError(code: "ENCODE_ERROR", message: nil, details: nil))
          }
        } catch {
          result(FlutterError(code: "FRAME_ERROR", message: error.localizedDescription, details: nil))
        }

      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
