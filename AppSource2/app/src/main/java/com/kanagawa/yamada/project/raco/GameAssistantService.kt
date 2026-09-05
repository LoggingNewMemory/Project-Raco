package com.kanagawa.yamada.project.raco

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import android.os.Handler
import android.os.Looper

class GameAssistantService : AccessibilityService() {
    private var currentForegroundPackage: String? = null
    private var isCurrentlyInGame = false
    private var lastGamePackage: String? = null
    private var gameSpaceOverlay: RacoGameAssistant? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        serviceInfo = info
        createNotificationChannel()
        
        Handler(Looper.getMainLooper()).post {
            gameSpaceOverlay = RacoGameAssistant(this)
        }
    }

    private fun showForegroundNotification() {
        val notification = Notification.Builder(this, "raco_game_assistant")
            .setContentTitle("Raco Game Assistant is Running")
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setOngoing(true)
            .build()
        startForeground(1, notification)
    }

    private fun hideForegroundNotification() {
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "raco_game_assistant",
                "Game Assistant",
                NotificationManager.IMPORTANCE_LOW // IMPORTANCE_LOW ensures it's silent but visible
            ).apply {
                description = "Keeps the Game Assistant alive in the background"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        
        val packageName = event.packageName?.toString() ?: return
        
        // Ignore System UI (notification bar, volume panel, etc), Android system dialogs, and our own overlay
        if (packageName == "com.android.systemui" || packageName == "android" || packageName == "com.kanagawa.yamada.project.raco") return
        
        // Ignore keyboards
        if (packageName.contains("inputmethod") || packageName.contains("keyboard")) return
        
        val isGame = try {
            java.io.File("/data/ProjectRaco/gamelist.txt").readLines().any { it.trim() == packageName }
        } catch (e: Exception) {
            false
        }
        
        // If it's NOT a game and NOT a full-screen window, it's likely just a popup (like a toast or Google Play Games overlay).
        // We ignore these so they don't accidentally hide the Game Assistant.
        // We DO NOT ignore non-fullscreen events if it IS a game, so the game is detected instantly.
        if (!isGame && !event.isFullScreen) return

        if (packageName == currentForegroundPackage) return
        currentForegroundPackage = packageName
        
        if (isGame && !isCurrentlyInGame) {
            isCurrentlyInGame = true
            lastGamePackage = packageName
            showForegroundNotification()
            Handler(Looper.getMainLooper()).post {
                gameSpaceOverlay?.show(packageName)
            }
        } else if (!isGame && isCurrentlyInGame) {
            isCurrentlyInGame = false
            hideForegroundNotification()
            Handler(Looper.getMainLooper()).post {
                gameSpaceOverlay?.hide()
            }
        } else if (isGame && isCurrentlyInGame && packageName != lastGamePackage) {
            lastGamePackage = packageName
            Handler(Looper.getMainLooper()).post {
                gameSpaceOverlay?.show(packageName)
            }
        }
    }

    override fun onInterrupt() {}
    
    override fun onDestroy() {
        super.onDestroy()
        gameSpaceOverlay?.hide()
    }
}
