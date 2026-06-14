package com.kanagawa.yamada.project.raco

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.View
import android.view.WindowManager
import kotlin.math.abs

class RefreshRateService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: View
    private lateinit var layoutParams: WindowManager.LayoutParams
    private var isAdded = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        overlayView = View(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val targetRate = intent?.getFloatExtra("refresh_rate", 0f) ?: 0f
        
        if (targetRate > 0f) {
            if (!::layoutParams.isInitialized) {
                layoutParams = WindowManager.LayoutParams(
                    0, 0,
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                    PixelFormat.TRANSPARENT
                )
            }

            val modes = windowManager.defaultDisplay.supportedModes
            val targetMode = modes.minByOrNull { abs(it.refreshRate - targetRate) }
            
            if (targetMode != null) {
                layoutParams.preferredDisplayModeId = targetMode.modeId
            }

            try {
                if (isAdded) {
                    windowManager.updateViewLayout(overlayView, layoutParams)
                } else {
                    windowManager.addView(overlayView, layoutParams)
                    isAdded = true
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        } else {
            stopSelf()
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (isAdded && ::overlayView.isInitialized) {
                if (::layoutParams.isInitialized) {
                    layoutParams.preferredDisplayModeId = 0
                    windowManager.updateViewLayout(overlayView, layoutParams)
                }
                windowManager.removeView(overlayView)
                isAdded = false
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
