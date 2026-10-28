package dev.bluesteer.bluesteer_remote

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.bluesteer/link_service").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    requestNotificationPermission()
                    val intent = Intent(this, LinkService::class.java).putExtra(LinkService.EXTRA_HOST, call.argument<String>("host"))
                    ContextCompat.startForegroundService(this, intent)
                    result.success(null)
                }
                "stop" -> {
                    stopService(Intent(this, LinkService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Android 13+ hides the service's notification without this; the service runs either way.
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
    }
}
