package com.kanagawa.yamada.project.raco

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
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
