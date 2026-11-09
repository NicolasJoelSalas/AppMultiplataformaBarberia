package com.example.barberapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "barberapp/cloudinary")
            .setMethodCallHandler { call, result ->
                if (call.method == "read") {
                    result.success(
                        mapOf(
                            "cloudName" to getString(R.string.cloudinary_cloud_name),
                            "uploadPreset" to getString(R.string.cloudinary_upload_preset)
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
