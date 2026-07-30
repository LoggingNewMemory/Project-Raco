package com.kanagawa.yamada.project.raco.GameTools

import android.content.Context
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch
import kotlinx.coroutines.GlobalScope

object ScreenshotTool {
    fun execute(context: Context, onCollapse: () -> Unit): String? {
        // Hide the overlay first so it's not in the screenshot
        Handler(Looper.getMainLooper()).post { onCollapse() }

        // Launch an independent coroutine!
        // If we run this in the ToolItem's coroutine scope, the moment onCollapse()
        // hides the UI, the Compose scope is cancelled, killing the screenshot process.
        kotlinx.coroutines.GlobalScope.launch(Dispatchers.IO) {
            delay(300) // Wait for collapse animation

            val timestamp = java.text.SimpleDateFormat("yyyyMMdd_HHmmss", java.util.Locale.US).format(java.util.Date())
            val dir = "/sdcard/Pictures/ProjectRaco"
            val path = "$dir/Screenshot_$timestamp.png"
            
            try {
                val cmd = "mkdir -p $dir && screencap -p > $path && am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file://$path"
                val process = Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
                val exitCode = process.waitFor()
                
                withContext(Dispatchers.Main) {
                    val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
                    val tv = android.widget.TextView(context).apply {
                        text = if (exitCode == 0) "Screenshot Captured" else "Failed: Code $exitCode"
                        setTextColor(android.graphics.Color.WHITE)
                        textSize = 14f
                        val shape = android.graphics.drawable.GradientDrawable().apply {
                            cornerRadius = 50f
                            setColor(android.graphics.Color.parseColor("#DD333333"))
                        }
                        background = shape
                        setPadding(64, 32, 64, 32)
                        elevation = 10f
                    }
                    val params = android.view.WindowManager.LayoutParams(
                        android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                        android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else android.view.WindowManager.LayoutParams.TYPE_PHONE,
                        android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                        android.graphics.PixelFormat.TRANSLUCENT
                    ).apply {
                        gravity = android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL
                        y = 200
                        windowAnimations = android.R.style.Animation_Toast
                    }
                    
                    try {
                        windowManager.addView(tv, params)
                        Handler(Looper.getMainLooper()).postDelayed({
                            try { windowManager.removeView(tv) } catch(e: Exception) {}
                        }, 2000)
                    } catch (e: Exception) {}
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
                    val tv = android.widget.TextView(context).apply {
                        text = "Error: ${e.message}"
                        setTextColor(android.graphics.Color.WHITE)
                        textSize = 14f
                        val shape = android.graphics.drawable.GradientDrawable().apply {
                            cornerRadius = 50f
                            setColor(android.graphics.Color.parseColor("#DD333333"))
                        }
                        background = shape
                        setPadding(64, 32, 64, 32)
                        elevation = 10f
                    }
                    val params = android.view.WindowManager.LayoutParams(
                        android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                        android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else android.view.WindowManager.LayoutParams.TYPE_PHONE,
                        android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                        android.graphics.PixelFormat.TRANSLUCENT
                    ).apply {
                        gravity = android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL
                        y = 200
                        windowAnimations = android.R.style.Animation_Toast
                    }
                    
                    try {
                        windowManager.addView(tv, params)
                        Handler(Looper.getMainLooper()).postDelayed({
                            try { windowManager.removeView(tv) } catch(err: Exception) {}
                        }, 2000)
                    } catch (err: Exception) {}
                }
            }
        }
        
        return null // Return null immediately so the UI doesn't animate
    }
}
