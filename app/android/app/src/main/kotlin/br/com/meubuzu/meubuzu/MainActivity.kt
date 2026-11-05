package br.com.meubuzu.meubuzu

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val locationChannel = "br.com.meubuzu.meubuzu/location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, locationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasGpsHardware" -> result.success(
                        packageManager.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
