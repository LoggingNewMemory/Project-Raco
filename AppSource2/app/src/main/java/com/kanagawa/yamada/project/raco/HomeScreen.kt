/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada
This program is free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program.

If not, see https://www.gnu.org/licenses/.
*/

package com.kanagawa.yamada.project.raco

import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.BlurMaskFilter
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.BatteryManager
import android.os.Build
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// ── Models ─────────────────────────────────────────────────────────────

enum class PerfMode(val color: Color, val title: String) {
    AWAKEN(Color(0xFFE53935), "Awaken"),
    BALANCED(Color(0xFFFFD600), "Balanced"),
    POWERSAVE(Color(0xFF00E676), "Powersave")
}

data class Game(
    val name: String,
    val packageName: String,
    val durationPlayed: String,
    val icon: ImageBitmap?,
    val lastTimeUsed: Long = 0L
)

// ── Main Screen ────────────────────────────────────────────────────────

@Composable
fun HomeScreen() {
    val context = LocalContext.current

    val gilmerBold = remember {
        FontFamily(androidx.compose.ui.text.font.Typeface(android.graphics.Typeface.createFromAsset(context.assets, "GilmerBold.otf")))
    }
    val gilmerRegular = remember {
        FontFamily(androidx.compose.ui.text.font.Typeface(android.graphics.Typeface.createFromAsset(context.assets, "GilmerRegular.otf")))
    }

    // State
    var currentMode by remember { mutableStateOf(PerfMode.AWAKEN) }
    var showPerfMenu by remember { mutableStateOf(false) }
    var selectedGameIndex by remember { mutableIntStateOf(0) }
    var showAppPicker by remember { mutableStateOf(false) }
    var listRefreshTrigger by remember { mutableIntStateOf(0) } // Used to re-trigger the games fetch

    // Live Data
    val currentTime by rememberCurrentTime()
    val batteryLevel by rememberBatteryLevel(context)
    val installedGames by rememberInstalledGames(context, listRefreshTrigger)

    if (installedGames.isNotEmpty() && selectedGameIndex >= installedGames.size) {
        selectedGameIndex = 0
    }

    // Smooth UI Color Transitions
    val animatedAccentColor by animateColorAsState(
        targetValue = currentMode.color,
        animationSpec = tween(durationMillis = 400),
        label = "AccentColorAnim"
    )

    // Right Pane Background perfectly clear transparent to allow the blurred icon to bleed edge-to-edge
    val rightPaneColor by animateColorAsState(if (showPerfMenu) Color(0xFF0A0A0A) else Color.Transparent, label = "RightPaneColor")
    val lineAlpha by animateFloatAsState(if (showPerfMenu) 0f else 1f, label = "LineAlpha")
    var activeGradientMode by remember { mutableStateOf(currentMode) }
    val lineSlideProgress = remember { Animatable(1f) }

    LaunchedEffect(showPerfMenu) {
        if (!showPerfMenu) {
            activeGradientMode = currentMode
            lineSlideProgress.snapTo(0f)
            lineSlideProgress.animateTo(1f, tween(durationMillis = 600, easing = FastOutSlowInEasing))
        }
    }

    Box(
        modifier = Modifier.fillMaxSize().background(Color(0xFF0A0A0A))
    ) {
        // Background Diagonal Line
        Canvas(modifier = Modifier.fillMaxSize().clipToBounds()) {
            val splitStart = size.width * 0.70f
            val splitEnd = size.width * 0.45f

            val path = Path().apply {
                moveTo(splitStart, 0f)
                lineTo(size.width, 0f)
                lineTo(size.width, size.height)
                lineTo(splitEnd, size.height)
                close()
            }

            drawPath(path, rightPaneColor)

            if (lineAlpha > 0f) {
                drawLine(Color.White.copy(alpha = lineAlpha), Offset(splitStart, 0f), Offset(splitEnd, size.height), 6.dp.toPx())

                if (lineSlideProgress.value > 0f) {
                    clipRect(top = size.height * (1f - lineSlideProgress.value), bottom = size.height, left = 0f, right = size.width) {
                        drawLine(
                            brush = Brush.linearGradient(
                                listOf(activeGradientMode.color.copy(alpha = lineAlpha), Color.White.copy(alpha = lineAlpha)),
                                start = Offset(splitStart, 0f), end = Offset(splitEnd, size.height)
                            ),
                            start = Offset(splitStart, 0f), end = Offset(splitEnd, size.height), strokeWidth = 6.dp.toPx()
                        )
                    }
                }
            }
        }

        // Foreground UI Overlay
        Box(
            modifier = Modifier.fillMaxSize()
        ) {
            // LEFT PANE (Adaptive Hide - Dynamically clipped by background line coordinates)
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .drawWithContent {
                        val margin = 24.dp.toPx() // Gap to ensure text visually respects the line
                        val splitStart = size.width * 0.70f - margin
                        val splitEnd = size.width * 0.45f - margin

                        // Creating a matching boundary path
                        val path = Path().apply {
                            moveTo(0f, 0f)
                            lineTo(splitStart, 0f)
                            lineTo(splitEnd, size.height)
                            lineTo(0f, size.height)
                            close()
                        }

                        // Adaptively hide content exactly at the line margin
                        clipPath(path) {
                            this@drawWithContent.drawContent()
                        }
                    }
                    .displayCutoutPadding()
                    .padding(start = 24.dp, top = 24.dp, bottom = 24.dp)
            ) {
                Text(
                    text = buildAnnotatedString {
                        withStyle(style = SpanStyle(color = animatedAccentColor)) { append("PROJECT ") }
                        withStyle(style = SpanStyle(color = Color.White)) { append("RACO") }
                    },
                    fontFamily = gilmerBold, fontSize = 34.sp, letterSpacing = 2.sp
                )

                Text("$currentTime • $batteryLevel%", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(bottom = 16.dp, top = 4.dp))

                if (installedGames.isEmpty()) {
                    // ── EMPTY STATE ──
                    Column(modifier = Modifier.padding(top = 16.dp)) {
                        Text("Empty Here.\nAdd Some Games.", color = Color.Gray, fontFamily = gilmerRegular, fontSize = 20.sp, modifier = Modifier.padding(bottom = 16.dp))
                        Button(
                            onClick = { showAppPicker = true },
                            colors = ButtonDefaults.buttonColors(containerColor = Color.DarkGray),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Icon(Icons.Default.Add, contentDescription = "Add", tint = Color.White)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Add Game", color = Color.White)
                        }
                    }
                } else {
                    // ── GAME LIST ──
                    LazyColumn(
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        contentPadding = PaddingValues(vertical = 16.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(installedGames.size) { index ->
                            GameListItem(
                                game = installedGames[index],
                                isSelected = index == selectedGameIndex,
                                accentColor = animatedAccentColor,
                                onClick = { selectedGameIndex = index }
                            )
                        }
                        // Add Game List Item at the bottom
                        item {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxWidth(0.55f) // Restrict to left half so touch doesn't overlap the right pane
                                    .clickable { showAppPicker = true }
                                    .padding(vertical = 4.dp)
                            ) {
                                Box(
                                    modifier = Modifier.size(64.dp).border(2.dp, Color.DarkGray, RoundedCornerShape(8.dp)).background(Color.Transparent, RoundedCornerShape(8.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(Icons.Default.Add, contentDescription = "Add", tint = Color.LightGray, modifier = Modifier.size(32.dp))
                                }
                                Text("Add Game", color = Color.LightGray, fontSize = 18.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(start = 16.dp))
                            }
                        }
                    }
                }
            }

            // RIGHT PANE: (Adaptive Hide - Dynamically clipped by background line coordinates)
            // REMOVED displayCutoutPadding and normal padding from here so the background image touches the literal screen edges.
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .drawWithContent {
                        val margin = 24.dp.toPx()
                        val splitStart = size.width * 0.70f + margin
                        val splitEnd = size.width * 0.45f + margin

                        val path = Path().apply {
                            moveTo(splitStart, 0f)
                            lineTo(size.width, 0f)
                            lineTo(size.width, size.height)
                            lineTo(splitEnd, size.height)
                            close()
                        }

                        clipPath(path) {
                            this@drawWithContent.drawContent()
                        }
                    }
            ) {
                if (!showPerfMenu) {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = "Settings",
                        tint = Color.White,
                        // Placed padding directly on the icon instead of the container
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .displayCutoutPadding()
                            .padding(end = 24.dp, top = 24.dp)
                            .size(28.dp)
                            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { showPerfMenu = true }
                    )
                }

                Crossfade(targetState = showPerfMenu, modifier = Modifier.fillMaxSize(), label = "SettingsCrossfade") { isSettings ->
                    if (isSettings) {
                        Box(
                            modifier = Modifier.fillMaxSize().pointerInput(Unit) {
                                detectHorizontalDragGestures { change, dragAmount ->
                                    if (dragAmount > 20f) { showPerfMenu = false; change.consume() }
                                }
                            }
                        ) {
                            Column(
                                horizontalAlignment = Alignment.End,
                                modifier = Modifier
                                    .align(Alignment.CenterEnd)
                                    .displayCutoutPadding()
                                    .padding(end = 24.dp) // Padded the settings menu
                            ) {
                                Column(horizontalAlignment = Alignment.End) {
                                    Text("Performance", color = Color.White, fontFamily = gilmerRegular, fontSize = 36.sp)
                                    Text("Settings", color = Color.White, fontFamily = gilmerRegular, fontSize = 36.sp)
                                }
                                Spacer(modifier = Modifier.height(48.dp))
                                PerfMode.entries.forEach { mode ->
                                    val isSelected = currentMode == mode
                                    Text(
                                        text = mode.title, color = Color.White, fontFamily = if (isSelected) gilmerBold else gilmerRegular, fontSize = 28.sp,
                                        modifier = Modifier.padding(vertical = 12.dp).clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { currentMode = mode }
                                    )
                                }
                            }
                        }
                    } else {
                        Box(modifier = Modifier.fillMaxSize()) {
                            if (installedGames.isNotEmpty()) {
                                val activeGame = installedGames[selectedGameIndex]

                                AnimatedContent(
                                    targetState = activeGame,
                                    transitionSpec = {
                                        (fadeIn(animationSpec = tween(400)) + slideInVertically(tween(400)) { 40 }).togetherWith(
                                            fadeOut(animationSpec = tween(400)) + slideOutVertically(tween(400)) { -40 }
                                        ).using(
                                            SizeTransform(clip = false)
                                        )
                                    },
                                    modifier = Modifier.fillMaxSize(),
                                    label = "GameDetailsAnimation"
                                ) { game ->
                                    Box(modifier = Modifier.fillMaxSize()) {

                                        // ── Edge-to-Edge Animated Game Icon Background ──
                                        val infiniteTransition = rememberInfiniteTransition(label = "bgIconAnim")
                                        val animProgress by infiniteTransition.animateFloat(
                                            initialValue = 0f,
                                            targetValue = 1f,
                                            animationSpec = infiniteRepeatable(
                                                animation = tween(15000, easing = FastOutSlowInEasing),
                                                repeatMode = RepeatMode.Reverse
                                            ),
                                            label = "progress"
                                        )

                                        val offsetY = 100f - (animProgress * 200f)

                                        if (game.icon != null) {
                                            Image(
                                                bitmap = game.icon,
                                                contentDescription = "Animated Background",
                                                contentScale = ContentScale.Crop,
                                                filterQuality = androidx.compose.ui.graphics.FilterQuality.High,
                                                modifier = Modifier
                                                    .fillMaxSize()
                                                    .scale(2.0f) // Extreme 2.0x scale prevents bounds clipping during movement
                                                    .offset(y = offsetY.dp)
                                                    .alpha(0.35f)
                                                    .blur(48.dp)
                                            )
                                        }

                                        // ── Foreground Content ──
                                        Column(
                                            horizontalAlignment = Alignment.End,
                                            modifier = Modifier
                                                .fillMaxWidth(0.7f)
                                                .align(Alignment.BottomEnd)
                                                .displayCutoutPadding()
                                                .padding(end = 24.dp, bottom = 24.dp) // Padding safely reapplied to the text/buttons
                                        ) {

                                            val tickerText = remember(game.name) {
                                                Array(10) { game.name }.joinToString("      •      ")
                                            }

                                            Text(
                                                text = tickerText,
                                                color = Color.White,
                                                fontSize = 34.sp,
                                                fontWeight = FontWeight.Bold,
                                                maxLines = 1,
                                                modifier = Modifier
                                                    .padding(bottom = 24.dp)
                                                    .basicMarquee(
                                                        iterations = Int.MAX_VALUE,
                                                        velocity = 40.dp
                                                    )
                                            )
                                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                                Box(
                                                    modifier = Modifier.size(56.dp).border(2.dp, animatedAccentColor, RoundedCornerShape(8.dp)).background(Color.Black, RoundedCornerShape(8.dp)).clickable { showPerfMenu = true },
                                                    contentAlignment = Alignment.Center
                                                ) { Text("III", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp) }
                                                Button(
                                                    onClick = {
                                                        val intent = context.packageManager.getLaunchIntentForPackage(game.packageName)
                                                        if (intent != null) { intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); context.startActivity(intent) }
                                                    },
                                                    colors = ButtonDefaults.buttonColors(containerColor = Color.Black), shape = RoundedCornerShape(8.dp),
                                                    modifier = Modifier.height(56.dp).width(160.dp).border(2.dp, animatedAccentColor, RoundedCornerShape(8.dp))
                                                ) { Text("ENTER", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp) }
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

        // Launch Full Screen App Picker Over UI with Slide + Fade Transition
        AnimatedVisibility(
            visible = showAppPicker,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
            modifier = Modifier.fillMaxSize()
        ) {
            GamePickerScreen(
                onBack = {
                    showAppPicker = false
                    listRefreshTrigger++ // Forces the game list to refresh when returning
                }
            )
        }
    }
}

// ── Components ─────────────────────────────────────────────────────────

@Composable
fun GameListItem(game: Game, isSelected: Boolean, accentColor: Color, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth(0.55f) // Restrict width to the left half so the invisible touch target doesn't block the right pane
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClick)
            .padding(vertical = 4.dp)
    ) {
        Box(
            modifier = Modifier.size(64.dp).then(if (isSelected) Modifier.neonGlow(accentColor, 16.dp) else Modifier).background(Color.DarkGray, RoundedCornerShape(8.dp))
        ) {
            if (game.icon != null) {
                Image(
                    bitmap = game.icon,
                    contentDescription = game.name,
                    contentScale = ContentScale.Crop, // Crops down to exact Box bounds
                    modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(8.dp))
                )
            }
        }
        Column(modifier = Modifier.padding(start = 16.dp).weight(1f)) {
            Text(
                text = game.name,
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Visible // Allows the text to draw OUTSIDE the 0.55f width boundary so it can reach the diagonal line
            )

            // Only show time played when this game is selected
            AnimatedVisibility(
                visible = isSelected,
                enter = expandVertically() + fadeIn(),
                exit = shrinkVertically() + fadeOut()
            ) {
                Text(
                    text = game.durationPlayed,
                    color = Color.LightGray,
                    fontSize = 14.sp,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }
    }
}

fun Modifier.neonGlow(color: Color, radius: Dp = 8.dp) = this.drawBehind {
    drawIntoCanvas { canvas ->
        val paint = Paint()
        val frameworkPaint = paint.asFrameworkPaint()
        frameworkPaint.color = color.toArgb()
        frameworkPaint.maskFilter = BlurMaskFilter(radius.toPx(), BlurMaskFilter.Blur.NORMAL)
        canvas.drawRoundRect(0f, 0f, size.width, size.height, 8.dp.toPx(), 8.dp.toPx(), paint)
    }
}

// ── Background Data Loaders ─────────────────────────────────────────────

@Composable
fun rememberInstalledGames(context: Context, refreshTrigger: Int): State<List<Game>> {
    val gamesState = remember { mutableStateOf(emptyList<Game>()) }

    LaunchedEffect(refreshTrigger) {
        withContext(Dispatchers.IO) {
            val pm = context.packageManager
            val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
            val customGames = GameManager.getManuallyAddedGames(context)
            val hiddenGames = GameManager.getHiddenGames(context)

            val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val timeNow = System.currentTimeMillis()
            val thirtyDaysAgo = timeNow - 1000L * 60 * 60 * 24 * 30
            val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_MONTHLY, thirtyDaysAgo, timeNow).associateBy { it.packageName }

            val gameList = mutableListOf<Game>()
            for (app in apps) {
                val isAndroidGame = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    app.category == ApplicationInfo.CATEGORY_GAME
                } else {
                    @Suppress("DEPRECATION")
                    (app.flags and ApplicationInfo.FLAG_IS_GAME) != 0
                }

                // Show it if it's explicitly added, OR if it's an auto-detected game that hasn't been explicitly hidden
                if ((isAndroidGame && !hiddenGames.contains(app.packageName)) || customGames.contains(app.packageName)) {
                    val name = app.loadLabel(pm).toString()
                    val packageName = app.packageName
                    val iconBitmap = drawableToImageBitmap(app.loadIcon(pm))
                    val totalTime = stats[packageName]?.totalTimeInForeground ?: 0L
                    val lastUsed = stats[packageName]?.lastTimeUsed ?: 0L // Extract last used time for sorting
                    val durationStr = if (totalTime > 0) formatDuration(totalTime) else "0 mins played"

                    gameList.add(Game(name, packageName, durationStr, iconBitmap, lastUsed))
                }
            }
            // Sort by last time used in descending order (most recent first)
            gamesState.value = gameList.sortedByDescending { it.lastTimeUsed }
        }
    }
    return gamesState
}

fun formatDuration(millis: Long): String {
    val hours = millis / (1000 * 60 * 60)
    val minutes = (millis % (1000 * 60 * 60)) / (1000 * 60)
    return if (hours > 0) "$hours hrs $minutes mins played" else "$minutes mins played"
}

// Fixed the root cause of Blurry background icons by extracting vector files into a massive 1024x1024 base canvas size!
fun drawableToImageBitmap(drawable: Drawable): ImageBitmap? {
    try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && drawable is android.graphics.drawable.AdaptiveIconDrawable) {
            val size = 1024 // Massively increased from 256 for perfectly sharp Full-Screen Backgrounds
            val bitmap = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bitmap)

            // Draw the unmasked background and foreground full-bleed
            drawable.background?.apply {
                setBounds(0, 0, size, size)
                draw(canvas)
            }
            drawable.foreground?.apply {
                setBounds(0, 0, size, size)
                draw(canvas)
            }
            return bitmap.asImageBitmap()
        }

        // Fallback for older legacy icons
        if (drawable is BitmapDrawable && drawable.bitmap != null) return drawable.bitmap.asImageBitmap()

        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth.coerceAtLeast(1024) else 1024
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight.coerceAtLeast(1024) else 1024
        val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap.asImageBitmap()
    } catch (e: Exception) { return null }
}

@Composable
fun rememberCurrentTime(): State<String> {
    val time = remember { mutableStateOf("") }
    LaunchedEffect(Unit) {
        val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
        while (true) { time.value = sdf.format(Date()); delay(1000) }
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
                if (level != -1 && scale != -1) batteryLevel.intValue = (level * 100 / scale.toFloat()).toInt()
            }
        }
        context.registerReceiver(receiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        onDispose { context.unregisterReceiver(receiver) }
    }
    return batteryLevel
}