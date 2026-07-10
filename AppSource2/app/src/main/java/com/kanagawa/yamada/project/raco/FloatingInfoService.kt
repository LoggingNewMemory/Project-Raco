package com.kanagawa.yamada.project.raco

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.TrafficStats
import android.os.BatteryManager
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BatteryFull
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import kotlinx.coroutines.*
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.roundToInt

class FloatingInfoService : Service() {
    private var windowManager: WindowManager? = null
    private var composeView: ComposeView? = null
    private var lifecycleOwner: MyLifecycleOwner? = null

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    
    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())
    private var startTimeMillis = 0L

    companion object {
        var isRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        startTimeMillis = System.currentTimeMillis()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        lifecycleOwner = MyLifecycleOwner().apply {
            performRestore(null)
            handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        }

        val prefs = getSharedPreferences("RacoFloatingPrefs", Context.MODE_PRIVATE)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt("info_x", 100)
            y = prefs.getInt("info_y", 150)
        }

        composeView = ComposeView(this).apply {
            setContent {
                ScaleTabletUI {
                    InfoWidgetContent(startTimeMillis)
                }
            }
            setOnTouchListener { view, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        
                        val displayMetrics = context.resources.displayMetrics
                        val screenWidth = displayMetrics.widthPixels
                        val screenHeight = displayMetrics.heightPixels
                        
                        if (params.x < 0) params.x = 0
                        if (params.y < 0) params.y = 0
                        if (params.x > screenWidth - view.width) params.x = screenWidth - view.width
                        if (params.y > screenHeight - view.height) params.y = screenHeight - view.height

                        windowManager?.updateViewLayout(composeView, params)
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        getSharedPreferences("RacoFloatingPrefs", Context.MODE_PRIVATE)
                            .edit()
                            .putInt("info_x", params.x)
                            .putInt("info_y", params.y)
                            .apply()
                        true
                    }
                    else -> false
                }
            }
        }

        composeView?.setViewTreeLifecycleOwner(lifecycleOwner)
        composeView?.setViewTreeSavedStateRegistryOwner(lifecycleOwner)
        val viewModelStore = ViewModelStore()
        composeView?.setViewTreeViewModelStoreOwner(object : ViewModelStoreOwner {
            override val viewModelStore: ViewModelStore get() = viewModelStore
        })

        windowManager?.addView(composeView, params)
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        serviceScope.cancel()
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        composeView?.let { windowManager?.removeView(it) }
    }
}

