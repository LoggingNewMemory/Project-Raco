/*
 * Project Raco - Performance and Gaming Optimization Suite
 * Copyright (C) 2026 Kanagawa Yamada <albert.wesley.dion@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

package com.kanagawa.yamada.project.raco.gamemode

import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.view.HapticFeedbackConstants
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.snapping.SnapPosition
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BatteryChargingFull
import androidx.compose.material.icons.filled.BatteryStd
import androidx.compose.material.icons.filled.BatterySaver
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.PowerSettingsNew
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Thermostat
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.coerceAtLeast
import androidx.compose.ui.unit.coerceIn
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import com.kanagawa.yamada.project.raco.AppIcon
import com.kanagawa.yamada.project.raco.ExecutionManager
import com.kanagawa.yamada.project.raco.R
import com.kanagawa.yamada.project.raco.tools.BypassCharging
import com.kanagawa.yamada.project.raco.tools.PixelSleepController
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

private const val GAMELIST_PATH = "/data/ProjectRaco/gamelist.txt"
private const val PREFS = "raco_app_config"
private const val PREF_LAST_GAME = "ps4_last_game"


internal data class Ps4Game(val pkg: String, val label: String)

private class LaunchRequest(val game: Ps4Game, val intent: Intent)

private suspend fun runRootCmd(cmd: String): String = withContext(Dispatchers.IO) {
    try {
        val p = ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
        p.outputStream.close()
        val out = p.inputStream.bufferedReader().use { it.readText() }
        p.waitFor()
        out
    } catch (e: Exception) {
        ""
    }
}

/** Reads the Raco game list and keeps only games that are installed and launchable. */
private suspend fun loadGames(context: Context): List<Ps4Game> = withContext(Dispatchers.IO) {
    val raw = runRootCmd("cat $GAMELIST_PATH")
    val pm = context.packageManager
    raw.lines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") }
        .distinct()
        .mapNotNull { pkg ->
            try {
                if (pm.getLaunchIntentForPackage(pkg) == null) {
                    null
                } else {
                    val info = pm.getApplicationInfo(pkg, 0)
                    Ps4Game(pkg, pm.getApplicationLabel(info).toString())
                }
            } catch (e: Exception) {
                null
            }
        }
}


