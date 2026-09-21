package com.kanagawa.yamada.project.raco.UtilitiesPages

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun HueColorWheel(
    hue: Float,
    sat: Float = 1f,
    value: Float = 1f,
    onHueChange: (Float) -> Unit,
    modifier: Modifier = Modifier
) {
    val radius = 90.dp
    val radiusPx = with(LocalDensity.current) { radius.toPx() }

    Box(
        modifier = modifier
            .size(radius * 2)
            .pointerInput(Unit) {
                detectDragGestures { change, _ ->
                    val center = Offset(radiusPx, radiusPx)
                    val position = change.position
                    val angle = atan2(position.y - center.y, position.x - center.x)
                    var degrees = Math.toDegrees(angle.toDouble()).toFloat()
                    if (degrees < 0) degrees += 360f
                    onHueChange(degrees)
                }
            }
            .pointerInput(Unit) {
                detectTapGestures { offset ->
                    val center = Offset(radiusPx, radiusPx)
                    val angle = atan2(offset.y - center.y, offset.x - center.x)
                    var degrees = Math.toDegrees(angle.toDouble()).toFloat()
                    if (degrees < 0) degrees += 360f
                    onHueChange(degrees)
                }
            }
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val center = Offset(size.width / 2, size.height / 2)
            val r = size.width / 2 - 15.dp.toPx() // Keep inside bounds for thumb

            // Draw a sweep gradient for the hue wheel
            val sweepBrush = Brush.sweepGradient(
                colors = listOf(
                    Color.hsv(0f, 1f, 1f),
                    Color.hsv(60f, 1f, 1f),
                    Color.hsv(120f, 1f, 1f),
                    Color.hsv(180f, 1f, 1f),
                    Color.hsv(240f, 1f, 1f),
                    Color.hsv(300f, 1f, 1f),
                    Color.hsv(360f, 1f, 1f)
                ),
                center = center
            )
            
            drawCircle(
                brush = sweepBrush,
                radius = r,
                center = center,
                style = Stroke(width = 30.dp.toPx()) // Donut shape
            )
            
            // Draw a thumb for the current hue
            val angleRad = Math.toRadians(hue.toDouble())
            val thumbX = center.x + r * cos(angleRad).toFloat()
            val thumbY = center.y + r * sin(angleRad).toFloat()
            
            drawCircle(
                color = Color.White,
                radius = 16.dp.toPx(),
                center = Offset(thumbX, thumbY),
            )
            drawCircle(
                color = Color.hsv(hue, sat, value),
                radius = 12.dp.toPx(),
                center = Offset(thumbX, thumbY)
            )
        }
    }
}
