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
    private var lastGamePackage: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        serviceInfo = info
        createNotificationChannel()
    }

    private fun showForegroundNotification() {
        val notification = Notification.Builder(this, "raco_game_assistant")
            .setContentTitle("Project Raco Game Assistant is Running")
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
        
        // Ignore System UI (notification bar, volume panel, etc) and Android system dialogs
        if (packageName == "com.android.systemui" || packageName == "android") return
        
        // Ignore keyboards
        if (packageName.contains("inputmethod") || packageName.contains("keyboard")) return
        
        // Ignore floating windows and overlays (only process full-screen app changes)
        if (!event.isFullScreen) return

        if (packageName == currentForegroundPackage) return
        currentForegroundPackage = packageName
        
        val sharedPrefs = getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
        val addedGames = sharedPrefs.getStringSet("automation_games", emptySet()) ?: emptySet()
        val isGame = addedGames.contains(packageName)
        
        if (isGame && !isCurrentlyInGame) {
            isCurrentlyInGame = true
            lastGamePackage = packageName
            showForegroundNotification()
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val gameMode = sharedPrefs.getString("game_mode_$packageName", "none") ?: "none"
                    if (gameMode != "none") {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "cmd game mode $gameMode $packageName")).waitFor()
                    }
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco load $packageName")).waitFor()
                } catch (e: Exception) {}
            }
        } else if (!isGame && isCurrentlyInGame) {
            isCurrentlyInGame = false
            hideForegroundNotification()
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val unloadCmd = if (lastGamePackage != null) {
                        "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco unload $lastGamePackage"
                    } else {
                        "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco unload"
                    }
                    Runtime.getRuntime().exec(arrayOf("su", "-c", unloadCmd)).waitFor()
                } catch (e: Exception) {}
            }
        } else if (isGame && isCurrentlyInGame && packageName != lastGamePackage) {
            val oldGame = lastGamePackage
            lastGamePackage = packageName
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val unloadCmd = if (oldGame != null) {
                        "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco unload $oldGame"
                    } else {
                        "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco unload"
                    }
                    Runtime.getRuntime().exec(arrayOf("su", "-c", unloadCmd)).waitFor()
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco load $packageName")).waitFor()
                } catch (e: Exception) {}
            }
        }
    }

    override fun onInterrupt() {}
}
