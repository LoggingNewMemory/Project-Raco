package com.kanagawa.yamada.project.raco

import android.content.Context
import android.content.Intent
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.combinedClickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.RandomAccessFile

@Composable
fun RacoPortraitPanel(
    isOpen: Boolean,
    isFromLeft: Boolean,
    themeColor: Color,
    currentPerfMode: PerfMode,
    onModeChange: (PerfMode) -> Unit,
    onClose: () -> Unit,
    onTakeScreenshot: () -> Unit
) {
    val offset = remember { Animatable(if (isFromLeft) -400f else 400f) }
    
    LaunchedEffect(isOpen) {
        if (isOpen) {
            offset.snapTo(if (isFromLeft) -400f else 400f)
            offset.animateTo(0f, tween(400, easing = FastOutSlowInEasing))
        } else {
            offset.animateTo(if (isFromLeft) -400f else 400f, tween(400, easing = FastOutSlowInEasing))
        }
    }

    var portraitMenuState by remember { mutableStateOf("MAIN") }
    var isRefreshRateMenuOpen by remember { mutableStateOf(false) }
    val context = LocalContext.current
    var currentRefreshRate by remember { 
        mutableStateOf(context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE).getFloat("override_refresh_rate", 0f))
    }

    if (isOpen || offset.value > -390f && isFromLeft || offset.value < 390f && !isFromLeft) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 64.dp)
        ) {
            if (isRefreshRateMenuOpen) {
                Box(
                    modifier = Modifier
                        .align(if (isFromLeft) Alignment.TopStart else Alignment.TopEnd)
                        .offset { IntOffset(offset.value.dp.roundToPx(), 0) }
                        .padding(horizontal = 16.dp)
                        .width(320.dp)
                        .clip(RoundedCornerShape(24.dp))
                        .background(Color(0xE6121212))
                        .border(1.dp, Color.White.copy(alpha=0.1f), RoundedCornerShape(24.dp))
                        .padding(20.dp)
                ) {
                    com.kanagawa.yamada.project.raco.RefreshRateMenu(
                        themeColor = themeColor,
                        onClose = { isRefreshRateMenuOpen = false },
                        onRateSelected = { currentRefreshRate = it }
                    )
                }
            } else {
                Box(
                    modifier = Modifier
                        .align(if (isFromLeft) Alignment.TopStart else Alignment.TopEnd)
                        .offset { IntOffset(offset.value.dp.roundToPx(), 0) }
                        .padding(horizontal = 16.dp)
                        .width(320.dp)
                        .clip(RoundedCornerShape(24.dp))
                        .background(Color(0xE6121212))
                        .border(1.dp, Color.White.copy(alpha=0.1f), RoundedCornerShape(24.dp))
                        .padding(20.dp)
                ) {
                    Crossfade(targetState = portraitMenuState, label = "menuCrossfade") { state ->
                        if (state == "CROSSHAIR") {
                            com.kanagawa.yamada.project.raco.RacoGameTools.CrosshairMenu(themeColor = themeColor, onClose = { portraitMenuState = "MAIN" })
                        } else if (state == "AYUNDA") {
                            com.kanagawa.yamada.project.raco.RacoGameTools.AyundaMenu(themeColor = themeColor, onClose = { portraitMenuState = "MAIN" })
                        } else if (state == "AUXLINE") {
                            com.kanagawa.yamada.project.raco.RacoGameTools.AuxLineMenu(themeColor = themeColor, onClose = { portraitMenuState = "MAIN" })
                        } else {
                            Column {
                            // Header
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "PROJECT RACO",
                                color = themeColor,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Black,
                                letterSpacing = 2.sp
                            )
                            Icon(
                                imageVector = Icons.Filled.Close,
                                contentDescription = "Close",
                                tint = Color.White,
                                modifier = Modifier
                                    .size(24.dp)
                                    .clickable { onClose() }
                            )
                        }
                        Spacer(modifier = Modifier.height(24.dp))
                        
                        // Hardware Stats Row
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceEvenly
                        ) {
                            StatBoxPortrait(title = "CPU", value = getCpuFreq(), unit = "GHz", color = themeColor)
                            StatBoxPortrait(title = "BATTERY", value = getBatteryLevel(LocalContext.current), unit = "%", color = themeColor)
                        }
                        
                        Spacer(modifier = Modifier.height(24.dp))
                        
                        // Modes
                        Text("PERFORMANCE MODE", color = Color.Gray, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(12.dp)).background(Color(0xFF222222))
                        ) {
                            val modes = listOf(PerfMode.POWERSAVE, PerfMode.BALANCED, PerfMode.AWAKEN)
                            modes.forEach { mode ->
                                val isSelected = currentPerfMode == mode
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxHeight()
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(if (isSelected) themeColor else Color.Transparent)
                                        .clickable { onModeChange(mode) },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = mode.name,
                                        color = if (isSelected) Color.White else Color.Gray,
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }
                        
                        Spacer(modifier = Modifier.height(24.dp))
                        
                        // Quick Tools
                        Text("QUICK TOOLS", color = Color.Gray, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(12.dp))
                        
                        Column(modifier = Modifier.fillMaxWidth().height(170.dp).verticalScroll(rememberScrollState())) {
                            val context = LocalContext.current
                            val prefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
                            var isDndOn by remember { mutableStateOf(false) }
                            var isCrosshairOn by remember { mutableStateOf(prefs.getBoolean("is_crosshair_enabled", false)) }
                            var isAyundaOn by remember { mutableStateOf(prefs.getBoolean("is_ayunda_enabled", false)) }
                            var isAuxLineOn by remember { mutableStateOf(prefs.getBoolean("is_auxline_enabled", false)) }
                            var isInfoOn by remember { mutableStateOf(prefs.getBoolean("is_info_enabled", false)) }
                            var isRotLockOn by remember { mutableStateOf(prefs.getBoolean("is_rotation_locked", false)) }
                            
                            val crosshairIcon = remember {
                                androidx.compose.ui.graphics.vector.ImageVector.Builder(
                                    name = "Crosshair",
                                    defaultWidth = 24.dp,
                                    defaultHeight = 24.dp,
                                    viewportWidth = 24f,
                                    viewportHeight = 24f
                                ).apply {
                                    addPath(
                                        pathData = androidx.compose.ui.graphics.vector.addPathNodes("M12 2v6M12 16v6M2 12h6M16 12h6"),
                                        stroke = androidx.compose.ui.graphics.SolidColor(Color.White),
                                        strokeLineWidth = 2f,
                                        strokeLineCap = androidx.compose.ui.graphics.StrokeCap.Round
                                    )
                                    addPath(
                                        pathData = androidx.compose.ui.graphics.vector.addPathNodes("M12 12m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0"),
                                        fill = androidx.compose.ui.graphics.SolidColor(Color.White)
                                    )
                                }.build()
                            }
                            
                            // Row 1
                            Row(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                                ToolButtonPortrait(Icons.Filled.DoNotDisturbOn, "DND", isDndOn, themeColor) {
                                    isDndOn = !isDndOn
                                    val cmd = if (isDndOn) "cmd notification set_dnd priority" else "cmd notification set_dnd off"
                                    Thread { try { Runtime.getRuntime().exec(arrayOf("su", "-c", cmd)).waitFor() } catch (e: Exception) {} }.start()
                                }
                                ToolButtonPortrait(crosshairIcon, "Crosshair", isCrosshairOn, themeColor, onLongClick = { portraitMenuState = "CROSSHAIR" }) {
                                    isCrosshairOn = !isCrosshairOn
                                    prefs.edit().putBoolean("is_crosshair_enabled", isCrosshairOn).apply()
                                    val intent = Intent(context, com.kanagawa.yamada.project.raco.RacoGameTools.GameCrosshairService::class.java)
                                    if (isCrosshairOn) context.startService(intent) else context.stopService(intent)
                                }
                                ToolButtonPortrait(Icons.Filled.CameraAlt, "Screenshot", false, themeColor) { onTakeScreenshot() }
                            }
                            
                            // Row 2
                            Row(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                                ToolButtonPortrait(Icons.Filled.Refresh, "Refresh Rate", currentRefreshRate > 0f, themeColor) {
                                    isRefreshRateMenuOpen = true
                                }
                                ToolButtonPortrait(Icons.Filled.Visibility, "Ayunda", isAyundaOn, themeColor, onLongClick = { portraitMenuState = "AYUNDA" }) {
                                    isAyundaOn = !isAyundaOn
                                    prefs.edit().putBoolean("is_ayunda_enabled", isAyundaOn).apply()
                                    kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO).launch {
                                        try {
                                            val cmd = java.lang.StringBuilder()
                                            if (isAyundaOn) {
                                                var currentFilterStr = prefs.getString("ayunda_filter", "NORMAL") ?: "NORMAL"
                                                if (currentFilterStr == "NORMAL") {
                                                    currentFilterStr = "VIVID"
                                                    prefs.edit().putString("ayunda_filter", "VIVID").apply()
                                                }
                                                cmd.append("settings put secure accessibility_display_inversion_enabled ${if (currentFilterStr == "INVERT") 1 else 0}; ")
                                                cmd.append("settings put secure accessibility_display_daltonizer_enabled 0; ")
                                                val saturation = when(currentFilterStr) { "VIVID" -> 1.5f; "VIVID_MAX" -> 2.0f; "GRAYSCALE" -> 0.0f; else -> 1.0f }
                                                cmd.append("service call SurfaceFlinger 1022 f $saturation; ")
                                            } else {
                                                cmd.append("settings put secure accessibility_display_inversion_enabled 0; settings put secure accessibility_display_daltonizer_enabled 0; service call SurfaceFlinger 1022 f 1.0; service call SurfaceFlinger 1015 i32 0")
                                            }
                                            Runtime.getRuntime().exec(arrayOf("su", "-c", cmd.toString())).waitFor()
                                        } catch (e: Exception) {}
                                    }
                                }
                                ToolButtonPortrait(Icons.Filled.Architecture, "AuxLine", isAuxLineOn, themeColor, onLongClick = { portraitMenuState = "AUXLINE" }) {
                                    isAuxLineOn = !isAuxLineOn
                                    prefs.edit().putBoolean("is_auxline_enabled", isAuxLineOn).apply()
                                    val intent = Intent(context, com.kanagawa.yamada.project.raco.RacoGameTools.GameAuxLineService::class.java)
                                    if (isAuxLineOn) context.startService(intent) else context.stopService(intent)
                                }
                            }
                            
                            // Row 3
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                ToolButtonPortrait(Icons.Filled.ScreenLockRotation, "Rot. Lock", isRotLockOn, themeColor) {
                                    isRotLockOn = !isRotLockOn
                                    prefs.edit().putBoolean("is_rotation_locked", isRotLockOn).apply()
                                    val intent = Intent(context, RotationLockService::class.java)
                                    if (isRotLockOn) context.startService(intent) else context.stopService(intent)
                                }
                                ToolButtonPortrait(Icons.Filled.Info, "Float Info", isInfoOn, themeColor) {
                                    isInfoOn = !isInfoOn
                                    prefs.edit().putBoolean("is_info_enabled", isInfoOn).apply()
                                    val intent = Intent(context, FloatingInfoService::class.java)
                                    if (isInfoOn) context.startService(intent) else context.stopService(intent)
                                }
                                Spacer(modifier = Modifier.width(80.dp))
                            }
                        }
                        }
                    }
                }
            }
        }
    }
}
}

