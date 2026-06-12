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
            .setSmallIcon(android.R.drawable.ic_media_play) // Use built-in generic icon
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1001, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1001, notification)
        }
    }

    private fun startMonitoring() {
        serviceScope.launch {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            while (isActive) {
                delay(1500) // Poll every 1.5 seconds
                val time = System.currentTimeMillis()
                val events = usageStatsManager.queryEvents(time - 2000, time)
                val event = UsageEvents.Event()
                var currentForeground = lastForegroundApp
                
                while (events.hasNextEvent()) {
                    events.getNextEvent(event)
                    if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                        currentForeground = event.packageName
                    }
                }
                
                if (currentForeground != lastForegroundApp && currentForeground != "com.kanagawa.yamada.project.raco" && currentForeground != "com.android.systemui") {
                    val appList = GameManager.getAllInstalledApps(this@AutoGameMonitorService)
                    val addedGames = GameManager.getManuallyAddedGames(this@AutoGameMonitorService)
                    val hiddenGames = GameManager.getHiddenGames(this@AutoGameMonitorService)
                    
                    val isGame = appList.find { it.packageName == currentForeground }?.let {
                        (it.isSystemGame && it.packageName !in hiddenGames) || it.packageName in addedGames
                    } ?: false

                    if (isGame) {
                        // Detected a game launching!
                        onGameLaunched(currentForeground)
                    } else if (lastForegroundApp.isNotEmpty()) {
                        // Transitioned from a game to a non-game app
                        val wasGame = appList.find { it.packageName == lastForegroundApp }?.let {
                            (it.isSystemGame && it.packageName !in hiddenGames) || it.packageName in addedGames
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
        // Read raco_slingshot_prefs to determine if user has a global preferred perf mode
        val prefs = getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
        val mode = prefs.getString("global_perf_mode", "AWAKEN") ?: "AWAKEN"
        
        // Trigger Daemon via UNIX Socket
        triggerDaemonMode(mode, packageName)

        // Prevent launching duplicate overlays if the user just launched via Slingshot
        val lastPlayed = GameManager.getGameLastPlayed(this, packageName)
        if (System.currentTimeMillis() - lastPlayed < 10000) {
            return
        }
        
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
        // When game exits, revert to NORMAL mode
        triggerDaemonMode("NORMAL")
    }

    private fun triggerDaemonMode(mode: String, packageName: String? = null) {
        try {
            val socket = LocalSocket()
            val address = LocalSocketAddress("raco_gameservice", LocalSocketAddress.Namespace.ABSTRACT)
            socket.connect(address)
            val payload = if (packageName != null) "$mode:$packageName" else mode
            socket.outputStream.write(payload.toByteArray())
            socket.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
    }
}
