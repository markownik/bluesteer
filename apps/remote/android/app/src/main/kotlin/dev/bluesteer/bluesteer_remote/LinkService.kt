package dev.bluesteer.bluesteer_remote

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/// Keeps the process (and so the BLE link) alive while the app is in the
/// background: a `connectedDevice` foreground service with the persistent
/// notification Android requires for it.
class LinkService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val hostName = intent?.getStringExtra(EXTRA_HOST) ?: "your Mac"
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Connection", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        val notification = builder
            .setContentTitle("BlueSteer connected to $hostName")
            .setContentText("The terminal link stays open while the app is in the background.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Android 14+ refuses a connectedDevice service when the Bluetooth permission was
            // revoked (SecurityException) or the app may not start one right now
            // (ForegroundServiceStartNotAllowedException). The link still works in the
            // foreground; without the service it just drops when the app is backgrounded.
            Log.w("BlueSteer", "foreground service refused: $e")
            stopSelf()
        }
        return START_NOT_STICKY
    }

    companion object {
        const val CHANNEL = "link"
        const val NOTIFICATION_ID = 1
        const val EXTRA_HOST = "host"
    }
}
