package com.kanagawa.yamada.project.raco
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.interaction.collectIsPressedAsState

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.BaselineShift
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.material.icons.filled.BrightnessHigh
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.style.TextAlign
import kotlin.math.roundToInt
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import androidx.compose.ui.platform.LocalContext
import java.io.RandomAccessFile
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import com.kanagawa.yamada.project.raco.RacoOverlayTools.*

val RacoRed = Color(0xFFFF2A2A)

@Composable
fun RacoGameOverlay(targetPackageName: String? = null, onStateBind: (openLeft: () -> Unit, openRight: () -> Unit) -> Unit, onClose: () -> Unit) {
    val context = LocalContext.current
    var isLeftOpen by remember { mutableStateOf(false) }
    var isRightOpen by remember { mutableStateOf(false) }
    val prefs = context.getSharedPreferences("raco_slingshot_prefs", android.content.Context.MODE_PRIVATE)
    var currentPerfMode by remember { 
        val savedMode = prefs.getString("global_perf_mode", PerfMode.AWAKEN.name) ?: PerfMode.AWAKEN.name
        mutableStateOf(
            try { PerfMode.valueOf(savedMode) } catch(e: Exception) { PerfMode.AWAKEN }
        ) 
    }
    val themeColor by androidx.compose.animation.animateColorAsState(
        targetValue = currentPerfMode.color,
        animationSpec = tween(durationMillis = 600, easing = FastOutSlowInEasing),
        label = "themeColor"
    )

    val lineSlideProgress = remember { Animatable(0f) }

    // Premium fluid motion curve: perfectly smooth transition from high speed to a long, gentle glide
    val dramaticEasing = androidx.compose.animation.core.CubicBezierEasing(0.16f, 1.0f, 0.3f, 1.0f)

    LaunchedEffect(isLeftOpen || isRightOpen) {
        if (isLeftOpen || isRightOpen) {
            lineSlideProgress.snapTo(0f)
            lineSlideProgress.animateTo(1f, tween(durationMillis = 1800, easing = dramaticEasing, delayMillis = 200))
        } else {
            lineSlideProgress.animateTo(0f, tween(durationMillis = 400, easing = FastOutSlowInEasing))
        }
    }

    var lastMode by remember { mutableStateOf(currentPerfMode) }
    LaunchedEffect(currentPerfMode) {
        if (lastMode != currentPerfMode) {
            lastMode = currentPerfMode
            if (isLeftOpen || isRightOpen) {
                lineSlideProgress.snapTo(0f)
                lineSlideProgress.animateTo(1f, tween(durationMillis = 1800, easing = dramaticEasing))
            }
        }
    }

    LaunchedEffect(Unit) {
        onStateBind(
            { isLeftOpen = true },
            { isRightOpen = true }
        )
    }

    var pendingScreenshot by remember { mutableStateOf(false) }

    val leftOffset by animateDpAsState(
        targetValue = if (isLeftOpen) 0.dp else (-300).dp,
        animationSpec = tween(400, easing = FastOutSlowInEasing),
        label = "leftOffset",
        finishedListener = {
            if (!isLeftOpen && pendingScreenshot) {
                pendingScreenshot = false
                Thread {
                    try {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "input keyevent 120")).waitFor()
                    } catch (e: Exception) {}
                }.start()
            }
        }
    )

    val rightOffset by animateDpAsState(
        targetValue = if (isRightOpen) 0.dp else 300.dp,
        animationSpec = tween(400, easing = FastOutSlowInEasing),
        label = "rightOffset"
    )

    Box(modifier = Modifier.fillMaxSize()) {
        // The invisible touch areas for edge swipe to OPEN are now handled by InGameMenuService directly!
        if (isLeftOpen || isRightOpen) {
            Box(
                modifier = Modifier.fillMaxSize().pointerInput(Unit) {
                    detectHorizontalDragGestures { _, dragAmount ->
                        // Swipe left (< -20) closes left panel, swipe right (> 20) closes right panel.
                        // Since they are synced, either swipe closes both.
                        if (dragAmount < -20 || dragAmount > 20) {
                            isLeftOpen = false
                            isRightOpen = false
                            onClose()
                        }
                    }
                }
            )
        }

        // LEFT PANEL
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .offset { androidx.compose.ui.unit.IntOffset(leftOffset.roundToPx(), 0) }
                .fillMaxHeight()
                .width(260.dp)
        ) {
            RacoLeftPanel(
                progressProvider = { lineSlideProgress.value },
                themeColor = themeColor,
                onClose = {
                    isLeftOpen = false
                    isRightOpen = false
                    onClose()
                },
                onTakeScreenshot = {
                    pendingScreenshot = true
                    isLeftOpen = false
                    isRightOpen = false
                    onClose()
                }
            )
        }

        // RIGHT PANEL
        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .offset { androidx.compose.ui.unit.IntOffset(rightOffset.roundToPx(), 0) }
                .fillMaxHeight()
                .width(260.dp)
        ) {
            RacoRightPanel(
                progressProvider = { lineSlideProgress.value },
                currentPerfMode = currentPerfMode,
                targetPackageName = targetPackageName,
                themeColor = themeColor,
                onModeChange = { 
                    currentPerfMode = it 
                    // Send command to UNIX socket
                    kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO).launch {
                        try {
                            val socket = android.net.LocalSocket()
                            val address = android.net.LocalSocketAddress("raco_gameservice", android.net.LocalSocketAddress.Namespace.ABSTRACT)
                            socket.connect(address)
                            val payload = if (targetPackageName != null) "${it.name}:$targetPackageName" else it.name
                            socket.outputStream.write(payload.toByteArray())
                            socket.close()
                            
                            // Save globally for next launches
                            val prefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
                            prefs.edit().putString("global_perf_mode", it.name).apply()
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
            )
        }
    }
}

