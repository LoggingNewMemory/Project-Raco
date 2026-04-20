package com.kanagawa.yamada.project.raco

import android.media.MediaPlayer
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun EntranceAnim(onAnimComplete: () -> Unit) {
    val context = LocalContext.current

    // ── Fonts ────────────────────────────────────────────────────────────
    val gilmerHeavy = remember {
        FontFamily(
            androidx.compose.ui.text.font.Typeface(
                android.graphics.Typeface.createFromAsset(context.assets, "GilmerHeavy.otf")
            )
        )
    }
    val gilmerMedium = remember {
        FontFamily(
            androidx.compose.ui.text.font.Typeface(
                android.graphics.Typeface.createFromAsset(context.assets, "GilmerMedium.otf")
            )
        )
    }

    // ── Animatables ──────────────────────────────────────────────────────
    val panelSplitOffset = remember { Animatable(0f) }

    // Staggered text alphas
    val titleAlpha = remember { Animatable(0f) }
    val subtitleAlpha = remember { Animatable(0f) }

    // Continuous slow drift
    val textScale = remember { Animatable(0.92f) }
    val exitAlpha = remember { Animatable(1f) }

    // ── Orchestration ────────────────────────────────────────────────────
    LaunchedEffect(Unit) {
        val mediaPlayer = MediaPlayer()
        try {
            val descriptor = context.assets.openFd("Intro.wav")
            mediaPlayer.setDataSource(
                descriptor.fileDescriptor,
                descriptor.startOffset,
                descriptor.length
            )
            descriptor.close()
            mediaPlayer.prepare()
            mediaPlayer.start()

            // 1. Parallax drift starts IMMEDIATELY at 0ms
            launch {
                textScale.animateTo(
                    targetValue = 1.05f,
                    animationSpec = tween(4000, easing = LinearOutSlowInEasing)
                )
            }

            // ── THE IMPACT ──
            // The initial "swoosh" takes ~180ms before the heavy slam.
            delay(180)

            // 2. Extreme snap-open for the panels matching the boom
            launch {
                panelSplitOffset.animateTo(
                    targetValue = 1f,
                    animationSpec = tween(
                        durationMillis = 1100,
                        // Violently fast at 0%, then extremely slow deceleration
                        easing = CubicBezierEasing(0.0f, 1.0f, 0.05f, 1.0f)
                    )
                )
            }

            // 3. Title punches in sharply with the panels
            launch {
                titleAlpha.animateTo(1f, tween(200, easing = LinearEasing))
            }

            // 4. Subtitle trails slightly behind for hierarchy
            launch {
                delay(120)
                subtitleAlpha.animateTo(1f, tween(400, easing = LinearOutSlowInEasing))
            }

            // Hold on screen to admire the echoing rumble
            delay(1800)

            // Graceful fade to black/exit
            launch {
                exitAlpha.animateTo(0f, tween(500, easing = FastOutLinearInEasing))
            }

            delay(550)
            onAnimComplete()

        } catch (e: Exception) {
            e.printStackTrace()
            onAnimComplete()
        } finally {
            mediaPlayer.release()
        }
    }

    // ── Layout ───────────────────────────────────────────────────────────
    Box(
        modifier = Modifier
            .fillMaxSize()
            .alpha(exitAlpha.value)
            .background(Color(0xFF060606)),
        contentAlignment = Alignment.Center
    ) {

        // 1. TEXT LAYER (Sits securely behind the masking panels)
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.scale(textScale.value)
        ) {
            Text(
                text = buildAnnotatedString {
                    withStyle(
                        SpanStyle(
                            color = Color(0xFFD32F2F),
                            shadow = Shadow(
                                color = Color(0x40D32F2F),
                                offset = Offset(0f, 8f),
                                blurRadius = 32f
                            )
                        )
                    ) { append("PROJECT ") }

                    withStyle(
                        SpanStyle(
                            color = Color.White,
                            shadow = Shadow(
                                color = Color(0x20FFFFFF),
                                offset = Offset(0f, 8f),
                                blurRadius = 32f
                            )
                        )
                    ) { append("RACO") }
                },
                fontFamily = gilmerHeavy,
                fontSize = 54.sp,
                letterSpacing = 4.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.alpha(titleAlpha.value)
            )

            Spacer(modifier = Modifier.height(10.dp))

            Text(
                text = "By: Kanagawa Yamada",
                color = Color.White,
                fontFamily = gilmerMedium,
                fontSize = 15.sp,
                letterSpacing = 4.sp,
                modifier = Modifier.alpha(subtitleAlpha.value * 0.85f)
            )
        }

        // 2. MASKING LAYER (Pure black panels that slide apart to reveal text)
        Canvas(modifier = Modifier.fillMaxSize()) {
            val cy = size.height / 2f
            val splitTravel = 140f * panelSplitOffset.value

            // Top Mask Panel
            drawRect(
                color = Color(0xFF060606),
                topLeft = Offset(0f, -splitTravel),
                size = Size(size.width, cy)
            )

            // Bottom Mask Panel
            drawRect(
                color = Color(0xFF060606),
                topLeft = Offset(0f, cy + splitTravel),
                size = Size(size.width, size.height - cy)
            )
        }
    }
}