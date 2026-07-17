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

class GameAssistantService : AccessibilityService() {
    private var currentForegroundPackage: String? = null
    private var isCurrentlyInGame = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        serviceInfo = info
        
        createNotificationChannel()
        val notification = Notification.Builder(this, "raco_game_assistant")
            .setContentTitle("Project Raco Game Assistant is Running")
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .build()
            
        startForeground(1, notification)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "raco_game_assistant",
                "Game Assistant",
                NotificationManager.IMPORTANCE_MIN
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        
        val packageName = event.packageName?.toString() ?: return
        if (packageName == currentForegroundPackage) return
        currentForegroundPackage = packageName
        
        val sharedPrefs = getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
        val addedGames = sharedPrefs.getStringSet("automation_games", emptySet()) ?: emptySet()
        val isGame = addedGames.contains(packageName)
        
        if (isGame && !isCurrentlyInGame) {
            isCurrentlyInGame = true
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "raco_main load $packageName"))
                } catch (e: Exception) {}
            }
        } else if (!isGame && isCurrentlyInGame) {
            isCurrentlyInGame = false
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "raco_main unload"))
                } catch (e: Exception) {}
            }
        }
    }

    override fun onInterrupt() {}
}
