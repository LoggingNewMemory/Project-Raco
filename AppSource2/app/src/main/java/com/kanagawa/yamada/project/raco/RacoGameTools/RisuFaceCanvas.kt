package com.kanagawa.yamada.project.raco.RacoGameTools

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform

@Composable
fun RisuFaceCanvas(modifier: Modifier = Modifier) {
    // Warna khas Risu~
    val hairColor = Color(0xFF8D6E63) // Coklat tupai
    val eyeColor = Color(0xFFE57373)  // Merah muda/Pinkish
    val noseColor = Color(0xFF3E2723)

    Canvas(modifier = modifier) {
        // The original canvas logic had hardcoded values that occupy roughly 440x470 size.
        // We calculate scale so it scales down perfectly to the available space (e.g. 24.dp).
        val virtualWidth = 440f
        val virtualHeight = 470f
        val scale = minOf(size.width / virtualWidth, size.height / virtualHeight)

        withTransform({
            translate(size.width / 2, size.height / 2)
            scale(scale, scale, Offset.Zero)
        }) {
            val centerX = 0f
            val centerY = 85f // Offset by 85f to perfectly center the drawing vertically

            // 1. Telinga Kiri (Pakai Path biar bentuknya segitiga imut)
            val leftEarPath = Path().apply {
                moveTo(centerX - 150f, centerY - 150f)
                lineTo(centerX - 220f, centerY - 320f)
                lineTo(centerX - 50f, centerY - 200f)
                close()
            }
            drawPath(path = leftEarPath, color = hairColor)

            // 2. Telinga Kanan
            val rightEarPath = Path().apply {
                moveTo(centerX + 150f, centerY - 150f)
                lineTo(centerX + 220f, centerY - 320f)
                lineTo(centerX + 50f, centerY - 200f)
                close()
            }
            drawPath(path = rightEarPath, color = hairColor)

            // 3. Muka Tembem Risu (Oval base)
            drawOval(
                color = hairColor,
                topLeft = Offset(centerX - 200f, centerY - 200f),
                size = Size(400f, 350f)
            )

            // 4. Mata Kiri & Kanan (Mata besar biar lucu!)
            drawCircle(
                color = eyeColor,
                radius = 35f,
                center = Offset(centerX - 80f, centerY - 40f)
            )
            drawCircle(
                color = eyeColor,
                radius = 35f,
                center = Offset(centerX + 80f, centerY - 40f)
            )

            // 5. Hidung Tupai Kecil
            drawCircle(
                color = noseColor,
                radius = 12f,
                center = Offset(centerX, centerY + 30f)
            )

            // 6. Senyum Risu (Pake Arc garis lengkung)
            drawArc(
                color = noseColor,
                startAngle = 10f,
                sweepAngle = 160f,
                useCenter = false,
                topLeft = Offset(centerX - 40f, centerY + 30f),
                size = Size(80f, 50f),
                style = Stroke(width = 8f)
            )
        }
    }
}