/** Scale of the focused tile, like the enlarged selection on the PS4 home screen. */
private const val FOCUS_SCALE = 1.35f

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun Ps4GameModeScreen(onExit: () -> Unit) {
    val context = LocalContext.current
    val view = LocalView.current
    val prefs = remember { context.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }
    val launchFailedText = stringResource(R.string.ps4_launch_failed)

    var games by remember { mutableStateOf<List<Ps4Game>>(emptyList()) }
    var lastPlayed by remember { mutableStateOf(prefs.getString(PREF_LAST_GAME, "") ?: "") }
    var loading by remember { mutableStateOf(true) }
    var entered by remember { mutableStateOf(false) }
    var showExitDialog by remember { mutableStateOf(false) }
    var panel by remember { mutableStateOf<Ps4Panel?>(null) }
    var lastPanel by remember { mutableStateOf(Ps4Panel.SETTINGS) }
    var launching by remember { mutableStateOf<LaunchRequest?>(null) }

    Ps4WindowSetup()
    Ps4AudioSetup()

    LaunchedEffect(panel) { panel?.let { lastPanel = it } }

    LaunchedEffect(Unit) {
        val list = loadGames(context)
        games = list.sortedWith(
            compareByDescending<Ps4Game> { it.pkg == lastPlayed }.thenBy { it.label.lowercase() }
        )
        loading = false
        delay(120)
        entered = true
    }
    LaunchedEffect(Unit) {
        ExecutionManager.currentMode = ExecutionManager.fetchActiveMode()
    }

    // Back closes the open panel first, then asks to leave Game Mode.
    BackHandler(enabled = launching == null && panel == null) { showExitDialog = true }
    BackHandler(enabled = launching == null && panel != null) { panel = null }

    fun startGame(game: Ps4Game) {
        if (launching != null) return
        val intent = context.packageManager.getLaunchIntentForPackage(game.pkg)
        if (intent == null) {
            Toast.makeText(context, launchFailedText, Toast.LENGTH_SHORT).show()
            return
        }
        prefs.edit().putString(PREF_LAST_GAME, game.pkg).apply()
        lastPlayed = game.pkg
        view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        Ps4Audio.playConfirm()
        launching = LaunchRequest(game, intent)
    }

    BoxWithConstraints(Modifier.fillMaxSize().background(Ps4Colors.Deep)) {
        // Game Mode runs in landscape: phones are only ~360-410dp tall there
        val compact = maxHeight < 480.dp
        val tile = if (compact) ((maxHeight - 230.dp) / 1.62f).coerceIn(60.dp, 88.dp) else 110.dp

        Ps4WaveBackground()

        Column(
            Modifier
                .fillMaxSize()
                .safeDrawingPadding()
        ) {
            Ps4TopBar(
                onPanel = { panel = it },
                onExit = { showExitDialog = true }
            )

            Box(Modifier.weight(1f).fillMaxWidth()) {
                Column(Modifier.fillMaxSize()) {
                    when {
                        loading -> Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp)
                        }
                        games.isEmpty() -> EmptyState(Modifier.weight(1f), onExit = { showExitDialog = true })
                        else -> GameHome(
                            modifier = Modifier.weight(1f),
                            games = games,
                            lastPlayed = lastPlayed,
                            entered = entered,
                            tile = tile,
                            compact = compact,
                            onStart = { startGame(it) }
                        )
                    }
                    ModeBar(compact = compact, enabled = !ExecutionManager.isExecuting && launching == null)
                }

                PanelOverlay(panel = panel, lastPanel = lastPanel, onClose = { panel = null })
            }
        }

        launching?.let { req ->
            LaunchTransition(req = req, onDone = { launching = null })
        }

        if (showExitDialog) {
            AlertDialog(
                onDismissRequest = { showExitDialog = false },
                containerColor = Ps4Colors.DeepAlt,
                titleContentColor = Color.White,
                textContentColor = Color.White.copy(alpha = 0.8f),
                title = { Text(stringResource(R.string.ps4_exit_title)) },
                text = { Text(stringResource(R.string.ps4_exit_desc)) },
                confirmButton = {
                    TextButton(onClick = {
                        showExitDialog = false
                        onExit()
                    }) { Text(stringResource(R.string.ps4_leave), color = Ps4Colors.Accent) }
                },
                dismissButton = {
                    TextButton(onClick = { showExitDialog = false }) {
                        Text(stringResource(R.string.ps4_stay), color = Color.White)
                    }
                }
            )
        }
    }
}

/**
 * Kept in its own function on purpose: called straight inside the Column/Box lambdas, Kotlin would pick
 * ColumnScope.AnimatedVisibility through the outer implicit receiver and refuse to compile.
 */
@Composable
private fun PanelOverlay(panel: Ps4Panel?, lastPanel: Ps4Panel, onClose: () -> Unit) {
    AnimatedVisibility(
        visible = panel != null,
        enter = fadeIn(tween(220)) + slideInVertically(tween(260)) { it / 8 },
        exit = fadeOut(tween(180)) + slideOutVertically(tween(200)) { it / 8 }
    ) {
        Ps4PanelHost(panel = panel ?: lastPanel, onClose = onClose)
    }
}

private fun modeChip(mode: String): Pair<String, Color>? = when (mode) {
    "POWER_SAVE" -> "ECO" to Ps4Colors.Eco
    "BALANCED_PERF" -> "BALANCED" to Ps4Colors.Balanced
    "PERFORMANCE", "GAMING_PRO" -> "AWAKEN" to Ps4Colors.Awaken
    else -> null
}

/**
 * Top status bar like the PS4 home screen: logo + day on the left, live battery / temperature /
 * mode in the middle, function icons (open the settings panels) and the clock on the right.
 */