@Composable
fun RacoLeftPanel(
    progressProvider: () -> Float = { 1f },
    themeColor: Color = RacoRed,
    onClose: () -> Unit = {},
    onTakeScreenshot: () -> Unit = {}
) {
    var cpuFreq by remember { mutableStateOf("0.00") }
    var cpuPercentage by remember { mutableStateOf(0f) }
    var currentTimeString by remember { 
        mutableStateOf(java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault()).format(java.util.Date())) 
    }
    val context = LocalContext.current
    var isDndOn by remember { mutableStateOf(false) }

    var currentBrightness by remember { 
        mutableStateOf(
            try {
                android.provider.Settings.System.getInt(context.contentResolver, android.provider.Settings.System.SCREEN_BRIGHTNESS)
            } catch (e: Exception) {
                128
            }
        )
    }

    val animatedCpuPercentage by animateFloatAsState(
        targetValue = cpuPercentage,
        animationSpec = tween(1000, easing = FastOutSlowInEasing),
        label = "cpuProgress"
    )

    LaunchedEffect(Unit) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            isDndOn = notificationManager.currentInterruptionFilter != android.app.NotificationManager.INTERRUPTION_FILTER_ALL
        } catch (e: Exception) {}

        var targetFile = "/sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq"
        var maxFile = "/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq"
        try {
            val cpufreqDir = java.io.File("/sys/devices/system/cpu/cpufreq/")
            val maxPolicyNum = cpufreqDir.listFiles()
                ?.mapNotNull { 
                    if (it.name.startsWith("policy")) it.name.removePrefix("policy").toIntOrNull() else null 
                }
                ?.maxOrNull()
            
            if (maxPolicyNum != null) {
                val file = java.io.File("/sys/devices/system/cpu/cpufreq/policy$maxPolicyNum/scaling_cur_freq")
                if (file.exists()) {
                    targetFile = file.absolutePath
                    maxFile = "/sys/devices/system/cpu/cpufreq/policy$maxPolicyNum/cpuinfo_max_freq"
                }
            }
        } catch (e: Exception) {
            // Fallback to policy0
        }

        var maxFreqHz = 3000000L
        try {
            val maxReader = RandomAccessFile(maxFile, "r")
            val maxFreqStr = maxReader.readLine()
            maxReader.close()
            if (maxFreqStr != null) {
                maxFreqHz = maxFreqStr.toLong()
            }
        } catch (e: Exception) {
            // Ignore
        }

        val sdf = java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault())
        while(true) {
            try {
                val reader = RandomAccessFile(targetFile, "r")
                val freqString = reader.readLine()
                reader.close()
                val freqHz = freqString.toLong()
                val freqGHz = freqHz / 1000000.0
                cpuFreq = String.format(java.util.Locale.US, "%.2f", freqGHz)
                
                var percentage = freqHz.toFloat() / maxFreqHz.toFloat()
                if (percentage > 1f) percentage = 1f
                if (percentage < 0.05f) percentage = 0.05f
                cpuPercentage = percentage
            } catch (e: Exception) {
                // Ignore or keep last known
            }
            currentTimeString = sdf.format(java.util.Date())
            delay(1000)
        }
    }

    var leftMenuState by remember { mutableStateOf("MAIN") }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .drawBehind {
                val path = Path().apply {
                    moveTo(0f, -size.height * 0.2f)
                    lineTo(size.width * 0.5f, -size.height * 0.2f)
                    lineTo(size.width, size.height * 0.3f)
                    lineTo(size.width * 0.58f, size.height * 1.2f)
                    lineTo(0f, size.height * 1.2f)
                    close()
                }
                drawPath(
                    path = path,
                    brush = Brush.horizontalGradient(listOf(Color.Black.copy(alpha=0.9f), Color.Black.copy(alpha=0.4f)))
                )
                
                // Red glowing border
                val borderPath = Path().apply {
                    moveTo(size.width * 0.5f, -size.height * 0.2f)
                    lineTo(size.width, size.height * 0.3f)
                    lineTo(size.width * 0.58f, size.height * 1.2f)
                }
                
                // Base white line
                drawPath(path = borderPath, color = Color.White, style = Stroke(width = 6.dp.toPx()))

                // Uprise Red glowing border
                val progress = progressProvider() * animatedCpuPercentage
                if (progress > 0f) {
                    val currentTop = size.height * 1.2f - (size.height * 1.4f * progress)
                    clipRect(top = currentTop, bottom = size.height * 1.2f, left = -size.width, right = size.width * 2f) {
                        translate(left = 1.5.dp.toPx(), top = 0f) {
                            drawPath(path = borderPath, color = themeColor.copy(alpha=0.4f), style = Stroke(width = 9.dp.toPx()))
                        }
                        drawPath(path = borderPath, color = themeColor, style = Stroke(width = 6.dp.toPx()))
                    }
                }
            }
            .padding(start = 24.dp, top = 24.dp, bottom = 24.dp, end = 35.dp)
    ) {
        androidx.compose.animation.AnimatedContent(
            targetState = leftMenuState,
            modifier = Modifier.fillMaxSize(),
            transitionSpec = {
                (androidx.compose.animation.fadeIn(androidx.compose.animation.core.tween(300))
                    .togetherWith(androidx.compose.animation.fadeOut(androidx.compose.animation.core.tween(300))))
                    .using(androidx.compose.animation.SizeTransform(clip = false))
            },
            label = "LeftMenuAnimation"
        ) { menuState ->
            if (menuState == "CROSSHAIR") {
                com.kanagawa.yamada.project.raco.RacoGameTools.CrosshairMenu(
                    themeColor = themeColor,
                    onClose = { leftMenuState = "MAIN" }
                )
            } else if (menuState == "AYUNDA") {
                com.kanagawa.yamada.project.raco.RacoGameTools.AyundaMenu(
                    themeColor = themeColor,
                    onClose = { leftMenuState = "MAIN" }
                )
            } else {
                Column(modifier = Modifier.fillMaxSize()) {
                    // CPU Monitor
            Column(horizontalAlignment = Alignment.Start, modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = "CPU • $currentTimeString",
                    color = themeColor,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.sp
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = buildAnnotatedString {
                        append(cpuFreq)
                        withStyle(SpanStyle(fontSize = 14.sp, color = Color.White.copy(alpha=0.6f), baselineShift = BaselineShift.Superscript)) {
                            append(" GHz")
                        }
                    },
                    color = Color.White,
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Black
                )
                
                Spacer(modifier = Modifier.height(8.dp))
            }
            
            // DND Toggle
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = "DND",
                    color = themeColor,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.sp
                )
                Spacer(modifier = Modifier.width(12.dp))
                androidx.compose.material3.Switch(
                    checked = isDndOn,
                    onCheckedChange = { checked ->
                        isDndOn = checked
                        val cmd = if (checked) "cmd notification set_dnd priority" else "cmd notification set_dnd off"
                        Thread {
                            try {
                                Runtime.getRuntime().exec(arrayOf("su", "-c", cmd)).waitFor()
                            } catch (e: Exception) {}
                        }.start()
                    },
                    modifier = Modifier.scale(0.75f),
                    colors = androidx.compose.material3.SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = themeColor,
                        checkedBorderColor = Color.Transparent,
                        uncheckedThumbColor = Color.LightGray,
                        uncheckedTrackColor = Color.DarkGray,
                        uncheckedBorderColor = Color.Transparent
                    )
                )

                Spacer(modifier = Modifier.weight(1f))

                Box(
                    modifier = Modifier
                        .width(81.dp)
                        .height(32.dp)
                        .border(1.dp, themeColor, RoundedCornerShape(16.dp))
                        .clickable {
                            onTakeScreenshot()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    androidx.compose.material3.Icon(
                        imageVector = Icons.Filled.CameraAlt,
                        contentDescription = "Screenshot",
                        tint = themeColor,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(4.dp))

            // Brightness Slider
            val density = LocalDensity.current
            val configuration = LocalConfiguration.current
            val screenHeightPx = with(density) { configuration.screenHeightDp.dp.toPx() }
            val panelWidthPx = with(density) { 260.dp.toPx() }
            val slope = if (screenHeightPx > 0) (0.42f * panelWidthPx) / (0.9f * screenHeightPx) else 0.4f

            val brightnessRatio = currentBrightness.toFloat() / 255f
            val verticalDistance = 13 * (4.2f + 2.1f) // 13 gaps for 14 steps
            val deltaX = verticalDistance * slope
            val dynamicMinWidth = (35f - deltaX).coerceAtLeast(2f).dp

            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.CenterEnd
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.End
                ) {
                    val prefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
                    var isCrosshairOn by remember { mutableStateOf(prefs.getBoolean("is_crosshair_enabled", false)) }
                    var isAyundaOn by remember { mutableStateOf(prefs.getBoolean("is_ayunda_enabled", false)) }
                    
                    // Crosshair & Ayunda Buttons Container
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .padding(end = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        // --- CROSSHAIR ---
                        val leftInteractionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
                        val isLeftPressed by leftInteractionSource.collectIsPressedAsState()
                        val rightInteractionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
                        val isRightPressed by rightInteractionSource.collectIsPressedAsState()

                        val leftBgColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isLeftPressed) Color.White.copy(alpha = 0.2f) else Color.Transparent,
                            animationSpec = androidx.compose.animation.core.tween(150), label = ""
                        )
                        val rightBgColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isRightPressed) Color.White.copy(alpha = 0.2f) else Color.Transparent,
                            animationSpec = androidx.compose.animation.core.tween(150), label = ""
                        )
                        val mainBgColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isCrosshairOn) themeColor.copy(alpha = 0.2f) else Color.Transparent,
                            animationSpec = androidx.compose.animation.core.tween(300), label = ""
                        )
                        val mainBorderColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isCrosshairOn) themeColor else Color.White.copy(alpha=0.2f),
                            animationSpec = androidx.compose.animation.core.tween(300), label = ""
                        )
                        val contentAnimColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isCrosshairOn) themeColor else Color.White,
                            animationSpec = androidx.compose.animation.core.tween(300), label = ""
                        )

                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(32.dp)
                                .clip(RoundedCornerShape(6.dp))
                                .background(mainBgColor)
                                .border(1.dp, mainBorderColor, RoundedCornerShape(6.dp))
                        ) {
                            Row(modifier = Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                                val CrosshairIcon = remember {
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
                                // Main Toggle Area
                                Row(
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxHeight()
                                        .background(leftBgColor)
                                        .clickable(
                                            interactionSource = leftInteractionSource,
                                            indication = null
                                        ) {
                                            isCrosshairOn = !isCrosshairOn
                                            prefs.edit().putBoolean("is_crosshair_enabled", isCrosshairOn).apply()
                                            val crosshairIntent = Intent(context, com.kanagawa.yamada.project.raco.RacoGameTools.GameCrosshairService::class.java)
                                            if (isCrosshairOn) {
                                                context.startService(crosshairIntent)
                                            } else {
                                                context.stopService(crosshairIntent)
                                            }
                                        }
                                        .padding(start = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    androidx.compose.material3.Icon(
                                        imageVector = CrosshairIcon,
                                        contentDescription = "Crosshair Toggle",
                                        tint = contentAnimColor,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = "Crosshair",
                                        color = contentAnimColor,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }

                                // Menu Area
                                Box(
                                    modifier = Modifier
                                        .fillMaxHeight()
                                        .background(rightBgColor)
                                        .clickable(
                                            interactionSource = rightInteractionSource,
                                            indication = null
                                        ) { leftMenuState = "CROSSHAIR" }
                                        .padding(horizontal = 8.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    androidx.compose.material3.Icon(
                                        imageVector = Icons.Filled.MoreVert,
                                        contentDescription = "Menu",
                                        tint = contentAnimColor,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }
                        }

                        // --- AYUNDA ENGINE ---
                        val ayundaLeftInteractionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
                        val isAyundaLeftPressed by ayundaLeftInteractionSource.collectIsPressedAsState()
                        val ayundaRightInteractionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
                        val isAyundaRightPressed by ayundaRightInteractionSource.collectIsPressedAsState()

                        val ayundaLeftBgColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isAyundaLeftPressed) Color.White.copy(alpha = 0.2f) else Color.Transparent,
                            animationSpec = androidx.compose.animation.core.tween(150), label = ""
                        )
                        val ayundaRightBgColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isAyundaRightPressed) Color.White.copy(alpha = 0.2f) else Color.Transparent,
                            animationSpec = androidx.compose.animation.core.tween(150), label = ""
                        )
                        val ayundaMainBgColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isAyundaOn) themeColor.copy(alpha = 0.2f) else Color.Transparent,
                            animationSpec = androidx.compose.animation.core.tween(300), label = ""
                        )
                        val ayundaMainBorderColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isAyundaOn) themeColor else Color.White.copy(alpha=0.2f),
                            animationSpec = androidx.compose.animation.core.tween(300), label = ""
                        )
                        val ayundaContentAnimColor by androidx.compose.animation.animateColorAsState(
                            targetValue = if (isAyundaOn) themeColor else Color.White,
                            animationSpec = androidx.compose.animation.core.tween(300), label = ""
                        )

                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(32.dp)
                                .clip(RoundedCornerShape(6.dp))
                                .background(ayundaMainBgColor)
                                .border(1.dp, ayundaMainBorderColor, RoundedCornerShape(6.dp))
                        ) {
                            Row(modifier = Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                                // Main Toggle Area
                                Row(
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxHeight()
                                        .background(ayundaLeftBgColor)
                                        .clickable(
                                            interactionSource = ayundaLeftInteractionSource,
                                            indication = null
                                        ) {
                                            isAyundaOn = !isAyundaOn
                                            prefs.edit().putBoolean("is_ayunda_enabled", isAyundaOn).apply()
                                            
                                            kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO).launch {
                                                try {
                                                    if (isAyundaOn) {
                                                        // Apply current filter
                                                        val currentFilterStr = prefs.getString("ayunda_filter", "NORMAL") ?: "NORMAL"
                                                        when (currentFilterStr) {
                                                            "NORMAL" -> {
                                                                Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_display_inversion_enabled 0")).waitFor()
                                                                Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1022 f 1.0")).waitFor()
                                                            }
                                                            "VIVID" -> {
                                                                Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_display_inversion_enabled 0")).waitFor()
                                                                Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1022 f 1.5")).waitFor()
                                                            }
                                                            "GRAYSCALE" -> {
                                                                Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_display_inversion_enabled 0")).waitFor()
                                                                Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1022 f 0.0")).waitFor()
                                                            }
                                                            "INVERT" -> {
                                                                Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1022 f 1.0")).waitFor()
                                                                Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_display_inversion_enabled 1")).waitFor()
                                                            }
                                                        }
                                                    } else {
                                                        // Reset filter
                                                        Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_display_inversion_enabled 0")).waitFor()
                                                        Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1022 f 1.0")).waitFor()
                                                    }
                                                } catch (e: Exception) {}
                                            }
                                        }
                                        .padding(start = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    androidx.compose.material3.Icon(
                                        imageVector = androidx.compose.material.icons.Icons.Filled.Visibility,
                                        contentDescription = "Ayunda Toggle",
                                        tint = ayundaContentAnimColor,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = "Ayunda",
                                        color = ayundaContentAnimColor,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }

                                // Menu Area
                                Box(
                                    modifier = Modifier
                                        .fillMaxHeight()
                                        .background(ayundaRightBgColor)
                                        .clickable(
                                            interactionSource = ayundaRightInteractionSource,
                                            indication = null
                                        ) { leftMenuState = "AYUNDA" }
                                        .padding(horizontal = 8.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    androidx.compose.material3.Icon(
                                        imageVector = Icons.Filled.MoreVert,
                                        contentDescription = "Menu",
                                        tint = ayundaContentAnimColor,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }
                        }
                    }

                    // Gradient Separator Line
                    Box(
                        modifier = Modifier
                            .padding(end = 16.dp)
                            .width(2.dp)
                            .height(86.dp)
                            .background(
                                brush = Brush.verticalGradient(
                                    colors = listOf(Color.White, themeColor)
                                )
                            )
                    )

                    Column(
                        horizontalAlignment = Alignment.Start,
                        modifier = Modifier.wrapContentWidth()
                    ) {
                        TriangleSlider(
                            value = brightnessRatio,
                            onValueChange = { newValue ->
                                val newBrightness = (newValue * 255).roundToInt().coerceIn(0, 255)
                                if (newBrightness != currentBrightness) {
                                    currentBrightness = newBrightness
                                    try {
                                        android.provider.Settings.System.putInt(
                                            context.contentResolver,
                                            android.provider.Settings.System.SCREEN_BRIGHTNESS,
                                            newBrightness
                                        )
                                    } catch (e: Exception) {
                                        Thread {
                                            try {
                                                Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put system screen_brightness $newBrightness")).waitFor()
                                            } catch (ex: Exception) {}
                                        }.start()
                                    }
                                }
                            },
                            activeColor = themeColor,
                            inactiveColor = Color.White.copy(alpha = 0.2f),
                            maxWidth = 35.dp,
                            minWidth = dynamicMinWidth,
                            barHeight = 4.2.dp,
                            spacing = 2.1.dp,
                            steps = 14,
                            alignRight = false
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        androidx.compose.material3.Icon(
                            imageVector = Icons.Filled.BrightnessHigh,
                            contentDescription = "Brightness",
                            tint = themeColor,
                            modifier = Modifier
                                .offset(x = (-8).dp)
                                .size(18.dp)
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(8.dp))
        }
            }
        }
    }
}

