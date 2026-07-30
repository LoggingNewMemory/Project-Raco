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
                    if (exitCode == 0) {
                        android.widget.Toast.makeText(context, "Screenshot Captured!", android.widget.Toast.LENGTH_SHORT).show()
                    } else {
                        android.widget.Toast.makeText(context, "Failed: Code $exitCode", android.widget.Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    android.widget.Toast.makeText(context, "Error: ${e.message}", android.widget.Toast.LENGTH_SHORT).show()
                }
            }
        }
        
        return null // Return null immediately so the UI doesn't animate
    }
}