@Composable
private fun Ps4TopBar(onPanel: (Ps4Panel) -> Unit, onExit: () -> Unit) {
    val context = LocalContext.current
    var time by remember { mutableStateOf("") }
    var day by remember { mutableStateOf("") }
    var level by remember { mutableIntStateOf(-1) }
    var temp by remember { mutableFloatStateOf(0f) }
    var pixelOn by remember { mutableStateOf(false) }
    var bypassOn by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        while (true) {
            val now = java.util.Date()
            time = android.text.format.DateFormat.getTimeFormat(context).format(now)
            day = java.text.SimpleDateFormat("EEEE", java.util.Locale.getDefault()).format(now)
            pixelOn = PixelSleepController.isEnabled(context)
            bypassOn = BypassCharging.isEnabled(context)
            val st = withContext(Dispatchers.IO) { BypassCharging.readStatus(context) }
            level = st.level
            temp = st.tempC
            delay(5000)
        }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(46.dp)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // ---- left: logo + day
        Icon(Icons.Default.SportsEsports, contentDescription = null, tint = Color.White, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(10.dp))
        Text(day, color = Color.White, fontSize = 14.sp)

        Spacer(Modifier.weight(1f))

        // ---- middle: live status
        val chip = modeChip(ExecutionManager.currentMode)
        if (chip != null) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(2.dp))
                    .background(chip.second.copy(alpha = 0.25f))
                    .border(1.dp, chip.second, RoundedCornerShape(2.dp))
                    .padding(horizontal = 8.dp, vertical = 2.dp)
            ) {
                Text(chip.first, color = Color.White, fontSize = 11.sp, letterSpacing = 1.5.sp)
            }
            Spacer(Modifier.width(14.dp))
        }
        Icon(
            if (bypassOn) Icons.Default.BatteryChargingFull else Icons.Default.BatteryStd,
            contentDescription = null,
            tint = if (bypassOn) Ps4Colors.Eco else Color.White,
            modifier = Modifier.size(18.dp)
        )
        Spacer(Modifier.width(4.dp))
        Text(if (level >= 0) "$level%" else "-", color = Color.White, fontSize = 13.sp)
        Spacer(Modifier.width(12.dp))
        Icon(Icons.Default.Thermostat, contentDescription = null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(18.dp))
        Text("${"%.1f".format(temp)}°", color = Color.White, fontSize = 13.sp)

        Spacer(Modifier.weight(1f))

        // ---- right: function icons + clock
        for (p in listOf(Ps4Panel.PIXELSLEEP, Ps4Panel.BYPASS, Ps4Panel.LOOK, Ps4Panel.SETTINGS)) {
            val active = (p == Ps4Panel.PIXELSLEEP && pixelOn) || (p == Ps4Panel.BYPASS && bypassOn)
            IconButton(onClick = { onPanel(p) }, modifier = Modifier.size(38.dp)) {
                Icon(
                    panelIcon(p),
                    contentDescription = panelTitle(p),
                    tint = if (active) Ps4Colors.Accent else Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
        IconButton(onClick = onExit, modifier = Modifier.size(38.dp)) {
            Icon(
                Icons.Default.PowerSettingsNew,
                contentDescription = stringResource(R.string.ps4_exit),
                tint = Color.White,
                modifier = Modifier.size(22.dp)
            )
        }
        Spacer(Modifier.width(8.dp))
        Text(time, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Light)
    }
}

/**
 * Game Mode is a landscape, full-screen (immersive) experience.
 * The original orientation (portrait) and the system bars are restored when leaving.
 */
@Composable
private fun Ps4WindowSetup() {
    val view = LocalView.current
    DisposableEffect(Unit) {
        val activity = view.context.findActivity()
        val window = activity?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        controller?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller?.hide(WindowInsetsCompat.Type.systemBars())
        onDispose {
            controller?.show(WindowInsetsCompat.Type.systemBars())
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }
    }
}

/** Background music for the whole time Game Mode is shown, paused whenever the app leaves the screen. */
@Composable
private fun Ps4AudioSetup() {
    val context = LocalContext.current
    DisposableEffect(Unit) {
        Ps4Audio.startMusic(context)
        val owner = context.findActivity() as? LifecycleOwner
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> Ps4Audio.resumeMusic()
                Lifecycle.Event.ON_STOP -> Ps4Audio.pauseMusic()
                else -> {}
            }
        }
        owner?.lifecycle?.addObserver(observer)
        onDispose {
            owner?.lifecycle?.removeObserver(observer)
            Ps4Audio.stopMusic()
        }
    }
    LaunchedEffect(Unit) { Ps4Audio.playStartup() }
}