@Composable
fun StatBoxPortrait(title: String, value: String, unit: String, color: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.width(80.dp)
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .border(2.dp, color.copy(alpha=0.5f), androidx.compose.foundation.shape.CircleShape)
                .padding(4.dp)
                .border(2.dp, color, androidx.compose.foundation.shape.CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(text = value, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text(text = unit, color = Color.Gray, fontSize = 10.sp)
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(text = title, color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Medium)
    }
}

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun ToolButtonPortrait(
    icon: androidx.compose.ui.graphics.vector.ImageVector, 
    title: String, 
    isActive: Boolean, 
    activeColor: Color, 
    onLongClick: (() -> Unit)? = null,
    onClick: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally, 
        modifier = Modifier
            .width(80.dp)
            .combinedClickable(
                onClick = { onClick() },
                onLongClick = { onLongClick?.invoke() }
            )
    ) {
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(if (isActive) activeColor else Color(0xFF222222)),
            contentAlignment = Alignment.Center
        ) {
            Icon(imageVector = icon, contentDescription = title, tint = Color.White, modifier = Modifier.size(24.dp))
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(text = title, color = Color.White, fontSize = 10.sp, maxLines = 1)
    }
}

@Composable
fun getCpuFreq(): String {
    var cpuFreq by remember { mutableStateOf("0.0") }
    LaunchedEffect(Unit) {
        var targetFile = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
        try {
            val cpuDir = java.io.File("/sys/devices/system/cpu/")
            val maxCpuNum = cpuDir.listFiles()?.mapNotNull { it.name.removePrefix("cpu").toIntOrNull() }?.maxOrNull()
            if (maxCpuNum != null) {
                val file = java.io.File("/sys/devices/system/cpu/cpu$maxCpuNum/cpufreq/scaling_cur_freq")
                if (file.exists()) targetFile = file.absolutePath
            }
        } catch (e: Exception) {}
        while(true) {
            try {
                val reader = RandomAccessFile(targetFile, "r")
                val freqString = reader.readLine()
                reader.close()
                cpuFreq = String.format(java.util.Locale.US, "%.1f", freqString.toLong() / 1000000.0)
            } catch (e: Exception) {}
            delay(1000)
        }
    }
    return cpuFreq
}

fun getBatteryLevel(context: Context): String {
    val bm = context.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
    return bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY).toString()
}
