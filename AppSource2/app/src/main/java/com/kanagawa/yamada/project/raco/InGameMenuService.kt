package com.kanagawa.yamada.project.raco

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class InGameMenuService : Service() {
    companion object {
        var isRunning = false
    }
    private var windowManager: WindowManager? = null
    private var mainComposeView: ComposeView? = null
    private var leftTriggerView: ComposeView? = null
    private var rightTriggerView: ComposeView? = null
    private var lifecycleOwner: MyLifecycleOwner? = null

    private var isLeftOpen by mutableStateOf(false)
    private var isRightOpen by mutableStateOf(false)
    
    // We pass a callback to RacoOverlay so it can update its own internal state to trigger the animation.
    private var openLeftMenu: (() -> Unit)? = null
    private var openRightMenu: (() -> Unit)? = null

    private var targetPackageName by mutableStateOf<String?>(null)
    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private var isCheckerRunning = false

    override fun onBind(intent: Intent?): IBinder? = null

    private fun dpToPx(dp: Int): Int = (dp * resources.displayMetrics.density).toInt()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val newTarget = intent?.getStringExtra("package_name")
        if (newTarget != null) {
            targetPackageName = newTarget
        }
        return START_NOT_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        promoteToForeground()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        lifecycleOwner = MyLifecycleOwner().apply {
            performRestore(null)
            handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        }
        
        setupMainOverlay()
        setupTriggers()
        
        val prefs = getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
        if (prefs.getBoolean("is_info_enabled", false)) {
            startService(Intent(this, FloatingInfoService::class.java))
        }
        if (prefs.getBoolean("is_rotation_locked", false)) {
            startService(Intent(this, RotationLockService::class.java))
        }
        val targetRate = prefs.getFloat("override_refresh_rate", 0f)
        if (targetRate > 0f) {
            val refreshIntent = Intent(this, RefreshRateService::class.java)
            refreshIntent.putExtra("refresh_rate", targetRate)
            startService(refreshIntent)
        }
        // Tool restoration (Crosshair, AuxLine, Ayunda) has been moved to RacoToolHandler 
        // to be triggered after the entrance animation finishes, avoiding overlaps.
        
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    private fun setupMainOverlay() {
        mainComposeView = ComposeView(this).apply {
            setContent {
                ScaleTabletUI {
                    RacoGameOverlay(
                        targetPackageName = targetPackageName,
                        onStateBind = { openLeft, openRight ->
                            openLeftMenu = openLeft
                            openRightMenu = openRight
                        },
                        onClose = {
                            isLeftOpen = false
                            isRightOpen = false
                            updateMainOverlayTouchable()
                        }
                    )
                }
            }
        }

        setupViewTree(mainComposeView!!)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE, // Initially NOT touchable!
            PixelFormat.TRANSLUCENT
        )
        params.alpha = 0.8f // Fix for Android 12 untrusted touches

        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        windowManager?.addView(mainComposeView, params)
        
        mainComposeView?.viewTreeObserver?.addOnWindowFocusChangeListener { hasFocus ->
            if (!hasFocus && (isLeftOpen || isRightOpen)) {
                isLeftOpen = false
                isRightOpen = false
                updateMainOverlayTouchable()
            }
        }
    }

    private fun setupTriggers() {
        // Left Trigger
        leftTriggerView = ComposeView(this).apply {
            setContent {
                ScaleTabletUI {
                    Box(modifier = Modifier.fillMaxSize().background(Color.Transparent).pointerInput(Unit) {
                        detectHorizontalDragGestures { _, dragAmount ->
                            if (dragAmount > 10 && !isLeftOpen && !isRightOpen) {
                                isLeftOpen = true
                                isRightOpen = true
                                updateMainOverlayTouchable()
                                openLeftMenu?.invoke()
                                openRightMenu?.invoke()
                            }
                        }
                    }) {
                        if (!isLeftOpen && !isRightOpen) {
                            Box(modifier = Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.CenterStart) {
                                Box(modifier = Modifier.width(4.dp).height(64.dp).background(Color.White.copy(alpha=0.4f), RoundedCornerShape(2.dp)))
                            }
                        }
                    }
                }
            }
        }
        setupViewTree(leftTriggerView!!)
        
        val leftParams = WindowManager.LayoutParams(
            dpToPx(16), // width
            dpToPx(150), // height
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        leftParams.alpha = 0.8f // Fix for XOS 12 / Android 12 touch block
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            leftParams.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        leftParams.gravity = Gravity.TOP or Gravity.START
        leftParams.y = dpToPx(16)
        windowManager?.addView(leftTriggerView, leftParams)

        // Right Trigger
        rightTriggerView = ComposeView(this).apply {
            setContent {
                ScaleTabletUI {
                    Box(modifier = Modifier.fillMaxSize().background(Color.Transparent).pointerInput(Unit) {
                        detectHorizontalDragGestures { _, dragAmount ->
                            if (dragAmount < -10 && !isLeftOpen && !isRightOpen) {
                                isLeftOpen = true
                                isRightOpen = true
                                updateMainOverlayTouchable()
                                openLeftMenu?.invoke()
                                openRightMenu?.invoke()
                            }
                        }
                    }) {
                        if (!isLeftOpen && !isRightOpen) {
                            Box(modifier = Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.CenterEnd) {
                                Box(modifier = Modifier.width(4.dp).height(64.dp).background(Color.White.copy(alpha=0.4f), RoundedCornerShape(2.dp)))
                            }
                        }
                    }
                }
            }
        }
        setupViewTree(rightTriggerView!!)
        
        val rightParams = WindowManager.LayoutParams(
            dpToPx(16), // width
            dpToPx(150), // height
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        rightParams.alpha = 0.8f // Fix for XOS 12 / Android 12 touch block
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            rightParams.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        rightParams.gravity = Gravity.TOP or Gravity.END
        rightParams.y = dpToPx(16)
        windowManager?.addView(rightTriggerView, rightParams)
    }
    
    private fun updateMainOverlayTouchable() {
        val params = mainComposeView?.layoutParams as? WindowManager.LayoutParams ?: return
        if (isLeftOpen || isRightOpen) {
            // Remove FLAG_NOT_TOUCHABLE so it can receive touches (clicks, close swipes)
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
            params.alpha = 1.0f // Fully visible when open
        } else {
            // Add FLAG_NOT_TOUCHABLE so game receives touches
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
            params.alpha = 0.8f // <= 0.8f avoids Android 12 untrusted touch blocking
        }
        windowManager?.updateViewLayout(mainComposeView, params)
    }

    private fun setupViewTree(view: ComposeView) {
        view.setViewTreeLifecycleOwner(lifecycleOwner)
        view.setViewTreeSavedStateRegistryOwner(lifecycleOwner)
        val viewModelStore = ViewModelStore()
        view.setViewTreeViewModelStoreOwner(object : ViewModelStoreOwner {
            override val viewModelStore: ViewModelStore get() = viewModelStore
        })
    }


    private fun promoteToForeground() {
        val channelId = "ingame_overlay_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "In-Game Overlay", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Keeps the game overlay alive during gaming sessions"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification = androidx.core.app.NotificationCompat.Builder(this, channelId)
            .setContentTitle("Project Raco")
            .setContentText("In-Game Overlay Active")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_LOW)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1002, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1002, notification)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopService(Intent(this, FloatingInfoService::class.java))
        stopService(Intent(this, RotationLockService::class.java))
        stopService(Intent(this, RefreshRateService::class.java))
        stopService(Intent(this, com.kanagawa.yamada.project.raco.RacoGameTools.GameCrosshairService::class.java))
        stopService(Intent(this, com.kanagawa.yamada.project.raco.RacoGameTools.GameAuxLineService::class.java))
        
        val prefs = getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
        if (prefs.getBoolean("is_ayunda_enabled", false)) {
            Thread {
                try {
                    val cmd = "settings put secure accessibility_display_inversion_enabled 0; " +
                              "settings put secure accessibility_display_daltonizer_enabled 0; " +
                              "service call SurfaceFlinger 1022 f 1.0; " +
                              "service call SurfaceFlinger 1015 i32 0"
                    Runtime.getRuntime().exec(arrayOf("su", "-c", cmd)).waitFor()
                } catch (e: Exception) {}
            }.start()
        }
        
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        mainComposeView?.let { windowManager?.removeView(it) }
        leftTriggerView?.let { windowManager?.removeView(it) }
        rightTriggerView?.let { windowManager?.removeView(it) }
    }
}