/**
 * The PS4 home row: square tiles in one horizontal line, the focused tile is enlarged with a white
 * frame and stays anchored near the left edge while the list scrolls beneath it.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun GameHome(
    modifier: Modifier,
    games: List<Ps4Game>,
    lastPlayed: String,
    entered: Boolean,
    tile: Dp,
    compact: Boolean,
    onStart: (Ps4Game) -> Unit
) {
    val listState = rememberLazyListState()
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    val gap = 10.dp
    val stridePx = with(density) { (tile + gap).toPx() }
    val tilePx = with(density) { tile.toPx() }

    // Fractional index of the item currently sitting at the anchor (0 = first item).
    val focusPos = remember(stridePx, games) {
        derivedStateOf {
            val items = listState.layoutInfo.visibleItemsInfo
            if (items.isEmpty()) {
                0f
            } else {
                val cand = items.lastOrNull { it.offset <= 0 } ?: items.first()
                cand.index + (-cand.offset) / stridePx
            }
        }
    }
    val selectedIndex by remember(games) {
        derivedStateOf { focusPos.value.roundToInt().coerceIn(0, (games.size - 1).coerceAtLeast(0)) }
    }
    val selected = games.getOrNull(selectedIndex)

    LaunchedEffect(games) {
        snapshotFlow { selectedIndex }.drop(1).collect {
            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
            Ps4Audio.playNav()
        }
    }

    BoxWithConstraints(modifier.fillMaxWidth()) {
        val anchor = (maxWidth * 0.10f).coerceIn(28.dp, 120.dp)
        val endPad = (maxWidth - anchor - tile).coerceAtLeast(0.dp)

        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center) {
            LazyRow(
                state = listState,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(tile * 1.65f),
                contentPadding = PaddingValues(start = anchor, end = endPad),
                horizontalArrangement = Arrangement.spacedBy(gap),
                verticalAlignment = Alignment.Top,
                flingBehavior = rememberSnapFlingBehavior(listState, SnapPosition.Start)
            ) {
                itemsIndexed(games, key = { _, g -> g.pkg }) { index, game ->
                    HomeTile(
                        game = game,
                        index = index,
                        tile = tile,
                        tilePx = tilePx,
                        focusPos = focusPos,
                        entered = entered,
                        onClick = {
                            if (index == selectedIndex) {
                                onStart(game)
                            } else {
                                scope.launch { listState.animateScrollToItem(index) }
                            }
                        }
                    )
                }
            }

            Spacer(Modifier.height(if (compact) 2.dp else 10.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = anchor, end = 24.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Crossfade(
                    targetState = selected,
                    animationSpec = tween(220),
                    modifier = Modifier.weight(1f),
                    label = "gameTitle"
                ) { g ->
                    Column(Modifier.height(if (compact) 40.dp else 56.dp), verticalArrangement = Arrangement.Center) {
                        if (g != null) {
                            Text(
                                g.label,
                                color = Color.White,
                                fontSize = if (compact) 20.sp else 24.sp,
                                fontWeight = FontWeight.Light,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            if (g.pkg == lastPlayed && !compact) {
                                Text(
                                    stringResource(R.string.ps4_last_played),
                                    color = Ps4Colors.Accent,
                                    fontSize = 11.sp,
                                    letterSpacing = 2.sp
                                )
                            }
                        }
                    }
                }
                Spacer(Modifier.width(12.dp))
                Row(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.14f))
                        .border(1.dp, Color.White.copy(alpha = 0.5f), CircleShape)
                        .clickable(enabled = selected != null) { selected?.let(onStart) }
                        .padding(start = 8.dp, end = 20.dp, top = 5.dp, bottom = 5.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(26.dp)
                            .clip(CircleShape)
                            .border(1.5.dp, Color.White, CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.Close, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
                    }
                    Spacer(Modifier.width(10.dp))
                    Text(
                        stringResource(R.string.ps4_start),
                        color = Color.White,
                        fontSize = 14.sp,
                        letterSpacing = 3.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun HomeTile(
    game: Ps4Game,
    index: Int,
    tile: Dp,
    tilePx: Float,
    focusPos: State<Float>,
    entered: Boolean,
    onClick: () -> Unit
) {
    val enter by animateFloatAsState(
        targetValue = if (entered) 1f else 0f,
        animationSpec = tween(500, delayMillis = index.coerceAtMost(6) * 60, easing = FastOutSlowInEasing),
        label = "tileEnter"
    )
    val shape = RoundedCornerShape(2.dp)

    Box(
        modifier = Modifier
            .size(tile)
            .graphicsLayer {
                val p = focusPos.value
                val f = (1f - abs(index - p)).coerceIn(0f, 1f)
                val s = 1f + (FOCUS_SCALE - 1f) * f
                transformOrigin = TransformOrigin(0f, 0f)
                scaleX = s
                scaleY = s
                // tiles to the right of the focus move aside by exactly the growth of the focused tile
                translationX = (FOCUS_SCALE - 1f) * tilePx * (index - p).coerceIn(0f, 1f) + (1f - enter) * 120f
                alpha = enter * (0.72f + 0.28f * f)
            }
            .drawBehind {
                val f = (1f - abs(index - focusPos.value)).coerceIn(0f, 1f)
                if (f > 0f) {
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(Ps4Colors.Accent.copy(alpha = 0.45f * f), Color.Transparent),
                            center = center,
                            radius = size.width * 1.1f
                        ),
                        radius = size.width * 1.1f,
                        center = center
                    )
                }
            }
            .clip(shape)
            .drawWithContent {
                drawContent()
                val f = (1f - abs(index - focusPos.value)).coerceIn(0f, 1f)
                if (f > 0f) {
                    drawRect(Color.White.copy(alpha = f), style = Stroke(width = 3.dp.toPx()))
                }
            }
            .clickable { onClick() }
    ) {
        AppIcon(pkg = game.pkg, modifier = Modifier.fillMaxSize())
    }
}

@Composable
private fun ModeBar(compact: Boolean, enabled: Boolean) {
    val current = ExecutionManager.currentMode
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = if (compact) 24.dp else 16.dp)
            .padding(bottom = if (compact) 8.dp else 14.dp, top = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Same mode ids as the in-game Game Assistant: Powersave 2 / Balanced 3 / Awaken 4
        Row(
            Modifier.widthIn(max = 640.dp).fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ModeButton(
                label = "ECO",
                desc = stringResource(R.string.ps4_eco_desc),
                icon = Icons.Default.BatterySaver,
                accent = Ps4Colors.Eco,
                selected = current == "POWER_SAVE",
                enabled = enabled,
                compact = compact,
                modifier = Modifier.weight(1f)
            ) { ExecutionManager.execute("2", "POWER_SAVE") }
            ModeButton(
                label = "BALANCED",
                desc = stringResource(R.string.ps4_balanced_desc),
                icon = Icons.Default.Tune,
                accent = Ps4Colors.Balanced,
                selected = current == "BALANCED_PERF",
                enabled = enabled,
                compact = compact,
                modifier = Modifier.weight(1f)
            ) { ExecutionManager.execute("3", "BALANCED_PERF") }
            ModeButton(
                label = "AWAKEN",
                desc = stringResource(R.string.ps4_awaken_desc),
                icon = Icons.Default.FlashOn,
                accent = Ps4Colors.Awaken,
                selected = current == "PERFORMANCE" || current == "GAMING_PRO",
                enabled = enabled,
                compact = compact,
                modifier = Modifier.weight(1f)
            ) { ExecutionManager.execute("4", "PERFORMANCE") }
        }
    }
}

@Composable
private fun ModeButton(
    label: String,
    desc: String,
    icon: ImageVector,
    accent: Color,
    selected: Boolean,
    enabled: Boolean,
    compact: Boolean,
    modifier: Modifier,
    onClick: () -> Unit
) {
    // square-ish PS4 tile look: dark blue body, white frame when selected
    val shape = RoundedCornerShape(2.dp)
    val bg = if (selected) accent.copy(alpha = 0.30f) else Ps4Colors.Mid.copy(alpha = 0.55f)
    val borderColor = if (selected) Color.White else Color.White.copy(alpha = 0.18f)
    val iconTint = if (selected) Color.White else accent
    val base = modifier
        .clip(shape)
        .background(bg)
        .border(if (selected) 2.dp else 1.dp, borderColor, shape)
        .clickable(enabled = enabled) { onClick() }

    if (compact) {
        Row(
            modifier = base.padding(vertical = 10.dp, horizontal = 8.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text(
                label,
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                letterSpacing = 1.5.sp,
                maxLines = 1
            )
        }
    } else {
        Column(
            modifier = base.padding(vertical = 14.dp, horizontal = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(26.dp))
            Spacer(Modifier.height(8.dp))
            Text(
                label,
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                letterSpacing = 1.5.sp,
                maxLines = 1
            )
            Spacer(Modifier.height(2.dp))
            Text(
                desc,
                color = Color.White.copy(alpha = 0.65f),
                fontSize = 10.sp,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun EmptyState(modifier: Modifier, onExit: () -> Unit) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 36.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.SportsEsports,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.5f),
            modifier = Modifier.size(72.dp)
        )
        Spacer(Modifier.height(20.dp))
        Text(
            stringResource(R.string.ps4_no_games_title),
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.Light,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.ps4_no_games_desc),
            color = Color.White.copy(alpha = 0.7f),
            fontSize = 14.sp,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = onExit,
            colors = ButtonDefaults.buttonColors(containerColor = Ps4Colors.Bright, contentColor = Color.White)
        ) { Text(stringResource(R.string.ps4_exit)) }
    }
}

/**
 * PS4-like "starting application" sequence: the screen dims into blue, a shockwave
 * ring expands from the game icon, a thin progress line fills, then a white flash
 * hands over to the game.
 */
