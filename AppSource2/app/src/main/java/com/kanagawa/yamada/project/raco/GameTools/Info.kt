package com.kanagawa.yamada.project.raco.GameTools

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BatteryFull
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.foundation.border
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

@Composable
fun InfoOverlayView(context: Context, currentPackage: String) {
    var currentTime by remember { mutableStateOf(java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault()).format(java.util.Date())) }
    var currentFps by remember { mutableStateOf(0) }
    var currentBattery by remember { mutableStateOf(100) }

    LaunchedEffect(currentPackage) {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
        var previousMaxTime = 0L
        var targetLayer = ""
        
        val process = Runtime.getRuntime().exec("su")
        val suOut = java.io.DataOutputStream(process.outputStream)
        val suIn = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
        
        fun runCmd(cmd: String): List<String> {
            try {
                suOut.writeBytes(cmd + "\n")
                suOut.writeBytes("echo '---RACO_END---'\n")
                suOut.flush()
                val lines = mutableListOf<String>()
                while (true) {
                    val line = suIn.readLine() ?: break
                    if (line == "---RACO_END---") break
                    lines.add(line)
                }
                return lines
            } catch(e: Exception) { return emptyList() }
        }

        try {
            runCmd("dumpsys SurfaceFlinger --timestats -clear -enable")
            
            while (true) {
                currentTime = java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault()).format(java.util.Date())
                currentBattery = bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
                
                // Calculate FPS matching Kaorios 1:1 logic
                val fps = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                    var calculatedFps = 0.0
                    try {
                        val timeStatsOutput = runCmd("dumpsys SurfaceFlinger --timestats -dump").joinToString("\n")
                        val matcher = java.util.regex.Pattern.compile("averageFPS\\s*=\\s*([0-9.]+)").matcher(timeStatsOutput)
                        if (matcher.find()) {
                            val fpsFloat = matcher.group(1)?.toFloatOrNull()
                            if (fpsFloat != null && fpsFloat > 0f) {
                                calculatedFps = fpsFloat.toDouble()
                                runCmd("dumpsys SurfaceFlinger --timestats -clear -enable")
                            }
                        }
    
                        if (calculatedFps <= 0.0) {
                            if (targetLayer.isEmpty()) {
                                val layers = runCmd("dumpsys SurfaceFlinger --list")
                                targetLayer = layers.firstOrNull { it.contains(currentPackage) && it.contains("SurfaceView") } 
                                    ?: layers.firstOrNull { it.contains(currentPackage) }
                                    ?: currentPackage
                            }
    
                            val lines = runCmd("dumpsys SurfaceFlinger --latency '$targetLayer'")
                            if (lines.size >= 2) {
                                var maxTime = Long.MIN_VALUE
                                var frameCount = 0
                                
                                for (i in 1 until lines.size) {
                                    val parts = lines[i].trim().split("\\s+".toRegex())
                                    if (parts.size >= 3) {
                                        val time = parts[1].toLongOrNull() ?: continue
                                        if (time <= 0L || time == Long.MAX_VALUE) continue
                                        
                                        if (time > previousMaxTime) {
                                            frameCount++
                                            if (time > maxTime) maxTime = time
                                        }
                                    }
                                }
                                
                                if (previousMaxTime > 0L && maxTime > previousMaxTime && frameCount > 0) {
                                    val timeDiffSec = (maxTime - previousMaxTime) / 1e9
                                    if (timeDiffSec > 0) {
                                        val currentCalc = frameCount / timeDiffSec
                                        if (currentCalc in 1.0..240.0) {
                                            calculatedFps = currentCalc
                                        }
                                    }
                                }
                                if (maxTime > previousMaxTime && maxTime != Long.MIN_VALUE) {
                                    previousMaxTime = maxTime
                                }
                            } else {
                                targetLayer = ""
                            }
                        }
                    } catch (e: Exception) {}
                    calculatedFps
                }
                if (fps > 0) {
                    currentFps = kotlin.math.round(fps).toInt()
                } else if (fps == 0.0 && previousMaxTime > 0L) {
                    currentFps = 0
                }
                
                delay(1000)
            }
        } finally {
            try {
                suOut.close()
                suIn.close()
                process.destroy()
            } catch(e: Exception) {}
        }
    }

    val sharedPrefs = remember { context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE) }
    var showTime by remember { mutableStateOf(sharedPrefs.getBoolean("overlay_show_time", true)) }
    var showFps by remember { mutableStateOf(sharedPrefs.getBoolean("overlay_show_fps", true)) }
    var showBattery by remember { mutableStateOf(sharedPrefs.getBoolean("overlay_show_battery", true)) }

    DisposableEffect(sharedPrefs) {
        val listener = android.content.SharedPreferences.OnSharedPreferenceChangeListener { prefs, key ->
            if (key == "overlay_show_time") showTime = prefs.getBoolean("overlay_show_time", true)
            if (key == "overlay_show_fps") showFps = prefs.getBoolean("overlay_show_fps", true)
            if (key == "overlay_show_battery") showBattery = prefs.getBoolean("overlay_show_battery", true)
        }
        sharedPrefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose {
            sharedPrefs.unregisterOnSharedPreferenceChangeListener(listener)
        }
    }

    if (showTime || showFps || showBattery) {
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(4.dp))
                .background(Color(0xFF1E1E1E).copy(alpha = 0.85f))
                .padding(horizontal = 12.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (showTime) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Schedule, contentDescription = "Time", tint = Color.LightGray, modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(currentTime, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            if (showFps) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Layers, contentDescription = "FPS", tint = Color.LightGray, modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("${currentFps}FPS", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            if (showBattery) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.BatteryFull, contentDescription = "Battery", tint = Color.LightGray, modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("$currentBattery%", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
fun InfoConfigView(
    onDismissRequest: () -> Unit,
    onDisableInfo: () -> Unit,
    sharedPrefs: android.content.SharedPreferences
) {
    var showTime by remember { mutableStateOf(sharedPrefs.getBoolean("overlay_show_time", true)) }
    var showFps by remember { mutableStateOf(sharedPrefs.getBoolean("overlay_show_fps", true)) }
    var showBattery by remember { mutableStateOf(sharedPrefs.getBoolean("overlay_show_battery", true)) }

    fun checkAndDisableAll(time: Boolean, fps: Boolean, battery: Boolean) {
        if (!time && !fps && !battery) {
            onDisableInfo()
            onDismissRequest()
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Sys Status Settings", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            IconButton(onClick = onDismissRequest, modifier = Modifier.size(24.dp)) {
                Icon(imageVector = Icons.Default.Close, contentDescription = "Close", tint = Color.Gray)
            }
        }
        
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text("Show Clock", modifier = Modifier.weight(1f), color = Color.White)
            Switch(checked = showTime, onCheckedChange = { 
                showTime = it
                sharedPrefs.edit().putBoolean("overlay_show_time", it).apply()
                checkAndDisableAll(it, showFps, showBattery)
            })
        }
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text("Show Battery", modifier = Modifier.weight(1f), color = Color.White)
            Switch(checked = showBattery, onCheckedChange = { 
                showBattery = it
                sharedPrefs.edit().putBoolean("overlay_show_battery", it).apply()
                checkAndDisableAll(showTime, showFps, it)
            })
        }
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                androidx.compose.foundation.layout.Box(
                    modifier = Modifier
                        .background(Color(0xFFFFB74D).copy(alpha = 0.2f), RoundedCornerShape(4.dp))
                        .border(1.dp, Color(0xFFFFB74D), RoundedCornerShape(4.dp))
                        .padding(horizontal = 4.dp, vertical = 2.dp)
                ) {
                    Text("BETA", color = Color(0xFFFFB74D), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.width(6.dp))
                Text("Show FPS", color = Color.White)
            }
            Switch(checked = showFps, onCheckedChange = { 
                showFps = it
                sharedPrefs.edit().putBoolean("overlay_show_fps", it).apply()
                checkAndDisableAll(showTime, it, showBattery)
            })
        }
    }
}
