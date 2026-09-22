package com.kanagawa.yamada.project.raco

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class GameAssistantService : Service() {
    private var gameSpaceOverlay: RacoGameAssistant? = null

    override fun onCreate() {
        super.onCreate()
        Handler(Looper.getMainLooper()).post {
            gameSpaceOverlay = RacoGameAssistant(this)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val pkg = intent?.getStringExtra("package") ?: ""
        if (pkg.isNotEmpty()) {
            Handler(Looper.getMainLooper()).post {
                gameSpaceOverlay?.show(pkg)
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        gameSpaceOverlay?.hide()
    }
}
