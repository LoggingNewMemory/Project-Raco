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

import android.os.SystemClock
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.BatterySaver
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.RocketLaunch
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kanagawa.yamada.project.raco.ExecutionManager
import com.kanagawa.yamada.project.raco.R
import kotlinx.coroutines.delay

internal data class ModeStyle(
    val name: String,
    val accent: Color,
    val icon: ImageVector,
    val descRes: Int
)

/** Maps the raco mode id (the argument given to the native binary) to its overlay look. */
internal fun modeStyleFor(modeId: String): ModeStyle? = when (modeId) {
    "2" -> ModeStyle("ECO", Ps4Colors.Eco, Icons.Default.BatterySaver, R.string.ps4_eco_desc)
    "3" -> ModeStyle("BALANCED", Ps4Colors.Balanced, Icons.Default.Tune, R.string.ps4_balanced_desc)
    "1" -> ModeStyle("BALANCED", Ps4Colors.Balanced, Icons.Default.Tune, R.string.ps4_balanced_desc)
    "4" -> ModeStyle("AWAKEN", Ps4Colors.Awaken, Icons.Default.FlashOn, R.string.ps4_awaken_desc)
    "5" -> ModeStyle("GAMING PRO", Ps4Colors.Awaken, Icons.Default.RocketLaunch, R.string.ps4_awaken_desc)
    "6" -> ModeStyle("COOLDOWN", Ps4Colors.Accent, Icons.Default.AcUnit, R.string.ps4_balanced_desc)
    "7" -> ModeStyle("RESET", Ps4Colors.Accent, Icons.Default.Refresh, R.string.ps4_balanced_desc)
    else -> null
}

internal enum class OverlayResult { APPLYING, DONE, FAILED }

private const val MIN_VISIBLE_MS = 1500L

/**
 * Full-screen animated overlay shown while Raco applies ECO / BALANCED / AWAKEN.
 * It listens to [ExecutionManager], so it reacts no matter where the switch was triggered.
 */
@Composable
fun ModeSwitchOverlay(enabled: Boolean) {
    var visible by remember { mutableStateOf(false) }
    var style by remember { mutableStateOf<ModeStyle?>(null) }
    var result by remember { mutableStateOf(OverlayResult.APPLYING) }
    var shownAt by remember { mutableStateOf(0L) }

    val executing = ExecutionManager.isExecuting
    val executingMode = ExecutionManager.executingMode
    val context = LocalContext.current

    LaunchedEffect(executing, executingMode, enabled) {
        if (!enabled) {
            visible = false
            return@LaunchedEffect
        }
        if (executing) {
            val s = modeStyleFor(executingMode)
            if (s != null) {
                style = s
                result = OverlayResult.APPLYING
                if (!visible) shownAt = SystemClock.uptimeMillis()
                visible = true
                Ps4Audio.init(context)
                Ps4Audio.playMode(executingMode)
            }
        } else if (visible) {
            delay(200)
            result = if (ExecutionManager.lastRunOk) OverlayResult.DONE else OverlayResult.FAILED
            val elapsed = SystemClock.uptimeMillis() - shownAt
            delay((MIN_VISIBLE_MS - elapsed).coerceAtLeast(900L))
            visible = false
        }
    }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(250)) + scaleIn(initialScale = 1.06f, animationSpec = tween(350, easing = FastOutSlowInEasing)),
        exit = fadeOut(tween(400)) + scaleOut(targetScale = 0.97f, animationSpec = tween(400))
    ) {
        style?.let { s ->
            ModeOverlayContent(s, result, ExecutionManager.executionProgress)
        }
    }
}

