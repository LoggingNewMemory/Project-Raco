package com.kanagawa.yamada.project.raco.RacoOverlayTools

import android.content.Intent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kanagawa.yamada.project.raco.FloatingInfoService

@Composable
fun OverlayInfo(themeColor: Color) {
    val context = LocalContext.current
    val prefs = context.getSharedPreferences("raco_slingshot_prefs", android.content.Context.MODE_PRIVATE)
    var isActive by remember { mutableStateOf(FloatingInfoService.isRunning) }

    val animatedBackgroundColor by animateColorAsState(
        targetValue = if (isActive) themeColor else Color.Transparent,
        animationSpec = tween(durationMillis = 300)
    )
    val animatedIconColor by animateColorAsState(
        targetValue = if (isActive) Color.White else themeColor,
        animationSpec = tween(durationMillis = 300)
    )

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .background(animatedBackgroundColor, RoundedCornerShape(11.4.dp))
                .border(1.dp, themeColor, RoundedCornerShape(11.4.dp))
                .clip(RoundedCornerShape(11.4.dp))
                .clickable {
                    isActive = !isActive
                    if (isActive) {
                        val intent = Intent(context, FloatingInfoService::class.java)
                        context.startService(intent)
                        prefs.edit().putBoolean("is_info_enabled", true).apply()
                    } else {
                        context.stopService(Intent(context, FloatingInfoService::class.java))
                        prefs.edit().putBoolean("is_info_enabled", false).apply()
                    }
                },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Memory,
                contentDescription = "System Monitor",
                tint = animatedIconColor,
                modifier = Modifier.size(24.dp)
            )
        }
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "Info",
            color = themeColor,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
