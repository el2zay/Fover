package com.example.fover

import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper()) // ✅

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fover/video_thumbnail")
            .setMethodCallHandler { call, result ->
                if (call.method == "getFirstFrame") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("NO_PATH", null, null)
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        val retriever = MediaMetadataRetriever()
                        try {
                            retriever.setDataSource(path)
                            val bitmap = retriever.getFrameAtTime(
                                0,
                                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                            )
                            val stream = ByteArrayOutputStream()
                            bitmap?.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, stream)

                            mainHandler.post { // ✅ au lieu de mainLooper.run
                                result.success(stream.toByteArray())
                            }
                        } catch (e: Exception) {
                            mainHandler.post { // ✅
                                result.error("FRAME_ERROR", e.message, null)
                            }
                        } finally {
                            retriever.release()
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