@Composable
internal fun ModeOverlayContent(
    style: ModeStyle,
    result: OverlayResult,
    rawProgress: Float,
    scrimAlpha: Float = 0.90f
) {
    val progress by animateFloatAsState(
        targetValue = if (result == OverlayResult.APPLYING) rawProgress else 1f,
        animationSpec = tween(250),
        label = "ovProgress"
    )
    val inf = rememberInfiniteTransition(label = "ov")
    val ring by inf.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(2000, easing = LinearEasing), RepeatMode.Restart),
        label = "ring"
    )
    val sweep by inf.animateFloat(
        initialValue = -0.3f,
        targetValue = 1.3f,
        animationSpec = infiniteRepeatable(tween(2200, easing = LinearEasing), RepeatMode.Restart),
        label = "sweep"
    )

    var popped by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { popped = true }
    val pop by animateFloatAsState(
        targetValue = if (popped) 1f else 0.6f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
        label = "pop"
    )

    val accent = style.accent

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Ps4Colors.Deep.copy(alpha = scrimAlpha))
            // swallow touches while the overlay is up
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = {}
            ),
        contentAlignment = Alignment.Center
    ) {
        // landscape phones are only ~360dp tall: shrink everything a bit
        val compact = maxHeight < 420.dp
        Canvas(Modifier.fillMaxSize()) {
            val center = Offset(size.width / 2f, size.height / 2f)
            val maxR = maxOf(size.width, size.height) * 0.6f
            // expanding pulse rings
            for (k in 0..2) {
                val f = (ring + k / 3f) % 1f
                drawCircle(
                    color = accent.copy(alpha = (1f - f) * 0.45f),
                    radius = f * maxR,
                    center = center,
                    style = Stroke(width = 3.dp.toPx())
                )
            }
            // accent bloom
            drawCircle(
                brush = Brush.radialGradient(
                    listOf(accent.copy(alpha = 0.30f), Color.Transparent),
                    center = center,
                    radius = size.width * 0.8f
                ),
                radius = size.width * 0.8f,
                center = center
            )
            // diagonal light sweep
            val x = sweep * size.width
            rotate(degrees = -18f, pivot = center) {
                drawRect(
                    brush = Brush.horizontalGradient(
                        colors = listOf(Color.Transparent, Color.White.copy(alpha = 0.14f), Color.Transparent),
                        startX = x - 160.dp.toPx(),
                        endX = x + 160.dp.toPx()
                    ),
                    topLeft = Offset(-size.width, -size.height),
                    size = Size(size.width * 3f, size.height * 3f)
                )
            }
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
        ) {
            Box(
                modifier = Modifier
                    .scale(pop)
                    .size(if (compact) 72.dp else 104.dp)
                    .clip(CircleShape)
                    .background(accent.copy(alpha = 0.18f))
                    .border(2.dp, accent, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Crossfade(targetState = result, label = "ovIcon") { r ->
                    Icon(
                        imageVector = if (r == OverlayResult.DONE) Icons.Default.Check else style.icon,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(if (compact) 34.dp else 48.dp)
                    )
                }
            }
            Spacer(Modifier.height(if (compact) 12.dp else 28.dp))
            Text(
                text = style.name,
                color = Color.White,
                fontSize = if (compact) 30.sp else 40.sp,
                fontWeight = FontWeight.Light,
                letterSpacing = 8.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.scale(pop)
            )
            Spacer(Modifier.height(10.dp))
            Text(
                text = stringResource(style.descRes),
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 14.sp,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(if (compact) 16.dp else 36.dp))

            // PS4 style thin progress line
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.62f)
                    .height(3.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.18f))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(progress.coerceIn(0f, 1f))
                        .height(3.dp)
                        .clip(CircleShape)
                        .background(accent)
                )
            }
            Spacer(Modifier.height(if (compact) 8.dp else 14.dp))
            Text(
                text = when (result) {
                    OverlayResult.APPLYING -> stringResource(R.string.ps4_overlay_applying)
                    OverlayResult.DONE -> stringResource(R.string.ps4_overlay_done, style.name)
                    OverlayResult.FAILED -> stringResource(R.string.ps4_overlay_failed)
                },
                color = Color.White.copy(alpha = 0.85f),
                fontSize = 12.sp,
                letterSpacing = 2.sp
            )
        }
    }
}
