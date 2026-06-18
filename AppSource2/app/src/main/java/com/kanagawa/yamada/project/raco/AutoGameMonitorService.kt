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
import kotlinx.coroutines.sync.withLock

class AutoGameMonitorService : Service() {
    companion object {
        var currentGamePackage = ""
    }
    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private var lastForegroundApp: String = ""

    // Cache the app/game list — only refresh every 60s, not on every poll tick.
    // Loading icons for every installed app on every 1.5s poll was extremely heavy
    // and could silently crash/freeze the monitoring coroutine.
    private var cachedAppList: List<AppInfo> = emptyList()
    private var cachedAddedGames: Set<String> = emptySet()
    private var cachedHiddenGames: Set<String> = emptySet()
    private var isCheckerRunning = false
    private var exitDebounceJob: kotlinx.coroutines.Job? = null
    private val stateMutex = kotlinx.coroutines.sync.Mutex()
    private var isGameForeground = false
    private var lastCacheRefresh = 0L
    private val CACHE_TTL_MS = 60_000L
    
    // Tracks the last known PIDs of games. Used to distinguish resume vs fresh launch.
    private val savedGamePids = mutableMapOf<String, Set<String>>()

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
        
        startForegroundAppChecker()
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

    private fun startForegroundAppChecker() {
        isCheckerRunning = true
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val event = UsageEvents.Event()
        var lastForegroundApp = ""

        serviceScope.launch {
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
                    refreshCacheIfNeeded(time)

                    val isGame = cachedAppList.find { it.packageName == currentForeground }?.let {
                        (it.isSystemGame && it.packageName !in cachedHiddenGames) || it.packageName in cachedAddedGames
                    } ?: false

                    if (isGame) {
                        stateMutex.withLock {
                            onGameLaunched(currentForeground)
                        }
                    } else if (lastForegroundApp.isNotEmpty()) {
                        val wasGame = cachedAppList.find { it.packageName == lastForegroundApp }?.let {
                            (it.isSystemGame && it.packageName !in cachedHiddenGames) || it.packageName in cachedAddedGames
                        } ?: false

                        if (wasGame) {
                            stateMutex.withLock {
                                onGameExited(lastForegroundApp)
                            }
                        }
                    }
                } else if (isGameForeground) {
                    // Watchdog: If the game is still foreground but the background overlays were killed by Android, revive them.
                    val prefs = getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
                    
                    if (!InGameMenuService.isRunning) {
                        val inGameIntent = Intent(this@AutoGameMonitorService, InGameMenuService::class.java).apply {
                            putExtra("package_name", currentForeground)
                        }
                        startService(inGameIntent)
                    }
                    
                    if (prefs.getBoolean("is_info_enabled", false) && !FloatingInfoService.isRunning) {
                        startService(Intent(this@AutoGameMonitorService, FloatingInfoService::class.java))
                    }
                }
                lastForegroundApp = currentForeground
            }
        }
    }

    private fun onGameLaunched(packageName: String) {
        isGameForeground = true
        currentGamePackage = packageName
        exitDebounceJob?.cancel()
        val prefs = getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
        val mode = prefs.getString("global_perf_mode", "AWAKEN") ?: "AWAKEN"

        // (Duplicate protection removed because it breaks quick-resumes)

        // Trigger mode switch
        RacoDaemon.sendMode(mode, packageName)
        
        // Update the timestamp for manual launches
        GameManager.setGameLastPlayed(this, packageName, System.currentTimeMillis())

        // Check if the game process actually survived in the background by querying the C daemon
        val currentPids = getGamePids(packageName)
        val lastPids = savedGamePids[packageName] ?: emptySet()
        
        // If ANY of the current PIDs match ANY of the PIDs we saved when it last exited, it's a true Resume!
        val isResume = currentPids.intersect(lastPids).isNotEmpty()
        
        // Update the saved PIDs for the next time
        savedGamePids[packageName] = currentPids

        if (isResume) {
            // Restore the tools immediately without playing the intro animation
            com.kanagawa.yamada.project.raco.RacoGameTools.RacoToolHandler.restoreSavedTools(this)
        } else {
            // Fresh launch: Delay any toasts and trigger entrance animation overlay
            prefs.edit().putLong("entrance_anim_playing_until", System.currentTimeMillis() + 4500).apply()
            val overlayIntent = Intent(this, GameOverlayService::class.java)
            startService(overlayIntent)
        }
        
        // Trigger the Side Triggers (In-Game Menu)
        val inGameIntent = Intent(this, InGameMenuService::class.java).apply {
            putExtra("package_name", packageName)
        }
        startService(inGameIntent)
    }

    private fun onGameExited(packageName: String) {
        isGameForeground = false
        exitDebounceJob?.cancel()
        exitDebounceJob = serviceScope.launch {
            kotlinx.coroutines.delay(1500) // Wait 1.5s to ensure they didn't just quick-switch or open an ad
            stateMutex.withLock {
                if (isGameForeground) return@launch // Abort if game was relaunched while waiting
                currentGamePackage = ""
                RacoDaemon.sendMode("NORMAL")
                // Master service now explicitly kills the menu to prevent desyncs
                stopService(Intent(this@AutoGameMonitorService, InGameMenuService::class.java))
            }
        }
    }

    private fun getGamePids(packageName: String): Set<String> {
        try {
            val address = LocalSocketAddress("raco_gameservice", LocalSocketAddress.Namespace.ABSTRACT)
            val socket = LocalSocket()
            socket.connect(address)
            socket.soTimeout = 1000
            
            socket.outputStream.write("GET_PID:$packageName".toByteArray())
            socket.outputStream.flush()
            
            val buffer = ByteArray(512)
            val bytesRead = socket.inputStream.read(buffer)
            socket.close()
            
            if (bytesRead > 0) {
                val str = String(buffer, 0, bytesRead).trim()
                if (str.isNotEmpty() && str != "-1") {
                    return str.split(" ").toSet()
                }
            }
        } catch (e: Exception) {
            // Ignore
        }
        return emptySet()
    }

    private fun getTopAppFromDaemon(): String {
        try {
            val address = LocalSocketAddress("raco_gameservice", LocalSocketAddress.Namespace.ABSTRACT)
            val socket = LocalSocket()
            socket.connect(address)
            socket.soTimeout = 1000
            
            socket.outputStream.write("GET_TOP_APP".toByteArray())
            socket.outputStream.flush()
            
            val buffer = ByteArray(1024)
            val bytesRead = socket.inputStream.read(buffer)
            socket.close()
            
            if (bytesRead > 0) {
                return String(buffer, 0, bytesRead).trim()
            }
        } catch (e: Exception) {
            // Ignore
        }
        return ""
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        try { unregisterReceiver(toastReceiver) } catch (_: Exception) {}
    }
}
