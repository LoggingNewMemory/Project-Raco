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
                val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                batteryLevel = "$level%"

                // FPS (Fetch real hardware FPS from raco_gameservice daemon)
                try {
                    val socket = android.net.LocalSocket()
                    val address = android.net.LocalSocketAddress("raco_gameservice", android.net.LocalSocketAddress.Namespace.ABSTRACT)
                    socket.connect(address)

                    val payload = "GET_FPS:"
                    socket.outputStream.write(payload.toByteArray())

                    val buffer = ByteArray(16)
                    val bytesRead = socket.inputStream.read(buffer)
                    if (bytesRead > 0) {
                        val fpsStr = String(buffer, 0, bytesRead).trim()
                        val fpsVal = fpsStr.toIntOrNull()
                        if (fpsVal != null) {
                            fps = fpsVal
                        }
                    }
                    socket.close()
                } catch (e: Exception) {
                    // Ignore
                }

                delay(1000)
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
