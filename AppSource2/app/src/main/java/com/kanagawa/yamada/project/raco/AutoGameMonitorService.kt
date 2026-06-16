package com.kanagawa.yamada.project.raco

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.LocalSocket
import android.net.LocalSocketAddress
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*

class AutoGameMonitorService : Service() {
    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private var lastForegroundApp: String = ""

    // Cache the app/game list — only refresh every 60s, not on every poll tick.
    // Loading icons for every installed app on every 1.5s poll was extremely heavy
    // and could silently crash/freeze the monitoring coroutine.
    private var cachedAppList: List<AppInfo> = emptyList()
    private var cachedAddedGames: Set<String> = emptySet()
    private var cachedHiddenGames: Set<String> = emptySet()
    private var lastCacheRefresh = 0L
    private val CACHE_TTL_MS = 60_000L

    override fun onBind(intent: Intent?): IBinder? = null
    private val toastReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == "com.kanagawa.yamada.project.raco.SHOW_TOAST") {
                val msg = intent.getStringExtra("msg")
                if (msg != null) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        android.widget.Toast.makeText(context, msg, android.widget.Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForegroundService()
        
        val filter = android.content.IntentFilter("com.kanagawa.yamada.project.raco.SHOW_TOAST")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(toastReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(toastReceiver, filter)
        }
        
        startMonitoring()
    }

    private fun startForegroundService() {
        val channelId = "game_monitor_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Game Monitor Service", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Project Raco")
            .setContentText("Game Monitoring is Active")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1001, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1001, notification)
        }
    }

    // Accept the already-computed `now` timestamp from the caller to avoid a
    // redundant System.currentTimeMillis() call on every foreground change check.
    // Uses getAllInstalledAppsLite() — skips icon loading entirely since the
    // monitoring path only ever needs packageName + isSystemGame.
    private suspend fun refreshCacheIfNeeded(now: Long) {
        if (now - lastCacheRefresh > CACHE_TTL_MS) {
            cachedAppList = GameManager.getAllInstalledAppsLite(this@AutoGameMonitorService)
            cachedAddedGames = GameManager.getManuallyAddedGames(this@AutoGameMonitorService)
            cachedHiddenGames = GameManager.getHiddenGames(this@AutoGameMonitorService)
            lastCacheRefresh = now
        }
    }

    private fun startMonitoring() {
        serviceScope.launch {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            // Allocate once — reused every poll tick to avoid GC pressure on a tight 1.5s loop.
            val event = UsageEvents.Event()
            while (isActive) {
                delay(1500) // Poll every 1.5 seconds
                val time = System.currentTimeMillis()
                val events = usageStatsManager.queryEvents(time - 2000, time)
                var currentForeground = lastForegroundApp

                while (events.hasNextEvent()) {
                    events.getNextEvent(event)
                    if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                        val pkg = event.packageName
                        val isIgnored = pkg == "android" ||
                                        pkg == "com.android.systemui" ||
                                        pkg == "com.kanagawa.yamada.project.raco" ||
                                        pkg.contains("permission", ignoreCase = true) ||
                                        pkg.contains("installer", ignoreCase = true) ||
                                        pkg.contains("securitycenter", ignoreCase = true) ||
                                        pkg.contains("safecenter", ignoreCase = true)

                        if (!isIgnored) {
                            currentForeground = pkg
                        }
                    }
                }

                if (currentForeground != lastForegroundApp) {
                    // Refresh the game list cache (at most once per minute).
                    // Pass the already-computed timestamp so refreshCacheIfNeeded
                    // doesn't call System.currentTimeMillis() a second time.
                    refreshCacheIfNeeded(time)

                    val isGame = cachedAppList.find { it.packageName == currentForeground }?.let {
                        (it.isSystemGame && it.packageName !in cachedHiddenGames) || it.packageName in cachedAddedGames
                    } ?: false

                    if (isGame) {
                        onGameLaunched(currentForeground)
                    } else if (lastForegroundApp.isNotEmpty()) {
                        val wasGame = cachedAppList.find { it.packageName == lastForegroundApp }?.let {
                            (it.isSystemGame && it.packageName !in cachedHiddenGames) || it.packageName in cachedAddedGames
                        } ?: false

                        if (wasGame) {
                            onGameExited(lastForegroundApp)
                        }
                    }
                }
                lastForegroundApp = currentForeground
            }
        }
    }

    private fun onGameLaunched(packageName: String) {
        val prefs = getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
        val mode = prefs.getString("global_perf_mode", "AWAKEN") ?: "AWAKEN"
        
        // Delay any toasts until EntranceAnim finishes (~4.5s)
        prefs.edit().putLong("entrance_anim_playing_until", System.currentTimeMillis() + 4500).apply()

        // Prevent launching duplicate overlays if the user just launched via Slingshot
        val lastPlayed = GameManager.getGameLastPlayed(this, packageName)
        if (System.currentTimeMillis() - lastPlayed < 10000) {
            return
        }

        // Trigger mode switch
        RacoDaemon.sendMode(mode, packageName)
        
        // Update the timestamp for manual launches
        GameManager.setGameLastPlayed(this, packageName, System.currentTimeMillis())

        // Trigger entrance animation overlay
        val overlayIntent = Intent(this, GameOverlayService::class.java)
        startService(overlayIntent)
        
        // Trigger the Side Triggers (In-Game Menu)
        val inGameIntent = Intent(this, InGameMenuService::class.java).apply {
            putExtra("package_name", packageName)
        }
        startService(inGameIntent)
    }

    private fun onGameExited(packageName: String) {
        RacoDaemon.sendMode("NORMAL")
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        try { unregisterReceiver(toastReceiver) } catch (_: Exception) {}
    }
}
