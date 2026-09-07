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
        createNotificationChannel()
        Handler(Looper.getMainLooper()).post {
            gameSpaceOverlay = RacoGameAssistant(this)
        }
        showForegroundNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val action = intent.action
            if (action == "com.kanagawa.yamada.project.raco.SHOW_OVERLAY") {
                val pkg = intent.getStringExtra("package") ?: ""
                if (pkg.isNotEmpty()) {
                    Handler(Looper.getMainLooper()).post {
                        gameSpaceOverlay?.show(pkg)
                    }
                }
            } else if (action == "com.kanagawa.yamada.project.raco.HIDE_OVERLAY") {
                Handler(Looper.getMainLooper()).post {
                    gameSpaceOverlay?.hide()
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun showForegroundNotification() {
        val notification = Notification.Builder(this, "raco_game_assistant")
            .setContentTitle("Raco Game Assistant is Running")
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setOngoing(true)
            .build()
        startForeground(1, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "raco_game_assistant",
                "Game Assistant",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the Game Assistant alive in the background"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        gameSpaceOverlay?.hide()
    }
}
