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
        return super.onStartCommand(intent, flags, startId)
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
            var fpsReader: java.io.BufferedReader? = null
            var daemonStarted = false
            
            var lastHwFrames = -1L
            var lastLayerFrames = mutableMapOf<String, Long>()
            var lastSampleTime = -1L

            try {
                while (isActive) {
                    var daemonFps = -1
                    
                    // 1. Try RacoFpsDaemon (Android 12+ TaskFpsCallback)
                    try {
                        val socket = android.net.LocalSocket()
                        val address = android.net.LocalSocketAddress("raco_fps_daemon", android.net.LocalSocketAddress.Namespace.ABSTRACT)
                        socket.connect(address)

                        val payload = "GET_FPS"
                        socket.outputStream.write(payload.toByteArray())

                        val buffer = ByteArray(16)
                        val bytesRead = socket.inputStream.read(buffer)
                        if (bytesRead > 0) {
                            val fpsStr = String(buffer, 0, bytesRead).trim()
                            val fpsVal = fpsStr.toIntOrNull()
                            if (fpsVal != null && fpsVal > 0) {
                                daemonFps = fpsVal
                            }
                        }
                        socket.close()
                    } catch (e: Exception) {
                        if (android.os.Build.VERSION.SDK_INT >= 31 && !daemonStarted) {
                            try {
                                Runtime.getRuntime().exec(arrayOf("su", "-c", "CLASSPATH=/data/adb/modules/ProjectRaco/CoreSys/raco_fps.dex app_process / com.raco.RacoFpsDaemon &"))
                                daemonStarted = true
                            } catch (ex: Exception) {}
                        }
                    }

                    if (daemonFps != -1) {
                        fps = daemonFps
                        
                        fpsProcess?.destroy()
                        fpsProcess = null
                        fpsReader = null
                        
                        delay(1000)
                        continue
                    }

                    // 2. Fallback to robust su script
                    if (fpsProcess == null) {
                        try {
                            val script = """
                                while true; do
                                    echo "TIME:${'$'}(cat /proc/uptime | awk '{printf "%d", ${'$'}1 * 1000}')"
                                    service call SurfaceFlinger 1013 2>/dev/null
                                    
                                    pkg=${'$'}(dumpsys window 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp' | grep -Eo '[a-zA-Z0-9_.]+/[a-zA-Z0-9_.]+' | cut -d/ -f1 | head -n1)
                                    if [ -z "${'$'}pkg" ]; then pkg="SurfaceView"; fi
                                    
                                    dumpsys SurfaceFlinger --list 2>/dev/null | grep -i "${'$'}pkg" | while read -r layer; do
                                        dumpsys SurfaceFlinger --latency "${'$'}layer" 2>/dev/null | awk '
                                        NR>1 {
                                            if (NF>=2) {
                                                t = ${'$'}2;
                                                if (t != 0 && t != 9223372036854775807) {
                                                    ts[count++] = t;
                                                    if (t > latest) latest = t;
                                                }
                                            }
                                        }
                                        END {
                                            if (count > 0 && latest > 0) {
                                                cutoff = latest - 1000000000;
                                                fps = 0;
                                                for (i=0; i<count; i++) {
                                                    if (ts[i] > cutoff) fps++;
                                                }
                                                print "LATENCY_FPS:" fps;
                                            }
                                        }'
                                    done
                                    
                                    dumpsys SurfaceFlinger 2>/dev/null | grep -iE 'layer|surface|frame-counter=|flips='
                                    echo "---"
                                    sleep 1
                                done
                            """.trimIndent()
                            fpsProcess = Runtime.getRuntime().exec(arrayOf("su", "-c", script))
                            fpsReader = java.io.BufferedReader(java.io.InputStreamReader(fpsProcess!!.inputStream))
                            
                            lastHwFrames = -1L
                            lastLayerFrames.clear()
                            lastSampleTime = -1L
                        } catch (e: Exception) {
                            fpsProcess = null
                            fpsReader = null
                            delay(1000)
                            continue
                        }
                    }

                    try {
                        var hwFrames = -1L
                        val layerFrames = mutableMapOf<String, Long>()
                        var latencyFps = -1
                        var sampleTime = -1L
                        var line: String? = null
                        var currentLayerName = ""
                        var layerIndex = 0

                        while (isActive) {
                            line = fpsReader?.readLine()
                            if (line == null || line == "---") {
                                break
                            }

                            if (line.startsWith("TIME:")) {
                                sampleTime = line.substring(5).toLongOrNull() ?: -1L
                            } else if (line.startsWith("LATENCY_FPS:")) {
                                val f = line.substring(12).toIntOrNull() ?: -1
                                if (f > latencyFps) latencyFps = f
                            } else if (line.contains("Parcel(")) {
                                val hexes = """([0-9a-fA-F]{8})""".toRegex().findAll(line).map { it.groupValues[1] }.toList()
                                var maxVal = -1L
                                for (i in 1 until hexes.size) {
                                    val v = hexes[i].toLongOrNull(16) ?: -1L
                                    if (v > maxVal) maxVal = v
                                }
                                if (maxVal != -1L) {
                                    hwFrames = maxVal
                                }
                            } else if (line.contains("layer", ignoreCase = true) || line.contains("surface", ignoreCase = true)) {
                                currentLayerName = line.trim()
                                layerIndex = 0
                            } else if (line.contains("frame-counter=") || line.contains("flips=")) {
                                val match = """(?:frame-counter=|flips=)\s*([0-9]+)""".toRegex().find(line)
                                if (match != null) {
                                    val key = "$currentLayerName-$layerIndex"
                                    layerFrames[key] = match.groupValues[1].toLong()
                                    layerIndex++
                                }
                            }
                        }

                        if (line == null) {
                            fpsProcess?.destroy()
                            fpsProcess = null
                            delay(1000)
                            continue
                        }

                        if (sampleTime != -1L && lastSampleTime != -1L) {
                            val timeDiff = sampleTime - lastSampleTime
                            if (timeDiff > 0) {
                                var newFps = 0
                                
                                if (latencyFps > 0) {
                                    newFps = latencyFps
                                }

                                if (hwFrames > 0L) {
                                    if (lastHwFrames > 0 && hwFrames >= lastHwFrames) {
                                        val f = ((hwFrames - lastHwFrames) * 1000f / timeDiff).toInt()
                                        if (f > newFps) newFps = f
                                    }
                                    lastHwFrames = hwFrames
                                }

                                if (layerFrames.isNotEmpty()) {
                                    for ((key, cur) in layerFrames) {
                                        val last = lastLayerFrames[key] ?: 0L
                                        if (last > 0 && cur >= last) {
                                            val f = ((cur - last) * 1000f / timeDiff).toInt()
                                            if (f > newFps) newFps = f
                                        }
                                    }
                                    lastLayerFrames.clear()
                                    lastLayerFrames.putAll(layerFrames)
                                }

                                if (newFps > 1) newFps -= 1
                                if (newFps > 144) newFps = 144
                                if (newFps < 0) newFps = 0

                                fps = newFps
                            }
                        } else if (sampleTime != -1L) {
                            if (hwFrames > 0L) lastHwFrames = hwFrames
                            if (layerFrames.isNotEmpty()) {
                                lastLayerFrames.clear()
                                lastLayerFrames.putAll(layerFrames)
                            }
                        }
                        
                        if (sampleTime != -1L) {
                            lastSampleTime = sampleTime
                        }
                    } catch (e: Exception) {
                        fpsProcess?.destroy()
                        fpsProcess = null
                        delay(1000)
                    }
                }
            } finally {
                fpsProcess?.destroy()
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