@Composable
private fun LaunchTransition(req: LaunchRequest, onDone: () -> Unit) {
    val context = LocalContext.current
    val burst = remember { Animatable(0f) }
    val progress = remember { Animatable(0f) }
    val flash = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        Ps4Audio.playLaunch()
        launch { burst.animateTo(1f, tween(900, easing = FastOutSlowInEasing)) }
        progress.animateTo(1f, tween(1400, easing = FastOutSlowInEasing))
        flash.animateTo(1f, tween(160))
        Ps4Audio.pauseMusic()
        try {
            context.startActivity(req.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            // ignore, the overlay is dismissed below either way
        }
        delay(700)
        onDone()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Ps4Colors.Deep.copy(alpha = 0.94f * (burst.value * 3f).coerceAtMost(1f)))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = {}
            ),
        contentAlignment = Alignment.Center
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val c = Offset(size.width / 2f, size.height / 2f)
            val maxR = max(size.width, size.height) * 0.75f
            drawCircle(
                color = Color.White.copy(alpha = (1f - burst.value) * 0.6f),
                radius = burst.value * maxR,
                center = c,
                style = Stroke(width = 4.dp.toPx())
            )
            drawCircle(
                brush = Brush.radialGradient(
                    listOf(Ps4Colors.Bright.copy(alpha = 0.45f), Color.Transparent),
                    center = c,
                    radius = size.width * 0.9f
                ),
                radius = size.width * 0.9f,
                center = c
            )
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .size(130.dp)
                    .graphicsLayer {
                        val s = 0.7f + 0.3f * burst.value + 0.1f * progress.value
                        scaleX = s
                        scaleY = s
                        alpha = burst.value
                    }
                    .clip(RoundedCornerShape(30.dp))
                    .border(3.dp, Color.White, RoundedCornerShape(30.dp))
            ) {
                AppIcon(pkg = req.game.pkg, modifier = Modifier.fillMaxSize())
            }
            Spacer(Modifier.height(16.dp))
            Text(
                text = req.game.label,
                color = Color.White,
                fontSize = 24.sp,
                fontWeight = FontWeight.Light,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .padding(horizontal = 32.dp)
                    .alpha(burst.value)
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = stringResource(R.string.ps4_starting),
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 12.sp,
                letterSpacing = 3.sp,
                modifier = Modifier.alpha(burst.value)
            )
            Spacer(Modifier.height(14.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.4f)
                    .height(3.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.18f))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(progress.value.coerceIn(0f, 1f))
                        .height(3.dp)
                        .clip(CircleShape)
                        .background(Color.White)
                )
            }
        }

        Box(
            Modifier
                .fillMaxSize()
                .background(Color.White.copy(alpha = flash.value))
        )
    }
}