@Composable
fun RacoRightPanel(
    progressProvider: () -> Float = { 1f },
    currentPerfMode: PerfMode = PerfMode.AWAKEN,
    targetPackageName: String? = null,
    themeColor: Color = RacoRed,
    onModeChange: (PerfMode) -> Unit = {}
) {
    val context = LocalContext.current
    var batteryLevel by remember { mutableStateOf("--") }
    var batteryPercentage by remember { mutableStateOf(0f) }

    val animatedBatteryPercentage by animateFloatAsState(
        targetValue = batteryPercentage,
        animationSpec = tween(1000, easing = FastOutSlowInEasing),
        label = "batteryProgress"
    )

    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
    val maxVolume = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
    var currentVolume by remember { mutableStateOf(audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)) }

    DisposableEffect(context) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_BATTERY_CHANGED) {
                    val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                    val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                    if (level != -1 && scale != -1) {
                        val rawPercentage = level.toFloat() / scale.toFloat()
                        batteryLevel = (rawPercentage * 100).toInt().toString()
                        batteryPercentage = rawPercentage
                    }
                } else if (intent.action == "android.media.VOLUME_CHANGED_ACTION") {
                    val streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                    if (streamType == android.media.AudioManager.STREAM_MUSIC) {
                        currentVolume = audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_BATTERY_CHANGED)
            addAction("android.media.VOLUME_CHANGED_ACTION")
            addAction("com.kanagawa.yamada.project.raco.SHOW_TOAST")
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        onDispose {
            context.unregisterReceiver(receiver)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .drawBehind {
                val path = Path().apply {
                    moveTo(size.width, -size.height * 0.2f)
                    lineTo(size.width * 0.5f, -size.height * 0.2f)
                    lineTo(0f, size.height * 0.3f)
                    lineTo(size.width * 0.42f, size.height * 1.2f)
                    lineTo(size.width, size.height * 1.2f)
                    close()
                }
                drawPath(
                    path = path,
                    brush = Brush.horizontalGradient(listOf(Color.Black.copy(alpha=0.4f), Color.Black.copy(alpha=0.9f)))
                )
                
                // Red glowing border
                val borderPath = Path().apply {
                    moveTo(size.width * 0.5f, -size.height * 0.2f)
                    lineTo(0f, size.height * 0.3f)
                    lineTo(size.width * 0.42f, size.height * 1.2f)
                }
                
                // Base white line
                drawPath(path = borderPath, color = Color.White, style = Stroke(width = 6.dp.toPx()))

                // Uprise Red glowing border
                val progress = progressProvider() * animatedBatteryPercentage
                if (progress > 0f) {
                    val currentTop = size.height * 1.2f - (size.height * 1.4f * progress)
                    clipRect(top = currentTop, bottom = size.height * 1.2f, left = -size.width, right = size.width * 2f) {
                        translate(left = -1.5.dp.toPx(), top = 0f) {
                            drawPath(path = borderPath, color = themeColor.copy(alpha=0.4f), style = Stroke(width = 9.dp.toPx()))
                        }
                        drawPath(path = borderPath, color = themeColor, style = Stroke(width = 6.dp.toPx()))
                    }
                }
            }
            .padding(start = 35.dp, top = 24.dp, bottom = 24.dp, end = 24.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize(), horizontalAlignment = Alignment.End) {
            val prefs = context.getSharedPreferences("raco_slingshot_prefs", android.content.Context.MODE_PRIVATE)
            var isRefreshRateMenuOpen by remember { mutableStateOf(false) }
            var currentRefreshRate by remember { mutableStateOf(prefs.getFloat("override_refresh_rate", 0f)) }

            androidx.compose.animation.AnimatedContent(
                targetState = isRefreshRateMenuOpen,
                transitionSpec = {
                    androidx.compose.animation.fadeIn(androidx.compose.animation.core.tween(300)).togetherWith(androidx.compose.animation.fadeOut(androidx.compose.animation.core.tween(300)))
                },
                label = "RefreshRateMenuAnimation"
            ) { isMenuOpen ->
                if (isMenuOpen) {
                    RefreshRateMenu(
                        themeColor = themeColor,
                        onClose = { isRefreshRateMenuOpen = false },
                        onRateSelected = { currentRefreshRate = it }
                    )
                } else {
                    Column(horizontalAlignment = Alignment.End) {
                        AutoSizeText("PROJECT", color = themeColor, baseFontSize = 28f, fontWeight = FontWeight.Light, letterSpacing = 2.sp)
                        AutoSizeText("RACO", color = Color.White, baseFontSize = 28f, fontWeight = FontWeight.Light, letterSpacing = 2.sp)
                        Spacer(modifier = Modifier.height(8.dp))
                        
                        // Performance & Battery Row
                        var expanded by remember { mutableStateOf(false) }
            val density = LocalDensity.current
            val configuration = LocalConfiguration.current

            val getModeTitle = { mode: PerfMode ->
                when (mode) {
                    PerfMode.AWAKEN -> "AWAKEN"
                    PerfMode.BALANCED -> "MID"
                    PerfMode.POWERSAVE -> "ECO"
                }
            }
            
            val screenHeightPx = with(density) { configuration.screenHeightDp.dp.toPx() }
            val panelWidthPx = with(density) { 260.dp.toPx() }
            val slope = if (screenHeightPx > 0) (0.42f * panelWidthPx) / (0.9f * screenHeightPx) else 0.4f

            val trapezoidShape = remember(density, slope) {
                androidx.compose.foundation.shape.GenericShape { size, _ ->
                    moveTo(0f, 0f)
                    lineTo(size.width, 0f)
                    lineTo(size.width, size.height)
                    lineTo(size.height * slope, size.height)
                    close()
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.End, modifier = Modifier.fillMaxWidth().zIndex(1f)) {
                Box(
                    modifier = Modifier
                        .offset(x = (-16).dp)
                        .weight(1f)
                        .height(32.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .wrapContentHeight(align = Alignment.Top, unbounded = true)
                            .clip(trapezoidShape)
                            .border(1.dp, themeColor.copy(alpha = 0.5f), trapezoidShape)
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(32.dp)
                                .background(themeColor.copy(alpha = 0.2f))
                                .clickable { expanded = !expanded }
                                .padding(end = 8.dp),
                            contentAlignment = Alignment.CenterEnd
                        ) {
                            Text(
                                text = getModeTitle(currentPerfMode),
                                color = themeColor,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                letterSpacing = 1.sp
                            )
                        }
    
                        if (expanded) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(Color.Black.copy(alpha = 0.8f))
                            ) {
                                PerfMode.entries.forEach { mode ->
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { 
                                                onModeChange(mode)
                                                expanded = false
                                            }
                                            .padding(vertical = 12.dp, horizontal = 12.dp),
                                        contentAlignment = Alignment.CenterEnd
                                    ) {
                                        Text(
                                            text = getModeTitle(mode), 
                                            color = Color.White, 
                                            fontSize = 12.sp, 
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                Text(
                    text = buildAnnotatedString {
                        append(batteryLevel)
                        withStyle(SpanStyle(fontSize = 14.sp, color = Color.White.copy(alpha=0.6f), baselineShift = BaselineShift.Superscript)) {
                            append("%")
                        }
                    },
                    color = Color.White,
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Black
                )
            }
            Spacer(modifier = Modifier.height(4.dp))
            
            // Volume Slider
            val volumeRatio = if (maxVolume > 0) currentVolume.toFloat() / maxVolume.toFloat() else 0f
            val verticalDistance = 13 * (4.2f + 2.1f) // 13 gaps for 14 steps
            val deltaX = verticalDistance * slope
            val dynamicMinWidth = (35f - deltaX).coerceAtLeast(2f).dp

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.Top
            ) {
                // Volume Slider Column
                Box(
                    modifier = Modifier.wrapContentWidth(),
                    contentAlignment = Alignment.TopStart
                ) {
                    Column(
                        horizontalAlignment = Alignment.End,
                        modifier = Modifier.wrapContentWidth()
                    ) {
                        TriangleSlider(
                            value = volumeRatio,
                            onValueChange = { newValue ->
                                val newVol = (newValue * maxVolume).roundToInt()
                                if (newVol != currentVolume) {
                                    audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, newVol, 0)
                                    currentVolume = newVol
                                }
                            },
                            activeColor = themeColor,
                            inactiveColor = Color.White.copy(alpha = 0.2f),
                            maxWidth = 35.dp,
                            minWidth = dynamicMinWidth,
                            barHeight = 4.2.dp,
                            spacing = 2.1.dp,
                            steps = 14,
                            alignRight = true
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        androidx.compose.material3.Icon(
                            imageVector = Icons.Filled.VolumeUp,
                            contentDescription = "Volume",
                            tint = themeColor,
                            modifier = Modifier
                                .offset(x = 8.dp)
                                .size(20.dp)
                        )
                    }
                }
                
                // Centered Glowing Separator Line
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(86.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .width(2.dp)
                            .fillMaxHeight()
                            .background(
                                brush = Brush.verticalGradient(
                                    colors = listOf(Color.White, themeColor)
                                )
                            )
                    )
                }

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    OverlayInfo(themeColor = themeColor)
                    Spacer(modifier = Modifier.height(16.dp))
                    OverlayRotationLock(themeColor = themeColor)
                }

                Spacer(modifier = Modifier.width(16.dp))

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    OverlayClean(themeColor = themeColor)
                    Spacer(modifier = Modifier.height(16.dp))
                    com.kanagawa.yamada.project.raco.RacoOverlayTools.OverlayRefreshRate(
                        themeColor = themeColor,
                        currentRate = currentRefreshRate
                    ) {
                        isRefreshRateMenuOpen = true
                    }
                }
            } // END OF ROW

            Spacer(modifier = Modifier.height(8.dp))
            
                } // END of Column inside else branch
            } // END of else branch
            } // END of AnimatedContent
        } // END of RightPanel main Column
    } // END of Box
} // END of RacoRightPanel

