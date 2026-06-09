package com.kanagawa.yamada.project.raco

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
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
import kotlin.math.roundToInt
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import androidx.compose.ui.platform.LocalContext
import java.io.RandomAccessFile
import kotlinx.coroutines.delay

val RacoRed = Color(0xFFFF2A2A)

@Composable
fun RacoGameOverlay(onStateBind: (openLeft: () -> Unit, openRight: () -> Unit) -> Unit, onClose: () -> Unit) {
    var isLeftOpen by remember { mutableStateOf(false) }
    var isRightOpen by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        onStateBind(
            { isLeftOpen = true },
            { isRightOpen = true }
        )
    }

    val leftOffset by animateDpAsState(
        targetValue = if (isLeftOpen) 0.dp else (-300).dp,
        animationSpec = tween(400, easing = FastOutSlowInEasing),
        label = "leftOffset"
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
                .offset(x = leftOffset)
                .fillMaxHeight()
                .width(260.dp)
        ) {
            RacoLeftPanel()
        }

        // RIGHT PANEL
        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .offset(x = rightOffset)
                .fillMaxHeight()
                .width(260.dp)
        ) {
            RacoRightPanel()
        }
    }
}

@Composable
fun RacoLeftPanel() {
    var cpuFreq by remember { mutableStateOf("0.00") }

    LaunchedEffect(Unit) {
        var targetFile = "/sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq"
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
                }
            }
        } catch (e: Exception) {
            // Fallback to policy0
        }

        while(true) {
            try {
                val reader = RandomAccessFile(targetFile, "r")
                val freqString = reader.readLine()
                reader.close()
                val freqHz = freqString.toLong()
                val freqGHz = freqHz / 1000000.0
                cpuFreq = String.format(java.util.Locale.US, "%.2f", freqGHz)
            } catch (e: Exception) {
                // Ignore or keep last known
            }
            delay(1000)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .drawBehind {
                val path = Path().apply {
                    moveTo(0f, -size.height * 0.2f)
                    lineTo(size.width * 0.55f, -size.height * 0.2f)
                    lineTo(size.width, size.height * 0.4f)
                    lineTo(size.width * 0.45f, size.height * 1.2f)
                    lineTo(0f, size.height * 1.2f)
                    close()
                }
                drawPath(
                    path = path,
                    brush = Brush.horizontalGradient(listOf(Color.Black.copy(alpha=0.9f), Color.Black.copy(alpha=0.4f)))
                )
                
                // Red glowing border
                val borderPath = Path().apply {
                    moveTo(size.width * 0.55f, -size.height * 0.2f)
                    lineTo(size.width, size.height * 0.4f)
                    lineTo(size.width * 0.45f, size.height * 1.2f)
                }
                drawPath(path = borderPath, color = RacoRed, style = Stroke(width = 6.dp.toPx()))
                // Outer glow
                drawPath(path = borderPath, color = RacoRed.copy(alpha=0.3f), style = Stroke(width = 16.dp.toPx()))
            }
            .padding(start = 24.dp, top = 24.dp, bottom = 24.dp, end = 48.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Spacer(modifier = Modifier.height(24.dp))
            
            // CPU Monitor
            Column(horizontalAlignment = Alignment.Start, modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = "CPU",
                    color = RacoRed,
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
            

        }
    }
}

@Composable
fun RacoRightPanel() {
    val context = LocalContext.current
    var batteryLevel by remember { mutableStateOf("--") }

    DisposableEffect(context) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                if (level != -1 && scale != -1) {
                    batteryLevel = (level * 100 / scale.toFloat()).toInt().toString()
                }
            }
        }
        context.registerReceiver(receiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
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
                    lineTo(size.width * 0.45f, -size.height * 0.2f)
                    lineTo(0f, size.height * 0.4f)
                    lineTo(size.width * 0.55f, size.height * 1.2f)
                    lineTo(size.width, size.height * 1.2f)
                    close()
                }
                drawPath(
                    path = path,
                    brush = Brush.horizontalGradient(listOf(Color.Black.copy(alpha=0.4f), Color.Black.copy(alpha=0.9f)))
                )
                
                // Red glowing border
                val borderPath = Path().apply {
                    moveTo(size.width * 0.45f, -size.height * 0.2f)
                    lineTo(0f, size.height * 0.4f)
                    lineTo(size.width * 0.55f, size.height * 1.2f)
                }
                drawPath(path = borderPath, color = RacoRed, style = Stroke(width = 6.dp.toPx()))
                // Outer glow
                drawPath(path = borderPath, color = RacoRed.copy(alpha=0.3f), style = Stroke(width = 16.dp.toPx()))
            }
            .padding(start = 48.dp, top = 24.dp, bottom = 24.dp, end = 24.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize(), horizontalAlignment = Alignment.End) {
            AutoSizeText("PROJECT", color = RacoRed, baseFontSize = 28f, fontWeight = FontWeight.Light, letterSpacing = 2.sp)
            AutoSizeText("RACO", color = Color.White, baseFontSize = 28f, fontWeight = FontWeight.Light, letterSpacing = 2.sp)
            Spacer(modifier = Modifier.height(24.dp))
            
            // Battery Monitor
            Column(horizontalAlignment = Alignment.End, modifier = Modifier.fillMaxWidth()) {
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
                
                Spacer(modifier = Modifier.height(8.dp))
            }
            
        }
    }
}

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
