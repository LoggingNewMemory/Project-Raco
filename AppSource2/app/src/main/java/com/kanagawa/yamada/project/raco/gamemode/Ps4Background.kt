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

import android.graphics.BitmapFactory
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

private class Sym(
    val kind: Int,      // 0 triangle, 1 circle, 2 cross, 3 square
    val x: Float,
    val y: Float,
    val size: Float,
    val rot: Int,       // integer multiples keep the 16 s loop seamless
    val speed: Int,
    val phase: Float,
    val alpha: Float
)

/**
 * PS4 "dynamic theme" look: deep blue gradient, flowing silk ribbons and the
 * triangle / circle / cross / square symbols slowly drifting and turning.
 */
@Composable
fun Ps4WaveBackground(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "ps4Wave")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(18000, easing = LinearEasing), RepeatMode.Restart),
        label = "phase"
    )

    val useImage = Ps4Settings.useCustomImage
    val imagePath = Ps4Settings.bgImagePath
    var image by remember { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(useImage, imagePath) {
        image = if (useImage && imagePath.isNotEmpty()) {
            withContext(Dispatchers.IO) { decodeSampled(imagePath, 1600) }
        } else null
    }

    val symbols = remember {
        val rnd = Random(11)
        List(20) {
            Sym(
                kind = rnd.nextInt(4),
                x = rnd.nextFloat(),
                y = rnd.nextFloat(),
                size = 7f + rnd.nextFloat() * 14f,
                rot = 1 + rnd.nextInt(2),
                speed = 1,
                phase = rnd.nextFloat() * 6.28f,
                alpha = 0.16f + rnd.nextFloat() * 0.24f
            )
        }
    }

    Canvas(modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        val img = image
        if (img != null) {
            drawCoverImage(img)
            drawRect(
                Brush.verticalGradient(
                    listOf(
                        Ps4Colors.Deep.copy(alpha = 0.55f),
                        Ps4Colors.DeepAlt.copy(alpha = 0.35f),
                        Ps4Colors.Deep.copy(alpha = 0.65f)
                    )
                )
            )
        } else {
            drawRect(
                Brush.verticalGradient(
                    listOf(Ps4Colors.Deep, Ps4Colors.DeepAlt, Ps4Colors.Mid, Ps4Colors.DeepAlt)
                )
            )
            // soft bloom, top left (like the PS4 home theme)
            drawRect(
                Brush.radialGradient(
                    colors = listOf(Ps4Colors.Bright.copy(alpha = 0.40f), Color.Transparent),
                    center = Offset(w * 0.12f, h * 0.05f),
                    radius = w * 0.75f
                )
            )
        }

        // silk ribbons
        drawRibbon(0, phase, 0.20f)
        drawRibbon(1, phase, 0.16f)
        drawRibbon(2, phase, 0.12f)

        // floating symbols
        val frac = phase / (2 * PI).toFloat()
        val sw = 1.6.dp.toPx()
        for (s in symbols) {
            val yy = (((s.y - frac * s.speed) % 1f) + 1f) % 1f
            val xx = s.x + 0.015f * sin(phase * s.speed + s.phase)
            val c = Offset(xx * w, yy * h)
            drawSymbol(s.kind, c, s.size.dp.toPx(), phase * s.rot * (180f / PI.toFloat()), Color.White.copy(alpha = s.alpha), sw)
        }
    }
}

private fun DrawScope.drawRibbon(idx: Int, phase: Float, alpha: Float) {
    val w = size.width
    val h = size.height
    val p = phase + idx * 1.3f
    val y0 = h * (0.80f - 0.05f * idx + 0.04f * sin(p))
    val y1 = h * (0.30f + 0.08f * idx + 0.10f * sin(p + 1f))
    val y2 = h * (1.05f - 0.10f * idx + 0.10f * cos(p))
    val y3 = h * (0.45f + 0.06f * idx + 0.08f * sin(p + 2f))

    val curve = Path().apply {
        moveTo(-0.1f * w, y0)
        cubicTo(w * 0.30f, y1, w * 0.62f, y2, w * 1.1f, y3)
    }
    // soft body under the ribbon
    val body = Path().apply {
        moveTo(-0.1f * w, y0)
        cubicTo(w * 0.30f, y1, w * 0.62f, y2, w * 1.1f, y3)
        lineTo(w * 1.1f, h * 1.1f)
        lineTo(-0.1f * w, h * 1.1f)
        close()
    }
    drawPath(
        body,
        Brush.verticalGradient(
            listOf(Ps4Colors.Accent.copy(alpha = alpha * 0.45f), Color.Transparent),
            startY = h * 0.3f,
            endY = h
        )
    )
    // bright silk edge
    drawPath(
        curve,
        Brush.linearGradient(
            colors = listOf(
                Color.Transparent,
                Ps4Colors.Accent.copy(alpha = alpha),
                Color.White.copy(alpha = alpha * 0.8f),
                Color.Transparent
            ),
            start = Offset(0f, 0f),
            end = Offset(w, h)
        ),
        style = Stroke(width = (26f + 22f * idx).dp.toPx(), cap = StrokeCap.Round)
    )
}

private fun DrawScope.drawSymbol(kind: Int, c: Offset, r: Float, deg: Float, color: Color, sw: Float) {
    rotate(degrees = deg, pivot = c) {
        when (kind) {
            0 -> {
                val path = Path().apply {
                    moveTo(c.x, c.y - r)
                    lineTo(c.x + r * 0.87f, c.y + r * 0.5f)
                    lineTo(c.x - r * 0.87f, c.y + r * 0.5f)
                    close()
                }
                drawPath(path, color, style = Stroke(width = sw, join = StrokeJoin.Round))
            }
            1 -> drawCircle(color, radius = r * 0.85f, center = c, style = Stroke(width = sw))
            2 -> {
                drawLine(color, Offset(c.x - r * 0.7f, c.y - r * 0.7f), Offset(c.x + r * 0.7f, c.y + r * 0.7f), sw, StrokeCap.Round)
                drawLine(color, Offset(c.x + r * 0.7f, c.y - r * 0.7f), Offset(c.x - r * 0.7f, c.y + r * 0.7f), sw, StrokeCap.Round)
            }
            else -> drawRect(
                color,
                topLeft = Offset(c.x - r * 0.7f, c.y - r * 0.7f),
                size = Size(r * 1.4f, r * 1.4f),
                style = Stroke(width = sw, join = StrokeJoin.Round)
            )
        }
    }
}

/** Center-crop ("cover") drawing of [img] over the whole canvas. */
private fun DrawScope.drawCoverImage(img: ImageBitmap) {
    val scale = maxOf(size.width / img.width, size.height / img.height)
    val srcW = (size.width / scale).toInt().coerceIn(1, img.width)
    val srcH = (size.height / scale).toInt().coerceIn(1, img.height)
    val srcX = ((img.width - srcW) / 2).coerceAtLeast(0)
    val srcY = ((img.height - srcH) / 2).coerceAtLeast(0)
    drawImage(
        image = img,
        srcOffset = IntOffset(srcX, srcY),
        srcSize = IntSize(srcW, srcH),
        dstOffset = IntOffset.Zero,
        dstSize = IntSize(size.width.toInt(), size.height.toInt())
    )
}

/** Decodes an image file down-sampled so its longest side is about [maxSide] px. */
internal fun decodeSampled(path: String, maxSide: Int): ImageBitmap? {
    return try {
        if (!File(path).exists()) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > maxSide) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        BitmapFactory.decodeFile(path, opts)?.asImageBitmap()
    } catch (e: Exception) {
        null
    }
}
