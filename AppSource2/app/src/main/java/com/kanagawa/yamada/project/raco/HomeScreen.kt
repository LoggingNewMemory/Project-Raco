package com.kanagawa.yamada.project.raco

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// ── Models ─────────────────────────────────────────────────────────────

enum class PerfMode(val color: Color, val title: String) {
    AWAKEN(Color(0xFFE53935), "Awaken"),
    BALANCED(Color(0xFFFFD600), "Balanced"),
    POWERSAVE(Color(0xFF00E676), "Powersave")
}

// ── Main Screen ────────────────────────────────────────────────────────

@Composable
fun HomeScreen() {
    val context = LocalContext.current

    // ── Fonts ────────────────────────────────────────────────────────────
    val gilmerBold = remember {
        FontFamily(
            androidx.compose.ui.text.font.Typeface(
                android.graphics.Typeface.createFromAsset(context.assets, "GilmerBold.otf")
            )
        )
    }
    val gilmerRegular = remember {
        FontFamily(
            androidx.compose.ui.text.font.Typeface(
                android.graphics.Typeface.createFromAsset(context.assets, "GilmerRegular.otf")
            )
        )
    }

    // State
    var currentMode by remember { mutableStateOf(PerfMode.AWAKEN) }
    var showPerfMenu by remember { mutableStateOf(false) }

    // Live Data
    val currentTime by rememberCurrentTime()
    val batteryLevel by rememberBatteryLevel(context)

    // ── Animations for the Background Transition ──
    val rightPaneColor by animateColorAsState(
        targetValue = if (showPerfMenu) Color(0xFF0A0A0A) else Color(0xFF242424),
        label = "RightPaneColor"
    )
    val lineAlpha by animateFloatAsState(
        targetValue = if (showPerfMenu) 0f else 1f,
        label = "LineAlpha"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A0A))
    ) {
        // ── Background Diagonal Canvas ──
        Canvas(modifier = Modifier.fillMaxSize().clipToBounds()) {
            val splitStart = size.width * 0.70f // Shifted right to ~70% of screen width
            val splitEnd = size.width * 0.45f   // Shifted right to ~45% to align with the list

            val path = Path().apply {
                moveTo(splitStart, 0f)
                lineTo(size.width, 0f)
                lineTo(size.width, size.height)
                lineTo(splitEnd, size.height)
                close()
            }

            // Dark Grey right pane (fades to Black when settings are open)
            drawPath(path, rightPaneColor)

            // The colored accent line (Gradient from Performance Color to White)
            if (lineAlpha > 0f) {
                drawLine(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            currentMode.color.copy(alpha = lineAlpha),
                            Color.White.copy(alpha = lineAlpha)
                        ),
                        start = Offset(splitStart, 0f),
                        end = Offset(splitEnd, size.height)
                    ),
                    start = Offset(splitStart, 0f),
                    end = Offset(splitEnd, size.height),
                    strokeWidth = 6.dp.toPx() // You can also increase this to 8.dp.toPx() if you want a thicker line
                )
            }
        }

        // ── Foreground UI ──
        Row(
            modifier = Modifier
                .fillMaxSize()
                .displayCutoutPadding() // Auto Notch Avoider
                .padding(24.dp)
        ) {
            // LEFT PANE: Info & Game List
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
            ) {
                // Header
                Text(
                    text = buildAnnotatedString {
                        withStyle(style = SpanStyle(color = currentMode.color)) { append("PROJECT ") }
                        withStyle(style = SpanStyle(color = Color.White)) { append("RACO") }
                    },
                    fontFamily = gilmerBold,
                    fontSize = 34.sp,
                    letterSpacing = 2.sp
                )

                // Real-time Clock and Battery
                Text(
                    text = "$currentTime • $batteryLevel%",
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 32.dp, top = 4.dp)
                )

                // Game List
                LazyColumn(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    items(4) { index ->
                        GameListItemStub(
                            isSelected = index == 0, // First item is highlighted in mockup
                            accentColor = currentMode.color
                        )
                    }
                    item {
                        Text(
                            text = "Add Game",
                            color = Color.White,
                            fontWeight = FontWeight.Medium,
                            fontSize = 16.sp,
                            modifier = Modifier.padding(top = 12.dp, start = 8.dp)
                        )
                    }
                }
            }

            // RIGHT PANE: Detail or Settings
            Box(
                modifier = Modifier
                    .weight(1.2f)
                    .fillMaxHeight()
            ) {
                // Settings Icon (Top Right) - Only show if perf menu is closed
                if (!showPerfMenu) {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = "Settings",
                        tint = Color.White,
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .size(28.dp)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null
                            ) {
                                // Toggle standard settings menu
                            }
                    )
                }

                // Crossfade between Game Details and Performance Settings
                Crossfade(
                    targetState = showPerfMenu,
                    modifier = Modifier.fillMaxSize()
                ) { isSettings ->
                    if (isSettings) {
                        // ── Performance Settings Menu ──
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .pointerInput(Unit) {
                                    // Detect horizontal swipe to close
                                    detectHorizontalDragGestures { change, dragAmount ->
                                        if (dragAmount > 20f) { // Positive dragAmount means swiping right
                                            showPerfMenu = false
                                            change.consume()
                                        }
                                    }
                                }
                        ) {
                            Column(
                                horizontalAlignment = Alignment.End,
                                modifier = Modifier.align(Alignment.CenterEnd)
                            ) {
                                // Title Block
                                Column(horizontalAlignment = Alignment.End) {
                                    Text(
                                        text = "Performance",
                                        color = Color.White,
                                        fontFamily = gilmerRegular,
                                        fontSize = 36.sp
                                    )
                                    Text(
                                        text = "Settings",
                                        color = Color.White,
                                        fontFamily = gilmerRegular,
                                        fontSize = 36.sp
                                    )
                                }

                                Spacer(modifier = Modifier.height(48.dp))

                                // Modes Block
                                PerfMode.values().forEach { mode ->
                                    val isSelected = currentMode == mode
                                    Text(
                                        text = mode.title,
                                        color = Color.White,
                                        fontFamily = if (isSelected) gilmerBold else gilmerRegular,
                                        fontSize = 28.sp,
                                        modifier = Modifier
                                            .padding(vertical = 12.dp)
                                            .clickable(
                                                interactionSource = remember { MutableInteractionSource() },
                                                indication = null
                                            ) {
                                                currentMode = mode
                                            }
                                    )
                                }
                            }
                        }
                    } else {
                        // ── Game Detail View ──
                        Box(modifier = Modifier.fillMaxSize()) {
                            Column(
                                horizontalAlignment = Alignment.End,
                                modifier = Modifier.align(Alignment.BottomEnd)
                            ) {
                                Text(
                                    text = "[Game Name]",
                                    color = Color.White,
                                    fontSize = 34.sp,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.padding(bottom = 24.dp)
                                )

                                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                    // Performance Menu Trigger (III)
                                    Box(
                                        modifier = Modifier
                                            .size(56.dp)
                                            .border(2.dp, currentMode.color, RoundedCornerShape(8.dp))
                                            .background(Color.Black, RoundedCornerShape(8.dp))
                                            .clickable { showPerfMenu = true },
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text("III", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                                    }

                                    // ENTER Button
                                    Button(
                                        onClick = { /* Launch Game via Daemon */ },
                                        colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
                                        shape = RoundedCornerShape(8.dp),
                                        modifier = Modifier
                                            .height(56.dp)
                                            .width(160.dp)
                                            .border(2.dp, currentMode.color, RoundedCornerShape(8.dp))
                                    ) {
                                        Text("ENTER", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp)
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

// ── Components & Helpers ───────────────────────────────────────────────

@Composable
fun GameListItemStub(isSelected: Boolean, accentColor: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        // Icon Box with Drop Shadow for glow effect
        Box(
            modifier = Modifier
                .size(64.dp)
                .then(
                    if (isSelected) {
                        Modifier.shadow(
                            elevation = 20.dp, // High elevation creates the soft spread
                            shape = RoundedCornerShape(8.dp),
                            ambientColor = accentColor,
                            spotColor = accentColor
                        )
                    } else {
                        Modifier
                    }
                )
                .background(Color.White, RoundedCornerShape(8.dp))
        )
        // Text Column
        Column(modifier = Modifier.padding(start = 16.dp)) {
            Text("[Game Name]", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Medium)
            Text("[Duration Played]", color = Color.LightGray, fontSize = 14.sp)
        }
    }
}

@Composable
fun rememberCurrentTime(): State<String> {
    val time = remember { mutableStateOf("") }
    LaunchedEffect(Unit) {
        val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
        while (true) {
            time.value = sdf.format(Date())
            delay(1000)
        }
    }
    return time
}

@Composable
fun rememberBatteryLevel(context: Context): State<Int> {
    val batteryLevel = remember { mutableIntStateOf(100) }
    DisposableEffect(context) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                if (level != -1 && scale != -1) {
                    batteryLevel.intValue = (level * 100 / scale.toFloat()).toInt()
                }
            }
        }
        context.registerReceiver(receiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        onDispose { context.unregisterReceiver(receiver) }
    }
    return batteryLevel
}