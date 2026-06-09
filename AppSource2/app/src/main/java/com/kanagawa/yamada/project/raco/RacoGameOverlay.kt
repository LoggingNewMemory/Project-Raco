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
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt

val NubiaRed = Color(0xFFFF2A2A)

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
            NubiaLeftPanel()
        }

        // RIGHT PANEL
        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .offset(x = rightOffset)
                .fillMaxHeight()
                .width(260.dp)
        ) {
            NubiaRightPanel()
        }
    }
}

@Composable
fun NubiaLeftPanel() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .drawBehind {
                val path = Path().apply {
                    moveTo(0f, 0f)
                    lineTo(size.width * 0.7f, 0f)
                    lineTo(size.width, size.height * 0.4f)
                    lineTo(size.width * 0.6f, size.height)
                    lineTo(0f, size.height)
                    close()
                }
                drawPath(
                    path = path,
                    brush = Brush.horizontalGradient(listOf(Color.Black.copy(alpha=0.9f), Color.Black.copy(alpha=0.4f)))
                )
                
                // Red glowing border
                val borderPath = Path().apply {
                    moveTo(size.width * 0.7f, 0f)
                    lineTo(size.width, size.height * 0.4f)
                    lineTo(size.width * 0.6f, size.height)
                }
                drawPath(path = borderPath, color = NubiaRed, style = Stroke(width = 6.dp.toPx()))
                // Outer glow
                drawPath(path = borderPath, color = NubiaRed.copy(alpha=0.3f), style = Stroke(width = 16.dp.toPx()))
            }
            .padding(start = 24.dp, top = 24.dp, bottom = 24.dp, end = 48.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Spacer(modifier = Modifier.height(24.dp))
            
            // CPU Monitor
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Text("2.70", color = Color.White, fontSize = 36.sp, fontWeight = FontWeight.Light)
                Text("GHz", color = Color.White.copy(alpha=0.6f), fontSize = 12.sp, fontWeight = FontWeight.Light)
                
                Spacer(modifier = Modifier.height(8.dp))
                // Rings
                Box(modifier = Modifier.size(80.dp), contentAlignment = Alignment.Center) {
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        drawCircle(NubiaRed.copy(alpha=0.2f), radius = size.width/2, style = Stroke(4f))
                        drawCircle(NubiaRed, radius = size.width/2.5f, style = Stroke(2f))
                        drawCircle(NubiaRed.copy(alpha=0.5f), radius = size.width/3, style = Stroke(8f))
                    }
                    Text("CPU", color = NubiaRed, fontWeight = FontWeight.Light, modifier = Modifier.align(Alignment.BottomCenter).offset(y = 12.dp))
                }
                
                Spacer(modifier = Modifier.height(24.dp))
                Box(modifier = Modifier.border(1.dp, NubiaRed, RoundedCornerShape(16.dp)).padding(horizontal = 32.dp, vertical = 8.dp)) {
                    Text("Rise", color = Color.White, fontWeight = FontWeight.Light)
                }
            }
        }
    }
}

@Composable
fun NubiaRightPanel() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .drawBehind {
                val path = Path().apply {
                    moveTo(size.width, 0f)
                    lineTo(size.width * 0.3f, 0f)
                    lineTo(0f, size.height * 0.4f)
                    lineTo(size.width * 0.4f, size.height)
                    lineTo(size.width, size.height)
                    close()
                }
                drawPath(
                    path = path,
                    brush = Brush.horizontalGradient(listOf(Color.Black.copy(alpha=0.4f), Color.Black.copy(alpha=0.9f)))
                )
                
                // Red glowing border
                val borderPath = Path().apply {
                    moveTo(size.width * 0.3f, 0f)
                    lineTo(0f, size.height * 0.4f)
                    lineTo(size.width * 0.4f, size.height)
                }
                drawPath(path = borderPath, color = NubiaRed, style = Stroke(width = 6.dp.toPx()))
                // Outer glow
                drawPath(path = borderPath, color = NubiaRed.copy(alpha=0.3f), style = Stroke(width = 16.dp.toPx()))
            }
            .padding(start = 48.dp, top = 24.dp, bottom = 24.dp, end = 24.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize(), horizontalAlignment = Alignment.End) {
            Text("PROJECT RACO", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Light, letterSpacing = 1.sp)
            Spacer(modifier = Modifier.height(24.dp))
            
            // Battery Monitor
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Text("96", color = Color.White, fontSize = 36.sp, fontWeight = FontWeight.Light)
                Text("%", color = Color.White.copy(alpha=0.6f), fontSize = 12.sp, fontWeight = FontWeight.Light)
                
                Spacer(modifier = Modifier.height(8.dp))
                // Rings
                Box(modifier = Modifier.size(80.dp), contentAlignment = Alignment.Center) {
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        drawCircle(NubiaRed.copy(alpha=0.2f), radius = size.width/2, style = Stroke(4f))
                        drawCircle(NubiaRed, radius = size.width/2.5f, style = Stroke(2f))
                        drawCircle(NubiaRed.copy(alpha=0.5f), radius = size.width/3, style = Stroke(8f))
                    }
                    Text("BATTERY", color = NubiaRed, fontWeight = FontWeight.Light, fontSize = 12.sp, modifier = Modifier.align(Alignment.BottomCenter).offset(y = 12.dp))
                }
                
                Spacer(modifier = Modifier.height(24.dp))
                Box(modifier = Modifier.border(1.dp, NubiaRed, RoundedCornerShape(16.dp)).padding(horizontal = 16.dp, vertical = 8.dp)) {
                    Text("Power Saving", color = Color.White, fontWeight = FontWeight.Light)
                }
            }
            

        }
    }
}



