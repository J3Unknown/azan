package com.unknown.azan

import android.hardware.GeomagneticField
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "azan/compass")
            .setMethodCallHandler { call, result ->
                if (call.method != "getMagneticDeclination") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val latitude = call.argument<Double>("latitude")
                val longitude = call.argument<Double>("longitude")
                if (latitude == null || longitude == null) {
                    result.error("invalid_location", "Latitude and longitude are required", null)
                    return@setMethodCallHandler
                }
                val field = GeomagneticField(
                    latitude.toFloat(),
                    longitude.toFloat(),
                    0f,
                    System.currentTimeMillis(),
                )
                result.success(field.declination.toDouble())
            }
    }
}
