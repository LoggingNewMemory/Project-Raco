package com.kyroos.app.engine

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.TextView
import com.kyroos.app.utils.ShellUtils
import kotlinx.coroutines.*

class FpsService : Service() {

    companion object {
        var isRunning = false
        const val UPDATE_INTERVAL_MS = 1000L
    }

    private lateinit var windowManager: WindowManager
    private lateinit var fpsView: TextView
    private var job: Job? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        setupFpsOverlay()
        startFpsMonitoring()
    }

    private fun startFpsMonitoring() {
        job = scope.launch {
            var lastFrameCount = fetchTotalFrames()
            var lastUpdateTime = System.currentTimeMillis()

            while (isActive) {
                delay(UPDATE_INTERVAL_MS)
                
                val currentTime = System.currentTimeMillis()
                val timeDiff = currentTime - lastUpdateTime
                val currentFrameCount = fetchTotalFrames()
                
                var fps = 0
                
                if (currentFrameCount > lastFrameCount && lastFrameCount > 0) {
                    val frameDiff = currentFrameCount - lastFrameCount
                    fps = ((frameDiff * 1000f) / timeDiff).toInt()
                    if (fps > 1) fps -= 1
                }
                
                if (fps > 144) fps = 144
                if (fps < 0) fps = 0

                withContext(Dispatchers.Main) {
                    fpsView.text = " $fps "
                }

                lastFrameCount = currentFrameCount
                lastUpdateTime = currentTime
            }
        }
    }

    private suspend fun fetchTotalFrames(): Long {
        return try {
            val dump = ShellUtils.execShizuku("dumpsys SurfaceFlinger 2>/dev/null | grep -E -m 1 'frame-counter=|flips='")
            val match = """(?:frame-counter=|flips=)\s*([0-9]+)""".toRegex().find(dump)
            
            if (match != null) {
                return match.groupValues[1].toLong()
            }

            val res = ShellUtils.execShizuku("service call SurfaceFlinger 1013 2>/dev/null")
            val hexMatch = """Parcel\([^\s]+\s+([0-9a-fA-F]+)""".toRegex().find(res)
            return hexMatch?.groupValues?.getOrNull(1)?.toLongOrNull(16) ?: 0L

        } catch (e: Exception) {
            0L
        }
    }

    private fun setupFpsOverlay() {
        fpsView = TextView(this).apply {
            text = " -- "
            textSize = 14f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            setPadding(28, 14, 28, 14)
            elevation = 4f

            // Warna mengikuti tema aplikasi
            setTextColor(Color.WHITE)
            
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 16f
                setColor(Color.parseColor("#CC000000")) // Semi-transparent black
            }
        }

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 40
            y = 100
        }

        // Drag functionality
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        fpsView.setOnTouchListener { _, event ->
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
                    windowManager.updateViewLayout(fpsView, params)
                    true
                }
                else -> false
            }
        }

        windowManager.addView(fpsView, params)
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        job?.cancel()
        scope.cancel()
        
        if (::fpsView.isInitialized) {
            windowManager.removeView(fpsView)
        }
    }
}