@Composable
fun InfoWidgetContent(startTimeMillis: Long) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var currentTime by remember { mutableStateOf("") }
    var fps by remember { mutableStateOf(0) }
    var networkSpeed by remember { mutableStateOf("0.0 KB/s") }
    var batteryLevel by remember { mutableStateOf("0%") }

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
            var lastRxBytes = TrafficStats.getTotalRxBytes()
            var lastTxBytes = TrafficStats.getTotalTxBytes()
            // Hoisted outside the loop: getSystemService is an IPC call and never changes.
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager

            while (isActive) {
                // Time
                currentTime = sdf.format(Date())

                // Network
                val currentRx = TrafficStats.getTotalRxBytes()
                val currentTx = TrafficStats.getTotalTxBytes()
                val rxDiff = currentRx - lastRxBytes
                val txDiff = currentTx - lastTxBytes
                val totalBytesPerSec = rxDiff + txDiff

                var displaySpeed = totalBytesPerSec / 1024f
                var unit = "KB/s"
                if (displaySpeed > 1000f) {
                    displaySpeed /= 1024f
                    unit = "MB/s"
                }
                networkSpeed = String.format(Locale.US, "%.1f %s", displaySpeed, unit)

                lastRxBytes = currentRx
                lastTxBytes = currentTx

                // Battery
                val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                batteryLevel = "$level%"

                // FPS reading is now handled in a separate background coroutine

                delay(1000)
            }
        }
    }

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            var fpsProcess: Process? = null
            var lastPkg = ""
            var readerJob: Job? = null

            try {
                while (isActive) {
                    val pkg = AutoGameMonitorService.currentGamePackage
                    if (pkg != lastPkg || fpsProcess == null) {
                        readerJob?.cancel()
                        fpsProcess?.destroy()
                        try {
                            // Clean up any stray background instances first to avoid multiple writers
                            Runtime.getRuntime().exec(arrayOf("su", "-c", "pkill -f raco_gameservice.*--monitor-fps")).waitFor()
                            
                            val cmd = if (pkg.isNotEmpty()) {
                                arrayOf("su", "-c", "/data/adb/modules/ProjectRaco/CoreSys/raco_gameservice --monitor-fps $pkg")
                            } else {
                                arrayOf("su", "-c", "/data/adb/modules/ProjectRaco/CoreSys/raco_gameservice --monitor-fps \"\"")
                            }
                            fpsProcess = Runtime.getRuntime().exec(cmd)
                            lastPkg = pkg
                            
                            readerJob = launch(Dispatchers.IO) {
                                try {
                                    val reader = java.io.BufferedReader(java.io.InputStreamReader(fpsProcess!!.inputStream))
                                    var line: String?
                                    while (isActive) {
                                        line = reader.readLine()
                                        if (line == null) break
                                        val fpsVal = line.trim().toIntOrNull()
                                        if (fpsVal != null) {
                                            fps = fpsVal
                                        }
                                    }
                                } catch (e: Exception) {}
                            }
                        } catch (e: Exception) {
                            fpsProcess = null
                            delay(1000)
                            continue
                        }
                    }

                    try {
                        // Process Hold Check: Actively verify if the C Daemon was killed by the ROM
                        if (fpsProcess != null) {
                            try {
                                fpsProcess!!.exitValue()
                                // If this DOES NOT throw an exception, it means the process is DEAD.
                                // We set it to null so the loop above will instantly restart it.
                                fpsProcess = null
                            } catch (e: IllegalThreadStateException) {
                                // Process is still happily running (throws exception)
                            }
                        }
                        
                        delay(1000)
                    } catch (e: Exception) {
                        delay(1000)
                    }
                }
            } finally {
                // Ensure the FPS monitor process is always cleaned up on cancellation
                readerJob?.cancel()
                fpsProcess?.destroy()
                try {
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "pkill -f raco_gameservice.*--monitor-fps"))
                } catch (e: Exception) {}
            }
        }
    }

    Box(
        modifier = Modifier
            .background(Color(0xFF1E1E22).copy(alpha = 0.80f), RoundedCornerShape(8.dp))
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Time
            InfoItem(Icons.Filled.Schedule, currentTime, 48.dp)
            
            // FPS
            InfoItem(Icons.Filled.Speed, "${fps}FPS", 56.dp)
            
            // Network
            InfoItem(Icons.Filled.Language, networkSpeed, 68.dp)
            
            // Battery
            InfoItem(Icons.Filled.BatteryFull, batteryLevel, 44.dp)
        }
    }
}

@Composable
fun InfoItem(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String, width: androidx.compose.ui.unit.Dp) {
    val configuration = androidx.compose.ui.platform.LocalConfiguration.current
    val isTablet = configuration.smallestScreenWidthDp >= 600
    
    val iconSize = if (isTablet) 10.dp else 13.dp
    val spacerWidth = if (isTablet) 2.dp else 3.dp
    val fontSize = if (isTablet) 7.sp else 11.sp

    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.width(width)) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.8f),
            modifier = Modifier.size(iconSize)
        )
        Spacer(modifier = Modifier.width(spacerWidth))
        Text(
            text = text,
            color = Color.White,
            fontSize = fontSize,
            fontWeight = FontWeight.Medium,
            maxLines = 1
        )
    }
}
