package com.kanagawa.yamada.project.raco

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.ceil

@Composable
fun TopoBackground(
    color: Color,
    speed: Float = 1.0f,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "topoAnim")
    val animValue by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(30000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "topoProgress"
    )

    Canvas(modifier = modifier.fillMaxSize()) {
        val resolution = 12f
        val cols = ceil(size.width / resolution).toInt() + 1
        val rows = ceil(size.height / resolution).toInt() + 1
        val t = animValue * 2 * Math.PI.toFloat() * speed

        val thresholds = listOf(-3.0f, -2.75f, -2.5f, -2.25f, -2.0f, -1.75f, -1.5f, -1.25f, -1.0f, -0.75f, -0.5f, -0.25f, 0f, 0.25f, 0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 1.75f, 2.0f, 2.25f, 2.5f, 2.75f, 3.0f)

        fun getElevation(x: Float, y: Float, t: Float): Float {
            val scaleX = 0.012f
            val scaleY = 0.012f
            var v = sin(x * scaleX + t) + cos(y * scaleY + t * 0.8f)
            v += 0.5f * sin((x * 0.03f) - (y * 0.03f) + t * 2.0f)
            v += 0.2f * cos((x * 0.05f) + (y * 0.01f))
            return v
        }

        fun lerp(a: Offset, b: Offset, valA: Float, valB: Float, threshold: Float): Offset {
            if (Math.abs(valB - valA) < 0.0001f) return a
            val pct = (threshold - valA) / (valB - valA)
            return Offset(a.x + (b.x - a.x) * pct, a.y + (b.y - a.y) * pct)
        }

        var currentRow = FloatArray(cols) { i -> getElevation(i * resolution, 0f, t) }
        var nextRow = FloatArray(cols)

        val path = Path()

        for (j in 0 until rows - 1) {
            val y = j * resolution
            val nextY = (j + 1) * resolution

            for (i in 0 until cols) {
                nextRow[i] = getElevation(i * resolution, nextY, t)
            }

            for (i in 0 until cols - 1) {
                val x = i * resolution
                val nextX = (i + 1) * resolution

                val valTL = currentRow[i]
                val valTR = currentRow[i + 1]
                val valBL = nextRow[i]
                val valBR = nextRow[i + 1]

                for (threshold in thresholds) {
                    var state = 0
                    if (valTL > threshold) state = state or 8
                    if (valTR > threshold) state = state or 4
                    if (valBR > threshold) state = state or 2
                    if (valBL > threshold) state = state or 1

                    if (state == 0 || state == 15) continue

                    val tl = Offset(x, y)
                    val tr = Offset(nextX, y)
                    val br = Offset(nextX, nextY)
                    val bl = Offset(x, nextY)

                    val a = lerp(tl, tr, valTL, valTR, threshold)
                    val b = lerp(tr, br, valTR, valBR, threshold)
                    val c = lerp(bl, br, valBL, valBR, threshold)
                    val d = lerp(tl, bl, valTL, valBL, threshold)

                    when (state) {
                        1 -> { path.moveTo(d.x, d.y); path.lineTo(c.x, c.y) }
                        2 -> { path.moveTo(c.x, c.y); path.lineTo(b.x, b.y) }
                        3 -> { path.moveTo(d.x, d.y); path.lineTo(b.x, b.y) }
                        4 -> { path.moveTo(a.x, a.y); path.lineTo(b.x, b.y) }
                        5 -> { path.moveTo(d.x, d.y); path.lineTo(a.x, a.y); path.moveTo(c.x, c.y); path.lineTo(b.x, b.y) }
                        6 -> { path.moveTo(a.x, a.y); path.lineTo(c.x, c.y) }
                        7 -> { path.moveTo(d.x, d.y); path.lineTo(a.x, a.y) }
                        8 -> { path.moveTo(d.x, d.y); path.lineTo(a.x, a.y) }
                        9 -> { path.moveTo(a.x, a.y); path.lineTo(c.x, c.y) }
                        10 -> { path.moveTo(a.x, a.y); path.lineTo(b.x, b.y); path.moveTo(d.x, d.y); path.lineTo(c.x, c.y) }
                        11 -> { path.moveTo(a.x, a.y); path.lineTo(b.x, b.y) }
                        12 -> { path.moveTo(d.x, d.y); path.lineTo(b.x, b.y) }
                        13 -> { path.moveTo(c.x, c.y); path.lineTo(b.x, b.y) }
                        14 -> { path.moveTo(d.x, d.y); path.lineTo(c.x, c.y) }
                    }
                }
            }
            val temp = currentRow
            currentRow = nextRow
            nextRow = temp
        }

        drawPath(
            path = path,
            color = color,
            style = Stroke(width = 1f, cap = StrokeCap.Round)
        )
    }
}