@Composable
fun AutoSizeText(
    text: String,
    color: Color,
    baseFontSize: Float,
    fontWeight: FontWeight,
    letterSpacing: androidx.compose.ui.unit.TextUnit
) {
    var multiplier by remember { mutableStateOf(1f) }
    Text(
        text = text,
        color = color,
        fontSize = (baseFontSize * multiplier).sp,
        fontWeight = fontWeight,
        letterSpacing = letterSpacing,
        maxLines = 1,
        softWrap = false,
        onTextLayout = { textLayoutResult ->
            if (textLayoutResult.hasVisualOverflow) {
                multiplier *= 0.95f
            }
        }
    )
}

@Composable
fun TriangleSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    steps: Int = 18,
    minWidth: androidx.compose.ui.unit.Dp = 10.dp,
    maxWidth: androidx.compose.ui.unit.Dp = 70.dp,
    barHeight: androidx.compose.ui.unit.Dp = 3.dp,
    spacing: androidx.compose.ui.unit.Dp = 3.dp,
    activeColor: Color = Color.White,
    inactiveColor: Color = Color.White.copy(alpha = 0.3f),
    alignRight: Boolean = true
) {
    var isDragging by remember { mutableStateOf(false) }
    
    Box(
        modifier = modifier
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { isDragging = true },
                    onDragEnd = { isDragging = false },
                    onDragCancel = { isDragging = false }
                ) { change, _ ->
                    val y = change.position.y
                    val newValue = 1f - (y / size.height).coerceIn(0f, 1f)
                    onValueChange(newValue)
                }
            }
            .pointerInput(Unit) {
                detectTapGestures { offset ->
                    val y = offset.y
                    val newValue = 1f - (y / size.height).coerceIn(0f, 1f)
                    onValueChange(newValue)
                }
            }
    ) {
        Column(
            modifier = Modifier.wrapContentSize(),
            horizontalAlignment = if (alignRight) Alignment.End else Alignment.Start,
            verticalArrangement = Arrangement.spacedBy(spacing)
        ) {
            for (i in (steps - 1) downTo 0) {
                val fraction = i.toFloat() / (steps - 1)
                val width = minWidth + (maxWidth - minWidth) * fraction
                val isActive = (value * (steps - 1)) >= i
                Box(
                    modifier = Modifier
                        .width(width)
                        .height(barHeight)
                        .background(if (isActive) activeColor else inactiveColor)
                )
            }
        }
    }
}
